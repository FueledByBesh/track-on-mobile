import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../data/models/activity.dart';
import '../../../data/models/post.dart';
import '../../../data/providers/activity_history_provider.dart';
import '../../../data/providers/groups_provider.dart';
import '../../../data/services/storage_service.dart';

// ─── Composer attachment (local state before submit) ─────────────────────────

enum _AttachmentKind { image, activity }

class _ComposerAttachment {
  final _AttachmentKind kind;

  // IMAGE
  final Uint8List? imageBytes;
  final String? imageMime;
  final String? tempMediaId; // set after upload completes
  bool uploading;
  bool uploadFailed;

  // ACTIVITY
  final ActivitySummary? activity;

  _ComposerAttachment.image({
    required this.imageBytes,
    required this.imageMime,
    this.tempMediaId,
    this.uploading = false,
  })  : kind = _AttachmentKind.image,
        uploadFailed = false,
        activity = null;

  _ComposerAttachment.activity({required this.activity})
      : kind = _AttachmentKind.activity,
        imageBytes = null,
        imageMime = null,
        tempMediaId = null,
        uploading = false,
        uploadFailed = false;

  /// Ready to submit: image must have finished uploading; activity just
  /// needs a non-null refId.
  bool get isReady => kind == _AttachmentKind.activity ||
      (tempMediaId != null && !uploading && !uploadFailed);
}

// ─── Page ─────────────────────────────────────────────────────────────────────

class CreatePostPage extends StatefulWidget {
  final String? preselectedClubId;
  final String? preselectedClubName;

  const CreatePostPage({
    super.key,
    this.preselectedClubId,
    this.preselectedClubName,
  });

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final _contentCtrl = TextEditingController();
  final _imagePicker = ImagePicker();
  bool _submitting = false;

  String? _selectedClubId;
  String? _selectedClubName;

  final List<_ComposerAttachment> _attachments = [];

