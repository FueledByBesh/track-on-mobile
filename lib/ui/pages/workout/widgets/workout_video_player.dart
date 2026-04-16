import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

/// Looping muted YouTube player used at the top of AboutWorkoutPage.
/// Mutes are required for mobile autoplay; looping is implemented via
/// YouTube's playlist parameter (single-video "playlist" loops back to
/// itself when the video ends).
///
/// If [videoUrl] is null or doesn't contain a parseable YouTube ID,
/// falls back to a plain gray placeholder with a fitness icon.
class WorkoutVideoPlayer extends StatefulWidget {
  final String? videoUrl;

  const WorkoutVideoPlayer({super.key, required this.videoUrl});

  @override
  State<WorkoutVideoPlayer> createState() => _WorkoutVideoPlayerState();
}

class _WorkoutVideoPlayerState extends State<WorkoutVideoPlayer> {
  YoutubePlayerController? _controller;
  String? _videoId;

  @override
  void initState() {
    super.initState();
    _setupController();
  }

  void _setupController() {
    final videoId = _extractYoutubeId(widget.videoUrl);
    _videoId = videoId;
    if (videoId == null) return;

    _controller = YoutubePlayerController(
      params: const YoutubePlayerParams(
        showControls: false,
        showFullscreenButton: false,
        mute: true,
        loop: true,
        playsInline: true,
        enableCaption: false,
        strictRelatedVideos: true,
      ),
    )..loadVideoById(videoId: videoId);
  }

  @override
  void dispose() {
    _controller?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_videoId == null || _controller == null) {
      return _placeholder();
    }
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: YoutubePlayer(
        controller: _controller!,
        aspectRatio: 16 / 9,
      ),
    );
  }

  Widget _placeholder() {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        color: Colors.grey.shade200,
        child: const Center(
          child: Icon(
            Icons.fitness_center,
            size: 56,
            color: Color(0xFF6B5FFF),
          ),
        ),
      ),
    );
  }

  /// Extracts the 11-character YouTube video ID from common URL forms:
  ///   https://youtu.be/XXXXXXXXXXX
  ///   https://youtu.be/XXXXXXXXXXX?si=...
  ///   https://www.youtube.com/watch?v=XXXXXXXXXXX
  ///   https://www.youtube.com/embed/XXXXXXXXXXX
  /// Returns null if no id can be found.
  static String? _extractYoutubeId(String? url) {
    if (url == null || url.isEmpty) return null;
    final regex = RegExp(
      r'(?:youtu\.be/|youtube\.com/(?:watch\?v=|embed/|v/|shorts/))([A-Za-z0-9_-]{11})',
    );
    final match = regex.firstMatch(url);
    return match?.group(1);
  }
}
