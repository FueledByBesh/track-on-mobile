import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:trackon_mobile/data/models/user.dart';
import 'package:trackon_mobile/data/services/user_service.dart';

/// Self-only edit form. Mirrors the shape of CreateClubPage — a
/// handful of text fields + a save button in the app bar. Returns the
/// updated [UserProfile] via `Navigator.pop` so the ProfilePage can
/// swap it in without a second fetch.
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
  late final TextEditingController _avatarCtrl;

  bool _submitting = false;
  String? _handleError;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _firstCtrl = TextEditingController(text: p.firstName);
    _lastCtrl = TextEditingController(text: p.lastName);
    _handleCtrl = TextEditingController(text: p.handle);
    _bioCtrl = TextEditingController(text: p.bio ?? '');
    _locationCtrl = TextEditingController(text: p.location ?? '');
    _avatarCtrl = TextEditingController(text: p.avatarImageUrl ?? '');
  }

  @override
  void dispose() {
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    _handleCtrl.dispose();
    _bioCtrl.dispose();
    _locationCtrl.dispose();
    _avatarCtrl.dispose();
    super.dispose();
  }

  String? _validateHandle(String? v) {
    if (v == null || v.isEmpty) return 'Required';
    final re = RegExp(r'^[a-z0-9][a-z0-9-]{2,39}$');
    if (!re.hasMatch(v)) {
      return '3–40 chars, lowercase letters, digits, hyphens';
    }
    return null;
  }

  Future<void> _save() async {
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
            avatarImageUrl:
                _avatarCtrl.text.trim().isEmpty ? null : _avatarCtrl.text.trim(),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit profile'),
        actions: [
          TextButton(
            onPressed: _submitting ? null : _save,
            child: _submitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child:
                        CircularProgressIndicator(strokeWidth: 2))
                : Text('Save',
                    style: TextStyle(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700)),
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
                    Divider(height: 1, color: scheme.outlineVariant),
                    TextFormField(
                      controller: _avatarCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Avatar URL',
                          helperText:
                              'Paste an image URL. Upload UI comes later.',
                          border: InputBorder.none),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