  @override
  void initState() {
    super.initState();
    _selectedClubId = widget.preselectedClubId;
    _selectedClubName = widget.preselectedClubName;
    _contentCtrl.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ActivityHistoryProvider>().loadHistory();
    });
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    super.dispose();
  }

  bool get _canPost =>
      _contentCtrl.text.trim().isNotEmpty &&
      !_submitting &&
      _attachments.every((a) => a.isReady);

  // ── Picking images ──────────────────────────────────────────────────────────

  Future<void> _pickImages() async {
    final picked = await _imagePicker.pickMultiImage(imageQuality: 85);
    if (picked.isEmpty) return;
    for (final file in picked) {
      final bytes = await file.readAsBytes();
      final mime = _mimeForExtension(file.name.split('.').last.toLowerCase());
      final attachment = _ComposerAttachment.image(
        imageBytes: bytes,
        imageMime: mime,
        uploading: true,
      );
      setState(() => _attachments.add(attachment));
      _uploadImage(attachment);
    }
  }

  Future<void> _uploadImage(_ComposerAttachment attachment) async {
    try {
      final storage = context.read<StorageApiService>();
      final plan = await storage.requestUploadUrl(
        kind: 'post_image',
        contentType: attachment.imageMime ?? 'image/jpeg',
      );
      await storage.uploadBytes(
        plan: plan,
        bytes: attachment.imageBytes!,
        contentType: attachment.imageMime ?? 'image/jpeg',
      );
      if (mounted) {
        setState(() {
          attachment.uploading = false;
          // tempMediaId is final — reconstruct the attachment in-place
          // by replacing it in the list.
          final idx = _attachments.indexOf(attachment);
          if (idx != -1) {
            _attachments[idx] = _ComposerAttachment.image(
              imageBytes: attachment.imageBytes,
              imageMime: attachment.imageMime,
              tempMediaId: plan.tempMediaId,
            );
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          attachment.uploading = false;
          attachment.uploadFailed = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image upload failed — tap × to remove')),
        );
      }
    }
  }

  // ── Activity picker ─────────────────────────────────────────────────────────

  Future<void> _pickActivity() async {
    final history =
        context.read<ActivityHistoryProvider>().history;
    if (history.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No activities found')),
      );
      return;
    }
    final scheme = Theme.of(context).colorScheme;
    final cardColor = Theme.of(context).cardTheme.color ?? scheme.surface;

    final picked = await showModalBottomSheet<ActivitySummary>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scroll) => Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(children: [
                  Expanded(
                    child: Text('Attach Activity',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ]),
              ),
              Divider(height: 1, color: scheme.outlineVariant),
              Expanded(
                child: ListView.builder(
                  controller: scroll,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: history.length,
                  itemBuilder: (_, i) {
                    final a = history[i];
                    final alreadyAdded = _attachments.any(
                        (att) =>
                            att.kind == _AttachmentKind.activity &&
                            att.activity?.id == a.id);
                    return ListTile(
                      leading: Icon(Icons.directions_run,
                          color: alreadyAdded
                              ? scheme.outlineVariant
                              : scheme.primary),
                      title: Text(a.activityType,
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: alreadyAdded
                                  ? scheme.onSurfaceVariant
                                  : scheme.onSurface)),
                      subtitle: Text(
                          '${a.distanceKm.toStringAsFixed(2)} km · ${_formatDate(a.startTime)}',
                          style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant)),
                      trailing: alreadyAdded
                          ? Icon(Icons.check,
                              color: scheme.primary, size: 18)
                          : null,
                      enabled: !alreadyAdded,
                      onTap: alreadyAdded
                          ? null
                          : () => Navigator.pop(context, a),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (picked != null && mounted) {
      setState(() => _attachments
          .add(_ComposerAttachment.activity(activity: picked)));
    }
  }

  // ── Reorder & remove ────────────────────────────────────────────────────────

  void _removeAttachment(int index) =>
      setState(() => _attachments.removeAt(index));

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _attachments.removeAt(oldIndex);
      _attachments.insert(newIndex, item);
    });
  }

  // ── Submit ──────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    final content = _contentCtrl.text.trim();
    if (content.isEmpty) return;
    setState(() => _submitting = true);
    try {
      final requests = _attachments.map((a) {
        if (a.kind == _AttachmentKind.image) {
          return PostAttachmentRequest(
            kind: PostAttachmentKind.image,
            tempMediaId: a.tempMediaId,
          );
        } else {
          return PostAttachmentRequest(
            kind: PostAttachmentKind.activity,
            refId: a.activity!.id,
          );
        }
      }).toList();

      final provider = context.read<GroupsProvider>();
      if (_selectedClubId != null) {
        await provider.createClubPost(
          clubId: _selectedClubId!,
          content: content,
          attachments: requests,
        );
      } else {
        await provider.createUserPost(
          content: content,
          attachments: requests,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ── Club selector ───────────────────────────────────────────────────────────

  Future<void> _pickClub() async {
    final provider = context.read<GroupsProvider>();
    final clubs = provider.allMyClubs;
    if (clubs.isEmpty) return;
    final scheme = Theme.of(context).colorScheme;
    final cardColor = Theme.of(context).cardTheme.color ?? scheme.surface;

    final result = await showModalBottomSheet<({String? id, String? name})>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Text('Post to',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
              ListTile(
                leading: Icon(Icons.person_outline,
                    color: _selectedClubId == null
                        ? scheme.primary
                        : scheme.onSurfaceVariant),
                title: const Text('Personal post'),
                trailing: _selectedClubId == null
                    ? Icon(Icons.check, color: scheme.primary)
                    : null,
                onTap: () =>
                    Navigator.pop(context, (id: null, name: null)),
              ),
              const Divider(height: 1),
              ...clubs.map((c) => ListTile(
                    leading: Icon(Icons.groups_outlined,
                        color: _selectedClubId == c.id
                            ? scheme.primary
                            : scheme.onSurfaceVariant),
                    title: Text(c.name),
                    subtitle: Text('@${c.handle}',
                        style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant)),
                    trailing: _selectedClubId == c.id
                        ? Icon(Icons.check, color: scheme.primary)
                        : null,
                    onTap: () =>
                        Navigator.pop(context, (id: c.id, name: c.name)),
                  )),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _selectedClubId = result.id;
        _selectedClubName = result.name;
      });
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final locked = widget.preselectedClubId != null;
    final hasClubs = context.watch<GroupsProvider>().allMyClubs.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Post',
            style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : FilledButton(
                    onPressed: _canPost ? _submit : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: scheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Text('Post',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
          ),
        ],
      ),
      body: Column(
        children: [
          Divider(height: 1, color: scheme.outlineVariant),

          // Club selector row
          if (hasClubs || locked)
            InkWell(
              onTap: locked ? null : _pickClub,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Icon(
                      _selectedClubId != null
                          ? Icons.groups_outlined
                          : Icons.person_outline,
                      size: 18,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _selectedClubId != null
                          ? (_selectedClubName ?? 'Club post')
                          : 'Personal post',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: scheme.primary,
                      ),
                    ),
                    if (!locked) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.expand_more,
                          size: 16, color: scheme.primary),
                    ],
                  ],
                ),
              ),
            ),

          if (hasClubs || locked)
            Divider(height: 1, color: scheme.outlineVariant),

          // Text input
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: TextField(
                controller: _contentCtrl,
                autofocus: true,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: Theme.of(context).textTheme.bodyLarge,
                decoration: InputDecoration(
                  hintText: "What's on your mind?",
                  hintStyle: TextStyle(color: scheme.onSurfaceVariant),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),

          // Attachment preview strip
          if (_attachments.isNotEmpty)
            _AttachmentStrip(
              attachments: _attachments,
              onRemove: _removeAttachment,
              onReorder: _onReorder,
            ),

          // Bottom toolbar
          _BottomToolbar(
            onPickImages: _pickImages,
            onPickActivity: _pickActivity,
          ),
        ],
      ),
    );
  }
}

