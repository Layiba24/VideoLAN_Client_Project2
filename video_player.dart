import 'dart:html' as html;
import 'package:flutter/material.dart';

class VideoPlayer extends StatelessWidget {
  final String viewId;
  final Function(html.File) onFileAccepted;

  const VideoPlayer({
    Key? key,
    required this.viewId,
    required this.onFileAccepted,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DragTarget<html.File>(
      onWillAccept: (data) => true,
      onAccept: onFileAccepted,
      builder: (context, candidateData, rejectedData) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: candidateData.isNotEmpty 
                ? Theme.of(context).colorScheme.primary 
                : Colors.white12,
              width: candidateData.isNotEmpty ? 2 : 1,
            ),
          ),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: HtmlElementView(viewType: viewId),
              ),
              if (candidateData.isNotEmpty)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(
                          Icons.file_download,
                          size: 48,
                          color: Colors.white,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Drop video file here',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}