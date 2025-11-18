// VLC-style minimal media player clone (DartPad / Flutter Web ready)
// Single-file Flutter app. Copy-paste into DartPad (https://dartpad.dev/) using the Flutter tab and run.

// Notes:
// - Uses an HTML <video> element embedded into Flutter Web via platform view.
// - No external packages required. Works only on web (DartPad runs Flutter Web).
// - Features: play/pause, seek, volume, fullscreen, playlist, speed, loop, zoom, basic title.

// Dart imports
import 'dart:async';
import 'dart:html' as html;
// ignore: undefined_prefixed_name
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui;


// Flutter imports
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';

// Local imports (stubs or existing)

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PlaylistManager()),
        ChangeNotifierProvider(create: (_) => VideoSettings()),
        ChangeNotifierProvider(create: (_) => SubtitleManager()),
      ],
      child: const VLCCloneApp(),
    ),
  );
}

class VLCCloneApp extends StatelessWidget {
  const VLCCloneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VLC Media Player',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1A1A1A),
        primaryColor: const Color(0xFFF48B00), // VLC orange
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFFF48B00),
          secondary: const Color(0xFFF48B00),
          surface: const Color(0xFF232323),
          background: const Color(0xFF1A1A1A),
        ),
        sliderTheme: SliderThemeData(
          activeTrackColor: const Color(0xFFF48B00),
          thumbColor: const Color(0xFFF48B00),
          inactiveTrackColor: Colors.grey[800],
        ),
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
      ),
      home: const Scaffold(
        body: VLCHome(),
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}

class VLCHome extends StatefulWidget {
  const VLCHome({super.key});

  @override
  State<VLCHome> createState() => _VLCHomeState();
}

class _VLCHomeState extends State<VLCHome> {
  late html.VideoElement _video;
  final String _viewId = 'video-element-view';
  late FocusNode _focusNode;
  late StreamSubscription<html.KeyboardEvent> _keySubscription;
  double? _previousVolume;
  String _objectFit = 'contain'; // 'contain', 'cover', 'fill', 'none'
  double _zoom = 1.0;
  bool _showVolumeOSD = false;
  bool _showZoomOSD = false;
  Timer? _volumeTimer;
  Timer? _zoomTimer;
  bool _isFullscreen = false;
  bool _showControls = false; // Start hidden for immersive experience
  Timer? _hideControlsTimer;
  StreamSubscription<html.Event>? _fullscreenSubscription;
  html.Element? _originalParent;

  bool _isVideoFile(String fileName) {
    final validExtensions = [
      '.mp4', '.mkv', '.avi', '.mov',
      '.wmv', '.flv', '.webm', '.m4v',
      '.3gp', '.mpg', '.mpeg', '.m2v',
    ];
    return validExtensions.any((ext) => fileName.toLowerCase().endsWith(ext));
  }

  Future<Map<String, dynamic>> _getVideoMetadata(html.File file) async {
    final video = html.VideoElement();
    final url = html.Url.createObjectUrlFromBlob(file);
    video.src = url;

    try {
      await video.onLoadedMetadata.first;
      return {
        'duration': video.duration,
        'width': video.videoWidth,
        'height': video.videoHeight,
        'size': file.size,
      };
    } finally {
      html.Url.revokeObjectUrl(url);
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Timer? _timer;

  // sample playlist with reliable CORS-enabled MP4 to fix loading errors
  final List<MediaItem> _playlist = [
    MediaItem(
      title: 'Sample Video',
      url: 'https://sample-videos.com/video123/mp4/720/big_buck_bunny_720p_1mb.mp4',
    ),
    MediaItem(
      title: 'Another Sample',
      url: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
    ),
    MediaItem(
      title: 'Test Video',
      url: 'https://sample-videos.com/video123/mp4/720/SampleVideo_1280x720_1mb.mp4',
    ),
  ];

  int _currentIndex = 0;
  bool _isPlaying = false;
  double _volume = 0.8;
  double _playbackRate = 1.0;
  bool _loop = false;

  @override
  void initState() {
    super.initState();

    _focusNode = FocusNode();
    _focusNode.requestFocus();

    // create the HTML video element
    _video = html.VideoElement()
      ..src = _playlist[_currentIndex].url
      ..controls = false
      ..autoplay = false
      ..loop = false
      ..preload = 'auto'
      ..style.borderRadius = '8px'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = _objectFit
      ..style.transform = 'scale(1.0)'
      ..crossOrigin = 'anonymous';

    _video.onEnded.listen((_) => _onEnded());
    _video.onPlay.listen((_) => setState(() => _isPlaying = true));
    _video.onPause.listen((_) => setState(() => _isPlaying = false));
    _video.onError.listen((event) {
      print('Video load error: ${event}');
      // Fallback: try next video or show error UI
      if (_currentIndex < _playlist.length - 1) {
        _loadIndex(_currentIndex + 1, play: true);
      }
    });

    // expose the element to Flutter via platform view registry
    if (kIsWeb) {
      ui.platformViewRegistry.registerViewFactory(_viewId, (int viewId) => _video);
    }

    // start a timer to update UI (current time) - more frequent for responsive seek bar
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted) setState(() {});
    });

