import 'package:flutter/material.dart';

import '../../../data/models/post.dart';

/// Full-screen image gallery. Black background, horizontally swipeable,
/// each page wrapped in [InteractiveViewer] for pinch-to-zoom. Tap the
/// X in the top-left or swipe-back to dismiss.
class ImageGalleryViewerPage extends StatefulWidget {
  /// Image attachments to display, in their stored order.
  final List<PostAttachment> images;
  final int initialIndex;

  const ImageGalleryViewerPage({
    super.key,
    required this.images,
    this.initialIndex = 0,
  });

  @override
  State<ImageGalleryViewerPage> createState() =>
      _ImageGalleryViewerPageState();
}

class _ImageGalleryViewerPageState extends State<ImageGalleryViewerPage> {
  late final PageController _ctrl;
  late int _page;

  @override
  void initState() {
    super.initState();
    _page = widget.initialIndex.clamp(0, widget.images.length - 1);
    _ctrl = PageController(initialPage: _page);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _ctrl,
            itemCount: widget.images.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) {
              final url = widget.images[i].displayUrl;
              if (url == null) {
                return const Center(
                  child: Icon(Icons.broken_image_outlined,
                      color: Colors.white54, size: 60),
                );
              }
              return InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Center(
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    loadingBuilder: (_, child, progress) => progress == null
                        ? child
                        : const Center(
                            child: CircularProgressIndicator(
                                color: Colors.white)),
                    errorBuilder: (_, _, _) => const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white54,
                        size: 60),
                  ),
                ),
              );
            },
          ),

          // Top bar: close + counter
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  if (widget.images.length > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(120),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_page + 1} / ${widget.images.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
