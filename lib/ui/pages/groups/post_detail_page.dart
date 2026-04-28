import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/models/post.dart' as post_model;
import '../../../data/providers/groups_provider.dart';
import '../../../data/services/post_service.dart';
import '../../sharedwidgets/profile_page.dart';
import '../../sharedwidgets/post_attachments_viewer.dart';
import '../runpage/run_detail_page.dart';
import 'image_gallery_viewer_page.dart';

class PostDetailPage extends StatefulWidget {
  final post_model.Post post;

  const PostDetailPage({super.key, required this.post});

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  late post_model.Post _post;
  List<post_model.Comment> _comments = [];
  bool _loadingComments = true;
  bool _submitting = false;
  final _commentCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    _loadComments();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    try {
      final list = await context
          .read<PostApiService>()
          .getComments(_post.kind, _post.id);
      if (mounted) setState(() { _comments = list; _loadingComments = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingComments = false);
    }
  }

  Future<void> _submitComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _submitting = true);
    try {
      final comment = await context
          .read<PostApiService>()
          .addComment(_post.kind, _post.id, text);
      _commentCtrl.clear();
      setState(() {
        _comments = [..._comments, comment];
        // bump count locally
        _post = post_model.Post(
          id: _post.id, kind: _post.kind,
          authorId: _post.authorId, authorName: _post.authorName,
          authorEmail: _post.authorEmail,
          authorAvatarUrl: _post.authorAvatarUrl,
          clubId: _post.clubId, clubName: _post.clubName,
          content: _post.content, attachments: _post.attachments,
          likes: _post.likes, dislikes: _post.dislikes,
          commentCount: _post.commentCount + 1,
          userLiked: _post.userLiked, createdAt: _post.createdAt,
        );
      });
      // Scroll to bottom after adding comment.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _toggleLike(bool isLike) async {
    try {
      await context
          .read<GroupsProvider>()
          .likePost(_post.kind, _post.id, isLike);
      // Optimistic local update — provider also refreshes the feed in
      // the background.
      setState(() {
        final already = _post.userLiked == isLike;
        _post = post_model.Post(
          id: _post.id, kind: _post.kind,
          authorId: _post.authorId, authorName: _post.authorName,
          authorEmail: _post.authorEmail,
          authorAvatarUrl: _post.authorAvatarUrl,
          clubId: _post.clubId, clubName: _post.clubName,
          content: _post.content, attachments: _post.attachments,
          likes: _post.likes +
              (isLike ? (already ? -1 : 1) : 0),
          dislikes: _post.dislikes +
              (!isLike ? (already ? -1 : 1) : 0),
          commentCount: _post.commentCount,
          userLiked: already ? null : isLike,
          createdAt: _post.createdAt,
        );
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(elevation: 0),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scrollCtrl,
              children: [
                _PostBody(
                  post: _post,
                  onLike: () => _toggleLike(true),
                  onDislike: () => _toggleLike(false),
                ),
                Divider(height: 1, color: scheme.outlineVariant),
                _CommentsSection(
                  comments: _comments,
                  loading: _loadingComments,
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
          _CommentInput(
            controller: _commentCtrl,
            submitting: _submitting,
            onSubmit: _submitComment,
          ),
        ],
      ),
    );
  }
}

// ── Post body ────────────────────────────────────────────────────────────────

class _PostBody extends StatelessWidget {
  final post_model.Post post;
  final VoidCallback onLike;
  final VoidCallback onDislike;

  const _PostBody({
    required this.post,
    required this.onLike,
    required this.onDislike,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final initials = post.authorName.isNotEmpty
        ? post.authorName
            .split(' ')
            .map((e) => e.isNotEmpty ? e[0] : '')
            .take(2)
            .join()
        : '?';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Author row
        InkWell(
          onTap: () => Navigator.push(context,
              MaterialPageRoute(
                  builder: (_) => ProfilePage(userId: post.authorId))),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                _AuthorAvatar(
                  avatarUrl: post.authorAvatarUrl,
                  initials: initials,
                  scheme: scheme,
                  sizePx: 48,
                  fontSize: 17,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(post.authorName,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      if (post.clubName != null)
                        Text(post.clubName!,
                            style: TextStyle(
                                fontSize: 13,
                                color: scheme.primary,
                                fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                Text(_localDateTime(post.createdAt),
                    style: TextStyle(
                        fontSize: 12, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ),

        // Content
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Text(
            post.content,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(height: 1.5),
          ),
        ),

        // Attachments with "Open in full map" overlay on activity slots
        if (post.attachments.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
            child: PostAttachmentsViewer(
              attachments: post.attachments,
              showMapButton: true,
              onActivityTap: (activityId) => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        RunDetailPage(activityId: activityId)),
              ),
              onImageTap: (attachmentId) {
                final images = post.attachments
                    .where((a) =>
                        a.kind == post_model.PostAttachmentKind.image)
                    .toList();
                final initialIndex =
                    images.indexWhere((a) => a.id == attachmentId);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ImageGalleryViewerPage(
                      images: images,
                      initialIndex: initialIndex < 0 ? 0 : initialIndex,
                    ),
                  ),
                );
              },
            ),
          ),

        Divider(height: 1, color: scheme.outlineVariant),

        // Action bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              _ActionBtn(
                icon: post.userLiked == true
                    ? Icons.thumb_up_rounded
                    : Icons.thumb_up_outlined,
                label: '${post.likes}',
                color: post.userLiked == true
                    ? scheme.primary
                    : scheme.onSurfaceVariant,
                onTap: onLike,
              ),
              _ActionBtn(
                icon: post.userLiked == false
                    ? Icons.thumb_down_rounded
                    : Icons.thumb_down_outlined,
                label: '${post.dislikes}',
                color: post.userLiked == false
                    ? scheme.primary
                    : scheme.onSurfaceVariant,
                onTap: onDislike,
              ),
              _ActionBtn(
                icon: Icons.mode_comment_outlined,
                label: '${post.commentCount}',
                color: scheme.onSurfaceVariant,
                onTap: null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

// ── Comments ─────────────────────────────────────────────────────────────────

class _CommentsSection extends StatelessWidget {
  final List<post_model.Comment> comments;
  final bool loading;

  const _CommentsSection({required this.comments, required this.loading});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            comments.isEmpty && !loading
                ? 'No comments yet'
                : 'Comments',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        if (loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          ...comments.map((c) => _CommentRow(comment: c)),
      ],
    );
  }
}

class _CommentRow extends StatelessWidget {
  final post_model.Comment comment;
  const _CommentRow({required this.comment});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final initials = comment.authorName.isNotEmpty
        ? comment.authorName[0].toUpperCase()
        : '?';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
                color: scheme.primary.withAlpha(60),
                shape: BoxShape.circle),
            child: Center(
              child: Text(initials,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: scheme.primary)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(comment.authorName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(width: 8),
                    Text(_relativeTime(comment.createdAt),
                        style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurfaceVariant)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(comment.content,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Comment input ─────────────────────────────────────────────────────────────

class _CommentInput extends StatelessWidget {
  final TextEditingController controller;
  final bool submitting;
  final VoidCallback onSubmit;

  const _CommentInput({
    required this.controller,
    required this.submitting,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color ?? scheme.surface,
          border: Border(top: BorderSide(color: scheme.outlineVariant)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSubmit(),
                decoration: InputDecoration(
                  hintText: 'Add a comment…',
                  hintStyle:
                      TextStyle(color: scheme.onSurfaceVariant),
                  filled: true,
                  fillColor: scheme.surfaceContainerHighest,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            submitting
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : IconButton(
                    icon: Icon(Icons.send_rounded, color: scheme.primary),
                    onPressed: onSubmit,
                  ),
          ],
        ),
      ),
    );
  }
}

String _relativeTime(String iso) {
  try {
    final dt = DateTime.parse(iso).toLocal();
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${diff.inDays ~/ 7}w';
  } catch (_) { return ''; }
}

/// Local date + time, e.g. "28 Apr · 14:32" (current year) or
/// "12 Mar 2024 · 14:32" (prior years).
String _localDateTime(String iso) {
  try {
    final dt = DateTime.parse(iso).toLocal();
    final now = DateTime.now();
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    if (dt.year == now.year) {
      return '${dt.day} ${months[dt.month - 1]} · $hh:$mm';
    }
    return '${dt.day} ${months[dt.month - 1]} ${dt.year} · $hh:$mm';
  } catch (_) { return ''; }
}

class _AuthorAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String initials;
  final ColorScheme scheme;
  final double sizePx;
  final double fontSize;

  const _AuthorAvatar({
    required this.avatarUrl,
    required this.initials,
    required this.scheme,
    required this.sizePx,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: sizePx,
      height: sizePx,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: scheme.primary.withAlpha(80),
        image: avatarUrl != null && avatarUrl!.isNotEmpty
            ? DecorationImage(
                image: NetworkImage(avatarUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: avatarUrl == null || avatarUrl!.isEmpty
          ? Center(
              child: Text(
                initials,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: fontSize,
                  color: scheme.primary,
                ),
              ),
            )
          : null,
    );
  }
}
