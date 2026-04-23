import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Tutorial-video tile at the top of AboutWorkoutPage.
///
/// We used to embed the video via youtube_player_iframe, but many
/// fitness creators disable embedding in YouTube Studio, which throws
/// error 150/152 for their entire channel. Instead we show YouTube's
/// public thumbnail and open the real YouTube app on tap — which
/// works regardless of embed settings, is lighter (no WebView), and
/// gives users the full native player.
///
/// When the workout's `videoUrl` is null or unparseable, falls back
/// to a plain gray placeholder with a fitness icon.
class WorkoutVideoPlayer extends StatelessWidget {
  final String? videoUrl;

  const WorkoutVideoPlayer({super.key, required this.videoUrl});

  @override
  Widget build(BuildContext context) {
    final videoId = _extractYoutubeId(videoUrl);
    if (videoId == null) {
      return _placeholder();
    }
    return _thumbnail(context, videoId);
  }

  Widget _thumbnail(BuildContext context, String videoId) {
    // YouTube hosts public thumbnails at predictable URLs. `hqdefault`
    // (480×360) is the most widely available size — even recently
    // uploaded videos usually have it within seconds.
    final thumbUrl = 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: GestureDetector(
        onTap: () => _open(videoUrl!),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              thumbUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _placeholderContent(),
              loadingBuilder: (_, child, progress) {
                if (progress == null) return child;
                return Container(
                  color: Colors.grey.shade200,
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF6B5FFF),
                      strokeWidth: 2,
                    ),
                  ),
                );
              },
            ),
            // Dark gradient scrim so the play button is always readable
            // over bright thumbnails.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withAlpha(40),
                    Colors.black.withAlpha(90),
                  ],
                ),
              ),
            ),
            const Center(child: _PlayBadge()),
            Positioned(
              left: 12,
              bottom: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(140),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.open_in_new, size: 12, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      'Play on YouTube',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => AspectRatio(
        aspectRatio: 16 / 9,
        child: _placeholderContent(),
      );

  Widget _placeholderContent() => Container(
        color: Colors.grey.shade200,
        child: const Center(
          child: Icon(
            Icons.fitness_center,
            size: 56,
            color: Color(0xFF6B5FFF),
          ),
        ),
      );

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Extracts the 11-character YouTube video ID from common URL forms:
  ///   https://youtu.be/XXXXXXXXXXX
  ///   https://youtu.be/XXXXXXXXXXX?si=...
  ///   https://www.youtube.com/watch?v=XXXXXXXXXXX
  ///   https://www.youtube.com/embed/XXXXXXXXXXX
  ///   https://www.youtube.com/shorts/XXXXXXXXXXX
  static String? _extractYoutubeId(String? url) {
    if (url == null || url.isEmpty) return null;
    final regex = RegExp(
      r'(?:youtu\.be/|youtube\.com/(?:watch\?v=|embed/|v/|shorts/))([A-Za-z0-9_-]{11})',
    );
    final match = regex.firstMatch(url);
    return match?.group(1);
  }
}

class _PlayBadge extends StatelessWidget {
  const _PlayBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(220),
        shape: BoxShape.circle,
      ),
      child: const Center(
        child: Icon(
          Icons.play_arrow,
          size: 40,
          color: Color(0xFFFF0000),
        ),
      ),
    );
  }
}