    // global key listener for shortcuts in fullscreen
    _keySubscription = html.window.onKeyDown.listen((html.KeyboardEvent event) {
      final key = event.key;
      if (key == ' ') {
        _togglePlay();
        _showControlsAndResetTimer();
        event.preventDefault();
      } else if (key == 'm' || key == 'M') {
        if (_video.muted) {
          _video.muted = false;
          _volume = _previousVolume ?? 0.8;
          _video.volume = _volume;
        } else {
          _previousVolume = _volume;
          _video.muted = true;
          _volume = 0.0;
        }
        setState(() {});
        _showControlsAndResetTimer();
        event.preventDefault();
      } else if (key == 'c' || key == 'C') {
        final fits = ['contain', 'cover', 'fill', 'none'];
        final index = fits.indexOf(_objectFit);
        _objectFit = fits[(index + 1) % fits.length];
        _video.style.objectFit = _objectFit;
        _showControlsAndResetTimer();
        event.preventDefault();
      } else if (key == 'a' || key == 'A') {
        _objectFit = _objectFit == 'contain' ? 'cover' : 'contain';
        _video.style.objectFit = _objectFit;
        _showControlsAndResetTimer();
        event.preventDefault();
      } else if (key == 'ArrowLeft') {
        _seekTo((_video.currentTime ?? 0) - 10);
        _showControlsAndResetTimer();
        event.preventDefault();
      } else if (key == 'ArrowRight') {
        _seekTo((_video.currentTime ?? 0) + 10);
        _showControlsAndResetTimer();
        event.preventDefault();
      } else if (key == 'ArrowUp') {
        _setVolume((_volume + 0.1).clamp(0.0, 1.0));
        _showControlsAndResetTimer();
        event.preventDefault();
      } else if (key == 'ArrowDown') {
        _setVolume((_volume - 0.1).clamp(0.0, 1.0));
        _showControlsAndResetTimer();
        event.preventDefault();
      } else if (key == '+' || key == '=') {
        _setZoom((_zoom + 0.1).clamp(0.25, 4.0));
        _showControlsAndResetTimer();
        event.preventDefault();
      } else if (key == '-') {
        _setZoom((_zoom - 0.1).clamp(0.25, 4.0));
        _showControlsAndResetTimer();
        event.preventDefault();
      } else if (key == 'f' || key == 'F') {
        _enterFullscreen();
        event.preventDefault();
      }
    });

    // fullscreen change listener
    _fullscreenSubscription = html.document.onFullscreenChange.listen((event) {
      setState(() {
        _isFullscreen = html.document.fullscreenElement != null;
        _showControls = !_isFullscreen;
        if (_isFullscreen) {
          _startHideTimer();
        } else {
          _hideControlsTimer?.cancel();
        }
      });
    });

    // Window resize listener for fullscreen responsiveness
    html.window.onResize.listen((event) {
      if (_isFullscreen && mounted) {
        setState(() {}); // Trigger rebuild to adapt to new dimensions
      }
    });

