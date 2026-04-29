import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../data/models/post.dart' as post_model;
import '../../../../data/providers/groups_provider.dart';
import '../../../sharedwidgets/post_attachments_viewer.dart';
import '../../../sharedwidgets/profile_page.dart';
import '../../groups/post_detail_page.dart';

/// Mixed timeline of club + user posts the viewer is allowed to see.
/// Pull to refresh; tap a card to open the detail page; tap the
/// avatar/name to open the author's profile.
class FeedTab extends StatelessWidget {
  const FeedTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GroupsProvider>();
    final feed = provider.feed;

    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (feed.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.dynamic_feed, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('No posts yet',
                style: TextStyle(color: Colors.grey.shade500)),
            const SizedBox(height: 8),
            Text('Follow clubs and add friends to see posts',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => provider.loadFeed(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: feed.length,
        itemBuilder: (context, index) => _PostCard(post: feed[index]),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final post_model.Post post;
  const _PostCard({required this.post});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cardColor = Theme.of(context).cardTheme.color ?? scheme.surface;
    final initials = post.authorName.isNotEmpty
        ? post.authorName
            .split(' ')
            .map((e) => e.isNotEmpty ? e[0] : '')
            .take(2)
            .join()
        : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author row
          InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => ProfilePage(userId: post.authorId)),
            ),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scheme.primary.withAlpha(80),
                      image: post.authorAvatarUrl != null &&
                              post.authorAvatarUrl!.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(post.authorAvatarUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: post.authorAvatarUrl == null ||
                            post.authorAvatarUrl!.isEmpty
                        ? Center(
                            child: Text(initials,
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                    color: scheme.primary)))
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(post.authorName,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        if (post.clubName != null)
                          Text(post.clubName!,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.primary,
                                  fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  Text(localDateTime(post.createdAt),
                      style: TextStyle(
                          fontSize: 12, color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
          ),

          // Content + attachments — tap anywhere here to open detail.
          InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => PostDetailPage(post: post)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: Text(
                    post.content,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(height: 1.45),
                  ),
                ),
                if (post.attachments.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                    child:
                        PostAttachmentsViewer(attachments: post.attachments),
                  ),
              ],
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
                  onTap: () => context
                      .read<GroupsProvider>()
                      .likePost(post.kind, post.id, true),
                ),
                _ActionBtn(
                  icon: post.userLiked == false
                      ? Icons.thumb_down_rounded
                      : Icons.thumb_down_outlined,
                  label: '${post.dislikes}',
                  color: post.userLiked == false
                      ? scheme.primary
                      : scheme.onSurfaceVariant,
                  onTap: () => context
                      .read<GroupsProvider>()
                      .likePost(post.kind, post.id, false),
                ),
                _ActionBtn(
                  icon: Icons.mode_comment_outlined,
                  label: '${post.commentCount}',
                  color: scheme.onSurfaceVariant,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => PostDetailPage(post: post)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Local date + time, e.g. "28 Apr · 14:32" (current year) or
/// "12 Mar 2024 · 14:32" (prior years). Top-level (not private) so
/// other group-tab files can reuse the exact same formatting.
String localDateTime(String iso) {
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
  } catch (_) {
    return '';
  }
}