// ─── Attachment preview strip ─────────────────────────────────────────────────

class _AttachmentStrip extends StatelessWidget {
  final List<_ComposerAttachment> attachments;
  final void Function(int) onRemove;
  final void Function(int, int) onReorder;

  const _AttachmentStrip({
    required this.attachments,
    required this.onRemove,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 100,
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: ReorderableListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: attachments.length,
        onReorder: onReorder,
        proxyDecorator: (child, _, _) => child,
        itemBuilder: (_, i) {
          final a = attachments[i];
          return _AttachmentThumb(
            key: ValueKey('att_$i'),
            attachment: a,
            onRemove: () => onRemove(i),
          );
        },
      ),
    );
  }
}

class _AttachmentThumb extends StatelessWidget {
  final _ComposerAttachment attachment;
  final VoidCallback onRemove;

  const _AttachmentThumb(
      {super.key, required this.attachment, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget content;

    if (attachment.kind == _AttachmentKind.image) {
      if (attachment.uploading) {
        content = Container(
          width: 76,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Center(
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))),
        );
      } else if (attachment.uploadFailed) {
        content = Container(
          width: 76,
          decoration: BoxDecoration(
            color: scheme.errorContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
              child: Icon(Icons.error_outline,
                  color: scheme.onErrorContainer, size: 24)),
        );
      } else {
        content = ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.memory(
            attachment.imageBytes!,
            width: 76,
            height: 84,
            fit: BoxFit.cover,
          ),
        );
      }
    } else {
      content = Container(
        width: 76,
        decoration: BoxDecoration(
          color: scheme.primary.withAlpha(20),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: scheme.primary.withAlpha(60)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_run, color: scheme.primary, size: 24),
            const SizedBox(height: 4),
            Text(
              attachment.activity?.activityType ?? 'Activity',
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontSize: 9, color: scheme.primary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: SizedBox(
        width: 76,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            content,
            Positioned(
              top: -6,
              right: -6,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: scheme.onSurface,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.close,
                      size: 12, color: scheme.surface),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Bottom toolbar ───────────────────────────────────────────────────────────

class _BottomToolbar extends StatelessWidget {
  final VoidCallback onPickImages;
  final VoidCallback onPickActivity;

  const _BottomToolbar({
    required this.onPickImages,
    required this.onPickActivity,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: scheme.outlineVariant)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: _ToolbarButton(
                icon: Icons.photo_library_outlined,
                label: 'Attach Photo',
                onTap: onPickImages,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ToolbarButton(
                icon: Icons.directions_run,
                label: 'Attach Activity',
                onTap: onPickActivity,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        decoration: BoxDecoration(
          color: scheme.primary.withAlpha(20),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.primary.withAlpha(60)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: scheme.primary),
            const SizedBox(width: 10),
            Text(label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: scheme.primary,
                )),
          ],
        ),
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

String _mimeForExtension(String ext) => switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };

String _formatDate(String iso) {
  try {
    final dt = DateTime.parse(iso).toLocal();
    return '${dt.day}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  } catch (_) {
    return iso;
  }
}