    // initial settings
    _video.volume = _volume;
    _video.playbackRate = _playbackRate;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _volumeTimer?.cancel();
    _zoomTimer?.cancel();
    _hideControlsTimer?.cancel();
    _fullscreenSubscription?.cancel();
    _focusNode.dispose();
    _video.pause();
    _video.src = '';
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      final key = event.logicalKey;
      switch (key) {
        case LogicalKeyboardKey.space:
          _togglePlay();
          return KeyEventResult.handled;
        case LogicalKeyboardKey.keyM:
          if (_video.muted) {
            _video.muted = false;
            _volume = _previousVolume ?? 0.8;
            _video.volume = _volume;
          } else {
            _previousVolume = _volume;
            _video.muted = true;
            _volume = 0.0;
          }
          setState(() {});
          return KeyEventResult.handled;
        case LogicalKeyboardKey.keyC: // Cycle crop (object-fit)
          final fits = ['contain', 'cover', 'fill', 'none'];
          final index = fits.indexOf(_objectFit);
          _objectFit = fits[(index + 1) % fits.length];
          _video.style.objectFit = _objectFit;
          return KeyEventResult.handled;
        case LogicalKeyboardKey.keyA: // Cycle aspect ratio (similar to crop)
          final aspects = ['auto', '16:9', '4:3', '1:1'];
          // For simplicity, toggle between contain and cover
          _objectFit = _objectFit == 'contain' ? 'cover' : 'contain';
          _video.style.objectFit = _objectFit;
          return KeyEventResult.handled;
        case LogicalKeyboardKey.arrowLeft:
          _seekTo((_video.currentTime ?? 0) - 10);
          return KeyEventResult.handled;
        case LogicalKeyboardKey.arrowRight:
          _seekTo((_video.currentTime ?? 0) + 10);
          return KeyEventResult.handled;
        case LogicalKeyboardKey.arrowUp:
          _setVolume((_volume + 0.1).clamp(0.0, 1.0));
          return KeyEventResult.handled;
        case LogicalKeyboardKey.arrowDown:
          _setVolume((_volume - 0.1).clamp(0.0, 1.0));
          return KeyEventResult.handled;
        case LogicalKeyboardKey.keyF:
          _enterFullscreen();
          return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  void _togglePlay() {
    if (_video.paused ?? true) {
      _video.play();
    } else {
      _video.pause();
    }
  }

  void _seekTo(double seconds) {
    _video.currentTime = seconds.clamp(0, _video.duration ?? 0);
  }

  void _setVolume(double value) {
    _volume = value;
    _video.volume = value;
    if (_video.muted) _video.muted = false;
    setState(() {
      _showVolumeOSD = true;
    });
    _volumeTimer?.cancel();
    _volumeTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _showVolumeOSD = false;
        });
      }
    });
  }

  void _setZoom(double value) {
    _zoom = value;
    _video.style.transform = 'scale($value)';
    setState(() {
      _showZoomOSD = true;
    });
    _zoomTimer?.cancel();
    _zoomTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _showZoomOSD = false;
        });
      }
    });
  }

  void _setPlaybackRate(double rate) {
    _playbackRate = rate;
    _video.playbackRate = rate;
    setState(() {});
  }

  void _toggleLoop() {
    _loop = !_loop;
    _video.loop = _loop;
    setState(() {});
  }

  void _onMouseEnter() {
    _showControlsAndResetTimer();
  }

  void _onMouseHover(PointerHoverEvent event) {
    _showControlsAndResetTimer();
  }

  void _onMouseExit(PointerExitEvent event) {
    _startHideTimer();
  }

  void _showControlsAndResetTimer() {
    setState(() => _showControls = true);
    _hideControlsTimer?.cancel();
    _startHideTimer();
  }

  void _startHideTimer() {
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _enterFullscreen() {
    if (html.document.fullscreenElement != null) {
      html.document.exitFullscreen();
    } else {
      _video.requestFullscreen();
    }
  }

  void _onEnded() {
    if (_loop) return;
    if (_currentIndex < _playlist.length - 1) {
      _loadIndex(_currentIndex + 1, play: true);
    } else {
      setState(() => _isPlaying = false);
    }
  }

  void _loadIndex(int index, {bool play = false}) {
    if (index < 0 || index >= _playlist.length) return;
    _currentIndex = index;
    _video.src = _playlist[_currentIndex].url;
    _video.load();
    if (play) _video.play();
    setState(() {});
  }

  void _openFilePicker() {
    final input = html.FileUploadInputElement()
      ..accept = '.mp4,.mkv,.avi,.mov,.wmv,.flv,.webm,.m4v,.3gp,.mpg,.mpeg,.m2v';
    input.onChange.listen((event) async {
      final files = input.files;
      if (files != null && files.isNotEmpty) {
        final file = files[0];
        if (_isVideoFile(file.name)) {
          final url = html.Url.createObjectUrlFromBlob(file);
          final metadata = await _getVideoMetadata(file);
          final custom = MediaItem(title: file.name, url: url, metadata: metadata);
          setState(() {
            _playlist.add(custom);
            _loadIndex(_playlist.length - 1, play: true);
          });
        }
      }
    });
    input.click();
  }

  String _formatTime(num seconds) {
    if (seconds.isNaN || seconds.isInfinite) return '00:00';
    final s = seconds.floor();
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  Widget _buildNormalView() {
    final duration = _video.duration ?? 0.0;
    final current = _video.currentTime ?? 0.0;

    return SafeArea(
      child: MouseRegion(
        onEnter: (_) => _showControlsAndResetTimer(),
        onHover: _onMouseHover,
        onExit: _onMouseExit,
        child: Column(
          children: [
            // Menu Bar (abbreviated for brevity)
            Container(
              color: Theme.of(context).colorScheme.surface,
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Icon(Icons.play_circle_filled, size: 32, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  const Text('VLC Media Player', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.folder_open),
                    onPressed: () {
                      _openFilePicker();
                      _showControlsAndResetTimer();
                    },
                    tooltip: 'Open File',
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings),
                    onPressed: () {
                      // Open settings
                      _showControlsAndResetTimer();
                    },
                  ),
                ],
              ),
            ),

            // Video and Controls
            Expanded(
              child: Column(
                children: [
                  // Video area
                  Expanded(
                    flex: 4,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      child: DragTarget<html.File>(
                        onWillAccept: (data) => true,
                        onAccept: (file) async {
                          if (_isVideoFile(file.name)) {
                            final url = html.Url.createObjectUrlFromBlob(file);
                            final metadata = await _getVideoMetadata(file);
                            final custom = MediaItem(title: file.name, url: url, metadata: metadata);
                            setState(() {
                              _playlist.add(custom);
                              _loadIndex(_playlist.length - 1, play: true);
                            });
                          }
                          _showControlsAndResetTimer();
                        },
                        builder: (context, candidateData, rejectedData) {
                          return MouseRegion(
                            onEnter: (_) => _showControlsAndResetTimer(),
                            onHover: _onMouseHover,
                            onExit: _onMouseExit,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: HtmlElementView(viewType: _viewId),
                                  ),
                                  ...(_showVolumeOSD ? [
                                    Positioned(
                                      bottom: 50,
                                      left: 0,
                                      right: 0,
                                      child: Center(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.7),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            '${(_volume * 100).round()}%',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ] : []),
                                  ...(_showZoomOSD ? [
                                    Positioned(
                                      top: 50,
                                      left: 0,
                                      right: 0,
                                      child: Center(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.7),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            '${(_zoom * 100).round()}%',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ] : []),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  // Controls (now auto-hiding with animation)
                  AnimatedOpacity(
                    opacity: _showControls ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: MouseRegion(
                      onEnter: (_) => _showControlsAndResetTimer(),
                      onHover: _onMouseHover,
                      onExit: _onMouseExit,
                      child: SingleChildScrollView(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Transport controls
                              Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surface,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: Row(
                                  children: [
                                    IconButton(
                                      iconSize: 32,
                                      icon: const Icon(Icons.skip_previous),
                                      onPressed: () {
                                        _loadIndex(_currentIndex - 1, play: true);
                                        _showControlsAndResetTimer();
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.fast_rewind),
                                      onPressed: () {
                                        _seekTo((_video.currentTime ?? 0.0) - 10);
                                        _showControlsAndResetTimer();
                                      },
                                    ),
                                    IconButton(
                                      iconSize: 48,
                                      icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled, color: Theme.of(context).colorScheme.primary),
                                      onPressed: () {
                                        _togglePlay();
                                        _showControlsAndResetTimer();
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.fast_forward),
                                      onPressed: () {
                                        _seekTo((_video.currentTime ?? 0.0) + 10);
                                        _showControlsAndResetTimer();
                                      },
                                    ),
                                    IconButton(
                                      iconSize: 32,
                                      icon: const Icon(Icons.skip_next),
                                      onPressed: () {
                                        _loadIndex(_currentIndex + 1, play: true);
                                        _showControlsAndResetTimer();
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.stop),
                                      onPressed: () {
                                        _video.pause();
                                        _video.currentTime = 0;
                                        setState(() {});
                                        _showControlsAndResetTimer();
                                      },
                                    ),
                                    const SizedBox(width: 16),
                                    Text('${_formatTime(current)} / ${_formatTime(duration)}', style: const TextStyle(fontFamily: 'Monospace')),
                                    const Spacer(),
                                    IconButton(
                                      icon: const Icon(Icons.fullscreen),
                                      onPressed: () {
                                        _enterFullscreen();
                                        _showControlsAndResetTimer();
                                      },
                                    ),
                                  ],
                                ),
                              ),

                              // Video Slider Bar (Seek Bar)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.only(left: 8.0, bottom: 4.0),
                                    child: Text('Video Progress', style: TextStyle(color: Colors.white, fontSize: 14)),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                    child: SliderTheme(
                                      data: SliderTheme.of(context).copyWith(
                                        activeTrackColor: Theme.of(context).colorScheme.primary,
                                        inactiveTrackColor: Colors.grey[600],
                                        thumbColor: Theme.of(context).colorScheme.primary,
                                        overlayColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                                        trackHeight: 6,
                                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                                      ),
                                      child: Slider(
                                        value: current.isNaN || duration == 0 ? 0 : current.clamp(0, duration).toDouble(),
                                        min: 0,
                                        max: duration.isFinite && duration > 0 ? duration.toDouble() : 100,
                                        onChanged: (value) {
                                          _seekTo(value);
                                          _showControlsAndResetTimer();
                                        },
                                        onChangeEnd: (value) {
                                          _seekTo(value);
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              // Volume and playback rate
                              Row(
                                children: [
                                  Icon(_volume == 0 ? Icons.volume_off : _volume < 0.5 ? Icons.volume_down : Icons.volume_up, color: Theme.of(context).colorScheme.primary),
                                  Expanded(child: Slider(value: _volume, min: 0, max: 1, onChanged: (v) {
                                    _setVolume(v);
                                    _showControlsAndResetTimer();
                                  })),
                                  Text('${(_volume * 100).round()}%'),
                                  const SizedBox(width: 16),
                                  DropdownButton<double>(
                                    value: _playbackRate,
                                    items: [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 4.0].map((e) => DropdownMenuItem(value: e, child: Text('${e}x'))).toList(),
                                    onChanged: (v) {
                                      if (v != null) _setPlaybackRate(v);
                                      _showControlsAndResetTimer();
                                    },
                                  ),
                                  IconButton(
                                    icon: Icon(_loop ? Icons.repeat_on : Icons.repeat),
                                    onPressed: () {
                                      _toggleLoop();
                                      _showControlsAndResetTimer();
                                    },
                                  ),
                                ],
                              ),

                              // Zoom controls
                              Row(
                                children: [
                                  Icon(Icons.zoom_in, color: Theme.of(context).colorScheme.primary),
                                  Expanded(child: Slider(value: _zoom, min: 0.25, max: 4.0, onChanged: (v) {
                                    _setZoom(v);
                                    _showControlsAndResetTimer();
                                  })),
                                  Text('${(_zoom * 100).round()}%'),
                                ],
                              ),

                              // Playlist (abbreviated)
                              SizedBox(
                                height: 150,
                                child: ListView.builder(
                                  itemCount: _playlist.length,
                                  itemBuilder: (context, i) => ListTile(
                                    title: Text(_playlist[i].title),
                                    selected: i == _currentIndex,
                                    onTap: () {
                                      _loadIndex(i, play: true);
                                      _showControlsAndResetTimer();
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullscreenView() {
    final duration = _video.duration ?? 0.0;
    final current = _video.currentTime ?? 0.0;

    return MouseRegion(
      onEnter: (_) => _onMouseEnter(),
      onHover: _onMouseHover,
      onExit: _onMouseExit,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              color: Colors.black,
              child: HtmlElementView(viewType: _viewId),
            ),
          ),
          // Subtle gradient overlay for cinematic mood
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.1),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withOpacity(0.3),
                  ],
                ),
              ),
            ),
          ),
          // Volume OSD in fullscreen
          ...(_showVolumeOSD ? [
            Positioned(
              bottom: 100,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${(_volume * 100).round()}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ] : []),
          // Error fallback if video fails to load
          ...(_video.networkState == 3 ? [
            Positioned.fill(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  color: Colors.black.withOpacity(0.8),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error, color: Colors.red, size: 48),
                      SizedBox(height: 10),
                      Text(
                        'Failed to load video. Try another file.',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ] : []),
          // Minimal controls overlay - responsive sizing based on screen
          AnimatedOpacity(
            opacity: _showControls ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: Container(
              color: Colors.black.withOpacity(0.4),
              child: Column(
                children: [
                  const Spacer(),
                  // Seek bar at bottom - fixed padding
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: Theme.of(context).colorScheme.primary,
                        inactiveTrackColor: Colors.grey[600],
                        thumbColor: Theme.of(context).colorScheme.primary,
                        overlayColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      ),
                      child: Slider(
                        value: current.isNaN || duration == 0 ? 0 : current.clamp(0, duration).toDouble(),
                        min: 0,
                        max: duration.isFinite && duration > 0 ? duration.toDouble() : 100,
                        onChanged: (value) {
                          _seekTo(value);
                        },
                        onChangeEnd: (value) {
                          _seekTo(value);
                        },
                      ),
                    ),
                  ),
                  // Transport controls - fixed icon sizes
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          iconSize: 32,
                          icon: const Icon(Icons.skip_previous),
                          color: Colors.white.withOpacity(0.8),
                          onPressed: () => _loadIndex(_currentIndex - 1, play: true),
                        ),
                        IconButton(
                          iconSize: 32,
                          icon: const Icon(Icons.fast_rewind),
                          color: Colors.white.withOpacity(0.8),
                          onPressed: () => _seekTo((_video.currentTime ?? 0.0) - 10),
                        ),
                        IconButton(
                          iconSize: 48,
                          icon: Icon(
                            _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          onPressed: _togglePlay,
                        ),
                        IconButton(
                          iconSize: 32,
                          icon: const Icon(Icons.fast_forward),
                          color: Colors.white.withOpacity(0.8),
                          onPressed: () => _seekTo((_video.currentTime ?? 0.0) + 10),
                        ),
                        IconButton(
                          iconSize: 32,
                          icon: const Icon(Icons.skip_next),
                          color: Colors.white.withOpacity(0.8),
                          onPressed: () => _loadIndex(_currentIndex + 1, play: true),
                        ),
                        const SizedBox(width: 20),
                        Text(
                          '${_formatTime(current)} / ${_formatTime(duration)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'Monospace',
                            fontSize: 14,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          iconSize: 32,
                          icon: const Icon(Icons.fullscreen_exit),
                          color: Colors.white.withOpacity(0.8),
                          onPressed: _enterFullscreen,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: _isFullscreen ? _buildFullscreenView() : _buildNormalView(),
    );
  }
}

// Stub classes for imports (replace with actual if available)
class MediaItem {
  final String title;
  final String url;
  final Map<String, dynamic>? metadata;
  final DateTime addedAt = DateTime.now();

  MediaItem({required this.title, required this.url, this.metadata});
}

class PlaylistManager extends ChangeNotifier {}

class SubtitleManager extends ChangeNotifier {}

class VideoSettings extends ChangeNotifier {}

class SettingsService {
  static void addRecentFile(MediaItem item) {}
}

