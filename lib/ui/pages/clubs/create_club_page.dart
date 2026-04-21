import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:trackon_mobile/data/providers/groups_provider.dart';

/// Full-screen club creation form. Navigated via
/// `Navigator.push(ClubDetailPage(...))`-style route from the Clubs tab.
/// All fields map 1:1 to the `POST /api/clubs` payload; the only
/// derived bit is the auto-slugged handle preview.
class CreateClubPage extends StatefulWidget {
  const CreateClubPage({super.key});

  @override
  State<CreateClubPage> createState() => _CreateClubPageState();
}

class _CreateClubPageState extends State<CreateClubPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _handleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _sportCtrl = TextEditingController();

  final List<String> _sports = [];
  bool _isPublic = true;
  bool _submitting = false;

  String? _handleError;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    // Rebuild when name changes so the auto-handle preview updates.
    _nameCtrl.addListener(() => setState(() {}));
    _handleCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _handleCtrl.dispose();
    _descCtrl.dispose();
    _locationCtrl.dispose();
    _sportCtrl.dispose();
    super.dispose();
  }

  // ============ HANDLE PREVIEW ============

  /// Slug-ify the name the same way the backend does so the preview
  /// the user sees matches what they'll get on create. Service layer
  /// re-does this; we're just showing the user what's coming.
  String _autoSlug(String s) {
    final lowered = s.toLowerCase();
    final replaced =
        lowered.replaceAll(RegExp(r'[\s_]+'), '-');
    final stripped =
        replaced.replaceAll(RegExp(r'[^a-z0-9-]'), '');
    final collapsed = stripped.replaceAll(RegExp(r'-+'), '-');
    final trimmed = collapsed.replaceAll(RegExp(r'^-|-$'), '');
    return trimmed.length > 40 ? trimmed.substring(0, 40) : trimmed;
  }

  String get _handlePreview {
    final typed = _handleCtrl.text.trim();
    if (typed.isNotEmpty) return typed;
    return _autoSlug(_nameCtrl.text.trim());
  }

  // ============ SPORTS ============

  void _addSport() {
    final raw = _sportCtrl.text.trim();
    if (raw.isEmpty) return;
    // Split on comma so users can paste "Running, Trail" and get two chips.
    final newTags = raw
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && !_sports.contains(s));
    if (newTags.isEmpty) return;
    setState(() {
      _sports.addAll(newTags);
      _sportCtrl.clear();
    });
  }

  // ============ VALIDATION ============

  String? _validateName(String? v) {
    if (v == null || v.trim().isEmpty) return 'Name is required';
    if (v.trim().length > 120) return 'Keep it under 120 characters';
    return null;
  }

  String? _validateHandle(String? v) {
    if (v == null || v.isEmpty) return null; // optional — auto-generated
    final re = RegExp(r'^[a-z0-9][a-z0-9-]{2,39}$');
    if (!re.hasMatch(v)) {
      return '3–40 chars, lowercase letters, digits, hyphens';
    }
    return null;
  }

  // ============ SUBMIT ============

  Future<void> _submit() async {
    setState(() {
      _nameError = null;
      _handleError = null;
    });
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      final club = await context.read<GroupsProvider>().createClub(
            name: _nameCtrl.text.trim(),
            handle: _handleCtrl.text.trim().isEmpty
                ? null
                : _handleCtrl.text.trim(),
            description: _descCtrl.text.trim().isEmpty
                ? null
                : _descCtrl.text.trim(),
            location: _locationCtrl.text.trim().isEmpty
                ? null
                : _locationCtrl.text.trim(),
            sportTypes: _sports.isEmpty ? null : List.of(_sports),
            isPublic: _isPublic,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${club.name} created')),
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final msg = e.response?.data is Map
          ? (e.response!.data['message'] ?? e.response!.data['error'])
              ?.toString()
          : null;
      if (!mounted) return;
      setState(() {
        if (status == 409) {
          // Handle taken.
          _handleError =
              'This handle is taken — pick another.';
        } else if (status == 400 && msg != null) {
          // Could be a name or handle problem — the server lumps them
          // into one 400. Surface the message near whichever field is
          // more likely to be the culprit.
          if (msg.toLowerCase().contains('handle')) {
            _handleError = msg;
          } else {
            _nameError = msg;
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not create club')),
          );
        }
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not create club')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ============ BUILD ============

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final canSubmit =
        _nameCtrl.text.trim().isNotEmpty && !_submitting;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create club'),
        actions: [
          TextButton(
            onPressed: canSubmit ? _submit : null,
            child: _submitting
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text('Create',
                    style: TextStyle(
                      color: canSubmit
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    )),
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
              _SectionLabel(label: 'Basics'),
              _InputCard(
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameCtrl,
                      autofocus: true,
                      maxLength: 120,
                      decoration: InputDecoration(
                        labelText: 'Club name',
                        border: InputBorder.none,
                        errorText: _nameError,
                      ),
                      validator: _validateName,
                    ),
                    Divider(height: 1, color: scheme.outlineVariant),
                    TextFormField(
                      controller: _handleCtrl,
                      inputFormatters: [
                        // Lowercase-only as user types, matches format.
                        FilteringTextInputFormatter.allow(
                            RegExp(r'[a-z0-9-]')),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Handle (optional)',
                        prefixText: '@',
                        // Show the auto-slug so the user knows what
                        // they'll get if they leave this blank.
                        helperText: _handleCtrl.text.isEmpty &&
                                _handlePreview.isNotEmpty
                            ? 'Will be @$_handlePreview'
                            : '3–40 chars, lowercase, digits, hyphens',
                        border: InputBorder.none,
                        errorText: _handleError,
                      ),
                      validator: _validateHandle,
                    ),
                    Divider(height: 1, color: scheme.outlineVariant),
                    TextFormField(
                      controller: _descCtrl,
                      maxLines: 4,
                      maxLength: 1000,
                      decoration: const InputDecoration(
                        labelText: 'Description (optional)',
                        border: InputBorder.none,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              _SectionLabel(label: 'Visibility'),
              _VisibilityPicker(
                isPublic: _isPublic,
                onChanged: (v) => setState(() => _isPublic = v),
              ),

              const SizedBox(height: 20),
              _SectionLabel(label: 'Sports'),
              _SportsEditor(
                sports: _sports,
                controller: _sportCtrl,
                onAdd: _addSport,
                onRemove: (s) => setState(() => _sports.remove(s)),
              ),

              const SizedBox(height: 20),
              _SectionLabel(label: 'Location'),
              _InputCard(
                child: TextFormField(
                  controller: _locationCtrl,
                  maxLength: 120,
                  decoration: const InputDecoration(
                    labelText: 'Location (optional)',
                    helperText: 'City, country, or "Online"',
                    border: InputBorder.none,
                  ),
                ),
              ),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: canSubmit ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: scheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Create club',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============ SUBWIDGETS ============

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
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

/// Two-state toggle: Public vs Private. Subtitle explains each.
class _VisibilityPicker extends StatelessWidget {
  final bool isPublic;
  final ValueChanged<bool> onChanged;
  const _VisibilityPicker(
      {required this.isPublic, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _option(
          context,
          selected: isPublic,
          icon: Icons.public,
          title: 'Public',
          subtitle: 'Anyone can join and see posts, challenges, and members.',
          onTap: () => onChanged(true),
        ),
        const SizedBox(height: 8),
        _option(
          context,
          selected: !isPublic,
          icon: Icons.lock_outline,
          title: 'Private',
          subtitle: "Users submit a request to join. You choose what "
              'guests can preview in Settings.',
          onTap: () => onChanged(false),
        ),
      ],
    );
  }

  Widget _option(
    BuildContext context, {
    required bool selected,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color ?? scheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Icon(icon,
                color:
                    selected ? scheme.primary : scheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            // Visual selection marker — a radio would trigger
            // deprecation warnings in current Flutter (RadioGroup is
            // the new pattern) and the parent InkWell already handles
            // the tap anyway.
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color:
                  selected ? scheme.primary : scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// Free-text chip editor for sport tags. Comma-separated paste is
/// split into multiple chips. Tap the × on a chip to remove.
class _SportsEditor extends StatelessWidget {
  final List<String> sports;
  final TextEditingController controller;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;
  const _SportsEditor({
    required this.sports,
    required this.controller,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        _InputCard(
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Add a sport',
                    helperText: 'e.g. Running, Trail, Cycling',
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => onAdd(),
                ),
              ),
              IconButton(
                icon: Icon(Icons.add, color: scheme.primary),
                onPressed: onAdd,
              ),
            ],
          ),
        ),
        if (sports.isNotEmpty) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: sports.map((s) {
                return Chip(
                  label: Text(s),
                  onDeleted: () => onRemove(s),
                  backgroundColor: scheme.primary.withAlpha(30),
                  side: BorderSide(color: scheme.primary.withAlpha(80)),
                  labelStyle: TextStyle(
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12),
                  deleteIconColor: scheme.primary,
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }
}
