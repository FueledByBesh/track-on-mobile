import 'package:flutter/material.dart';

/// Size presets for the thumbnail. Each picks the best YouTube CDN
/// variant for its pixel budget — small cards don't download 480px
/// images they'll render at 50px.
enum WorkoutThumbnailSize {
  /// 50×50 — list rows, planned workout cards.
  small(50, 'mqdefault.jpg'),

  /// 60×60 — library cards.
  medium(60, 'mqdefault.jpg'),

  /// Full width, 16:9 — detail page hero.
  hero(0, 'hqdefault.jpg');

  final double boxSize; // 0 = expand to parent
  final String ytSuffix;
  const WorkoutThumbnailSize(this.boxSize, this.ytSuffix);
}

/// Reusable workout thumbnail backed by YouTube's public thumbnail CDN.
/// Extracts the video ID from the workout's `tutorialVideoUrl` and
/// shows the CDN image with a rounded-corner clip. Falls back to a
/// purple fitness-icon placeholder if the URL is null or unparseable.
class WorkoutThumbnail extends StatelessWidget {
  final String? videoUrl;
  final WorkoutThumbnailSize size;
  final double borderRadius;

  const WorkoutThumbnail({
    super.key,
    required this.videoUrl,
    this.size = WorkoutThumbnailSize.medium,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final videoId = _extractYoutubeId(videoUrl);

    if (size == WorkoutThumbnailSize.hero) {
      return _heroLayout(videoId);
    }
    return _boxLayout(videoId);
  }

  Widget _boxLayout(String? videoId) {
    final dim = size.boxSize;
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: dim,
        height: dim,
        child: videoId != null
            ? Image.network(
                _thumbUrl(videoId),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholderBox(dim),
              )
            : _placeholderBox(dim),
      ),
    );
  }

  Widget _heroLayout(String? videoId) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: videoId != null
            ? Image.network(
                _thumbUrl(videoId),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholderHero(),
              )
            : _placeholderHero(),
      ),
    );
  }

  Widget _placeholderBox(double dim) {
    return Container(
      width: dim,
      height: dim,
      color: const Color(0xFF6B5FFF).withAlpha(30),
      child: Center(
        child: Icon(
          Icons.fitness_center,
          color: const Color(0xFF6B5FFF),
          size: dim * 0.5,
        ),
      ),
    );
  }

  Widget _placeholderHero() {
    return Container(
      color: Colors.grey.shade200,
      child: const Center(
        child: Icon(
          Icons.fitness_center,
          size: 56,
          color: Color(0xFF6B5FFF),
        ),
      ),
    );
  }

  String _thumbUrl(String videoId) =>
      'https://img.youtube.com/vi/$videoId/${size.ytSuffix}';

  static String? _extractYoutubeId(String? url) {
    if (url == null || url.isEmpty) return null;
    final regex = RegExp(
      r'(?:youtu\.be/|youtube\.com/(?:watch\?v=|embed/|v/|shorts/))([A-Za-z0-9_-]{11})',
    );
    final match = regex.firstMatch(url);
    return match?.group(1);
  }
}
