import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:trackon_mobile/data/models/user.dart';
import 'package:trackon_mobile/data/services/storage_service.dart';
import 'package:trackon_mobile/data/services/user_service.dart';

import 'user_avatar.dart';

enum _AvatarAction { change, remove }

/// Self-only profile edit form.
///
/// The Save button in the AppBar is disabled until the form is dirty
/// (at least one field differs from the initial [UserProfile]) and
/// re-enables as soon as anything changes. That keeps the "nothing to
/// save" no-op out of reach and gives a clear visual affordance for
/// whether there's pending work.
///
/// The avatar section opens a pick → compress → upload flow. The
/// upload goes direct-to-GCS via a signed PUT URL from
/// `/api/storage/uploads`; on success the stored reference is the
/// resulting public URL and the page is marked dirty so Save can
/// persist it onto `users.avatar_image_url`.
class EditProfilePage extends StatefulWidget {
  final UserProfile profile;
  const EditProfilePage({super.key, required this.profile});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstCtrl;
  late final TextEditingController _lastCtrl;
  late final TextEditingController _handleCtrl;
  late final TextEditingController _bioCtrl;
  late final TextEditingController _locationCtrl;

  /// Latest server-committed profile. Mutates when the avatar is
  /// saved eagerly (upload / remove) so the dirty-tracking baseline
  /// reflects what the server actually holds and the caller receives
  /// the most recent state on pop.
  late UserProfile _committed;

  bool _submitting = false;
  bool _uploading = false;
  double _uploadProgress = 0;
  String? _handleError;

  @override
  void initState() {
    super.initState();
    _committed = widget.profile;
    _firstCtrl = TextEditingController(text: _committed.firstName);
    _lastCtrl = TextEditingController(text: _committed.lastName);
    _handleCtrl = TextEditingController(text: _committed.handle);
    _bioCtrl = TextEditingController(text: _committed.bio ?? '');
    _locationCtrl = TextEditingController(text: _committed.location ?? '');

    for (final c in [
      _firstCtrl,
      _lastCtrl,
      _handleCtrl,
      _bioCtrl,
      _locationCtrl,
    ]) {
      c.addListener(_onFieldChanged);
    }
  }

  @override
  void dispose() {
    for (final c in [
      _firstCtrl,
      _lastCtrl,
      _handleCtrl,
      _bioCtrl,
      _locationCtrl,
    ]) {
      c.removeListener(_onFieldChanged);
      c.dispose();
    }
    super.dispose();
  }

  /// Triggered on every keystroke via controller listeners. Cheap —
  /// just flips the Save button color/enabled state when the form
  /// crosses the dirty/clean boundary.
  void _onFieldChanged() {
    // No need to compute anything here; the getter recomputes on
    // rebuild. We just need the rebuild.
    setState(() {});
  }

  /// True iff any text field differs from the last committed profile.
  /// Avatar is excluded — it's persisted eagerly on upload/remove so
  /// there's never a pending-avatar state for Save to cover.
  bool get _dirty {
    final p = _committed;
    return _firstCtrl.text.trim() != p.firstName ||
        _lastCtrl.text.trim() != p.lastName ||
        _handleCtrl.text.trim() != p.handle ||
        _bioCtrl.text != (p.bio ?? '') ||
        _locationCtrl.text != (p.location ?? '');
  }

  bool get _canSave => _dirty && !_submitting && !_uploading;

  String? _validateHandle(String? v) {
    if (v == null || v.isEmpty) return 'Required';
    final re = RegExp(r'^[a-z0-9][a-z0-9-]{2,39}$');
    if (!re.hasMatch(v)) {
      return '3–40 chars, lowercase letters, digits, hyphens';
    }
    return null;
  }

  // ============ AVATAR: OPTIONS SHEET ============

