import 'package:flutter/material.dart';
import 'dart:html' as html;
import '../models/media_item.dart';
import '../utils/formatters.dart';

class PlaylistItem extends StatelessWidget {
  final MediaItem item;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onRemove;
  final Function(BuildContext) onSecondaryTap;

  const PlaylistItem({
    Key? key,
    required this.item,
    required this.isSelected,
    required this.onTap,
    required this.onSecondaryTap,
    this.onRemove,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTap: () => onSecondaryTap(context),
      child: ListTile(
        selected: isSelected,
        selectedTileColor:
            Theme.of(context).colorScheme.primary.withOpacity(0.2),
        leading: Icon(
          isSelected ? Icons.play_circle_filled : Icons.play_circle_outline,
          color: isSelected ? Theme.of(context).colorScheme.primary : null,
        ),
        title: Text(
          item.title,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Theme.of(context).colorScheme.primary : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.metadata != null) ...[
              Text(
                '${item.metadata!['width']}x${item.metadata!['height']} · ${TimeFormatter.formatFileSize(item.metadata!['size'])}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[400],
                ),
              ),
              Text(
                'Duration: ${TimeFormatter.formatTime(item.metadata!['duration'])}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[400],
                ),
              ),
            ] else
              Text(
                item.url.startsWith('blob:') ? 'Local file' : item.url,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[400],
                ),
              ),
            Text(
              'Added: ${item.addedAt.toString().split('.')[0]}',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.open_in_new, size: 20),
              onPressed: () => html.window.open(item.url, '_blank'),
              tooltip: 'Open in new tab',
            ),
            if (onRemove != null)
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: onRemove,
                tooltip: 'Remove from playlist',
              ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}