  /// Opens a bottom sheet with Change / Remove actions. Remove is
  /// hidden when there's no avatar to remove.
  Future<void> _openAvatarOptions() async {
    if (_uploading || _submitting) return;
    final hasAvatar = (_committed.avatarImageUrl ?? '').isNotEmpty;
    final action = await showModalBottomSheet<_AvatarAction>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.upload_outlined),
              title: Text(hasAvatar ? 'Change photo' : 'Upload a photo'),
              onTap: () => Navigator.pop(ctx, _AvatarAction.change),
            ),
            if (hasAvatar)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'Remove photo',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () => Navigator.pop(ctx, _AvatarAction.remove),
              ),
          ],
        ),
      ),
    );
    if (action == _AvatarAction.change) {
      await _pickAndUploadAvatar();
    } else if (action == _AvatarAction.remove) {
      await _removeAvatar();
    }
  }

  /// Pick → compress → upload → PATCH profile immediately. Avatar is
  /// always persisted eagerly so orphan objects never accumulate in
  /// GCS from a user who picked an image and backed out.
  Future<void> _pickAndUploadAvatar() async {
    if (_uploading) return;
    // Grab context-bound services up front so the async gaps below
    // don't rely on the live BuildContext.
    final storage = context.read<StorageApiService>();
    final users = context.read<UserApiService>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        // Request a bounded size at capture; we still re-encode below
        // for consistency, but this lets the picker skip loading
        // multi-MB originals into memory.
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 90,
      );
      if (picked == null) return;

      setState(() {
        _uploading = true;
        _uploadProgress = 0;
      });

      // Re-compress to a known JPEG target so the server-side MIME
      // check (image/jpeg only for avatars) matches byte-for-byte.
      final bytes = await FlutterImageCompress.compressWithFile(
        picked.path,
        quality: 82,
        minWidth: 512,
        minHeight: 512,
        format: CompressFormat.jpeg,
      );
      final payload = bytes ?? await picked.readAsBytes();

      final plan = await storage.requestUploadUrl(
        kind: 'avatar',
        contentType: 'image/jpeg',
      );

      await storage.uploadBytes(
        plan: plan,
        bytes: Uint8List.fromList(payload),
        contentType: 'image/jpeg',
        onProgress: (sent, total) {
          if (!mounted || total <= 0) return;
          setState(() => _uploadProgress = sent / total);
        },
      );

      // Persist the new URL on the server immediately. Backend also
      // deletes the replaced GCS object on its side.
      final newUrl = plan.publicUrl ?? plan.objectPath;
      final updated = await users.updateMe(avatarImageUrl: newUrl);

      if (!mounted) return;
      setState(() {
        _committed = updated;
        _uploading = false;
        _uploadProgress = 1;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _uploadProgress = 0;
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not upload image')),
      );
    }
  }

  /// Clear the avatar: delete on the server (which also deletes the
  /// bucket object) and update the local baseline.
  Future<void> _removeAvatar() async {
    if (_uploading) return;
    final users = context.read<UserApiService>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _uploading = true);
    try {
      final updated = await users.removeAvatar();
      if (!mounted) return;
      setState(() {
        _committed = updated;
        _uploading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _uploading = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not remove photo')),
      );
    }
  }

  // ============ SAVE ============

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _handleError = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      final updated = await context.read<UserApiService>().updateMe(
            firstName: _firstCtrl.text.trim(),
            lastName: _lastCtrl.text.trim(),
            handle: _handleCtrl.text.trim(),
            bio: _bioCtrl.text,
            location: _locationCtrl.text,
          );
      if (!mounted) return;
      Navigator.pop(context, updated);
    } on DioException catch (e) {
      if (!mounted) return;
      if (e.response?.statusCode == 409) {
        setState(() => _handleError = 'This handle is taken — pick another');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not save changes')));
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save changes')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopScope<UserProfile>(
      canPop: false,
      // Any exit from this page — Save, AppBar back, system back —
      // should hand the latest committed profile back to the caller
      // so avatar-only changes (persisted eagerly on upload/remove)
      // don't get lost when the user doesn't have any text-field
      // changes to save.
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.pop(context, _committed);
      },
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Edit profile'),
        actions: [
          TextButton(
            onPressed: _canSave ? _save : null,
            child: _submitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'Save',
                    style: TextStyle(
                      color: _canSave
                          ? scheme.primary
                          : scheme.onSurfaceVariant.withAlpha(120),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: _submitting,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _AvatarSection(
                profile: _committed,
                uploading: _uploading,
                progress: _uploadProgress,
                onTap: _openAvatarOptions,
              ),
              const SizedBox(height: 24),
              _SectionLabel(label: 'Name'),
              _InputCard(
                child: Column(
                  children: [
                    TextFormField(
                      controller: _firstCtrl,
                      decoration: const InputDecoration(
                          labelText: 'First name', border: InputBorder.none),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    Divider(height: 1, color: scheme.outlineVariant),
                    TextFormField(
                      controller: _lastCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Last name', border: InputBorder.none),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _SectionLabel(label: 'Handle'),
              _InputCard(
                child: TextFormField(
                  controller: _handleCtrl,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9-]')),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Handle',
                    prefixText: '@',
                    helperText:
                        '3–40 chars, lowercase letters, digits, hyphens',
                    errorText: _handleError,
                    border: InputBorder.none,
                  ),
                  validator: _validateHandle,
                ),
              ),
              const SizedBox(height: 20),
              _SectionLabel(label: 'About'),
              _InputCard(
                child: Column(
                  children: [
                    TextFormField(
                      controller: _bioCtrl,
                      maxLines: 4,
                      maxLength: 500,
                      decoration: const InputDecoration(
                        labelText: 'Bio',
                        border: InputBorder.none,
                      ),
                    ),
                    Divider(height: 1, color: scheme.outlineVariant),
                    TextFormField(
                      controller: _locationCtrl,
                      maxLength: 120,
                      decoration: const InputDecoration(
                          labelText: 'Location',
                          helperText: 'City, country, or "Online"',
                          border: InputBorder.none),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

/// Top-of-form avatar preview + action button. Tapping the button
/// opens the Change / Remove bottom sheet. While an upload or remove
/// is in flight the avatar shows a progress overlay and the button
/// is disabled.
class _AvatarSection extends StatelessWidget {
  final UserProfile profile;
  final bool uploading;
  final double progress;
  final VoidCallback onTap;

  const _AvatarSection({
    required this.profile,
    required this.uploading,
    required this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasAvatar = (profile.avatarImageUrl ?? '').isNotEmpty;

    return Center(
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              UserAvatar(profile: profile, sizePx: 108),
              if (uploading)
                Container(
                  width: 108,
                  height: 108,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withAlpha(100),
                  ),
                  child: Center(
                    child: SizedBox(
                      width: 36,
                      height: 36,
                      child: CircularProgressIndicator(
                        value: progress > 0 && progress < 1 ? progress : null,
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: uploading ? null : onTap,
            icon: Icon(
              hasAvatar ? Icons.edit_outlined : Icons.upload_outlined,
              size: 18,
            ),
            label: Text(
              hasAvatar ? 'Change photo' : 'Upload a photo',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            style: TextButton.styleFrom(
              foregroundColor: scheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _InputCard extends StatelessWidget {
  final Widget child;
  const _InputCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? scheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: child,
    );
  }
}
