import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trackon_mobile/data/models/club.dart';
import 'package:trackon_mobile/data/models/club_settings.dart';
import 'package:trackon_mobile/data/providers/groups_provider.dart';
import 'package:trackon_mobile/data/services/club_service.dart';

/// Owner-only configuration surface. Four tabs:
///   - General: identity fields + visibility overrides
///   - Admins: member role management
///   - Permissions: role-gated action knobs
///   - Critical: transfer ownership + delete
///
/// Takes the current [Club] on construction so the initial render is
/// immediate; the tabs each issue their own API calls for anything
/// they own (settings, members list, transfers).
class ClubSettingsPage extends StatefulWidget {
  final Club club;
  const ClubSettingsPage({super.key, required this.club});

  @override
  State<ClubSettingsPage> createState() => _ClubSettingsPageState();
}

class _ClubSettingsPageState extends State<ClubSettingsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Club Settings'),
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: scheme.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: scheme.primary,
          tabs: const [
            Tab(text: 'General'),
            Tab(text: 'Admins'),
            Tab(text: 'Permissions'),
            Tab(text: 'Critical'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _GeneralTab(club: widget.club),
          _AdminsTab(club: widget.club),
          _PermissionsTab(club: widget.club),
          _CriticalTab(club: widget.club),
        ],
      ),
    );
  }
}

// ============ GENERAL ============

class _GeneralTab extends StatefulWidget {
  final Club club;
  const _GeneralTab({required this.club});

  @override
  State<_GeneralTab> createState() => _GeneralTabState();
}

class _GeneralTabState extends State<_GeneralTab> {
  late TextEditingController _nameCtrl;
  late TextEditingController _handleCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _locationCtrl;
  late TextEditingController _sportsCtrl;
  late bool _isPublic;
  late bool _showPosts;
  late bool _showChallenges;
  late bool _showMembers;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.club.name);
    _handleCtrl = TextEditingController(text: widget.club.handle);
    _descCtrl = TextEditingController(text: widget.club.description ?? '');
    _locationCtrl = TextEditingController(text: widget.club.location ?? '');
    _sportsCtrl =
        TextEditingController(text: widget.club.sportTypes.join(', '));
    _isPublic = widget.club.isPublic;
    _showPosts = widget.club.nonMembersCanViewPosts;
    _showChallenges = widget.club.nonMembersCanViewChallenges;
    _showMembers = widget.club.nonMembersCanViewMembers;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _handleCtrl.dispose();
    _descCtrl.dispose();
    _locationCtrl.dispose();
    _sportsCtrl.dispose();
    super.dispose();
  }

  /// Saves identity fields via PATCH and, if any non-member visibility
  /// override changed, PUTs the settings. Two round-trips but both
  /// endpoints are cheap and this keeps the service boundaries clean.
  Future<void> _save() async {
    setState(() => _saving = true);
    final clubs = context.read<ClubApiService>();
    try {
      await clubs.update(
        widget.club.id,
        name: _nameCtrl.text.trim(),
        handle: _handleCtrl.text.trim(),
        description: _descCtrl.text,
        location: _locationCtrl.text,
        sportTypes: _sportsCtrl.text
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
        isPublic: _isPublic,
      );

      // Settings diff — only PUT if a visibility override flipped, so
      // we don't bump the settings row's updated_at for no reason.
      final startingPosts = widget.club.nonMembersCanViewPosts;
      final startingChallenges = widget.club.nonMembersCanViewChallenges;
      final startingMembers = widget.club.nonMembersCanViewMembers;
      if (_showPosts != startingPosts ||
          _showChallenges != startingChallenges ||
          _showMembers != startingMembers) {
        await clubs.updateSettings(
          widget.club.id,
          ClubSettings.patch(
            nonMembersCanViewPosts: _showPosts,
            nonMembersCanViewChallenges: _showChallenges,
            nonMembersCanViewMembers: _showMembers,
          ),
        );
      }

      if (!mounted) return;
      // Refresh the grouping so the Clubs tab shows any renamed / re-
      // handled club on return.
      context.read<GroupsProvider>().loadMyClubs();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Saved')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Could not save')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionLabel(label: 'Basics'),
        _InputCard(
          child: Column(
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Club name',
                  border: InputBorder.none,
                ),
              ),
              Divider(height: 1, color: scheme.outlineVariant),
              TextField(
                controller: _handleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Handle',
                  helperText: 'Used so people can find you easily. '
                      'Lowercase letters, numbers, hyphens.',
                  prefixText: '@',
                  border: InputBorder.none,
                ),
              ),
              Divider(height: 1, color: scheme.outlineVariant),
              TextField(
                controller: _descCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: InputBorder.none,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _SectionLabel(label: 'Metadata'),
        _InputCard(
          child: Column(
            children: [
              TextField(
                controller: _sportsCtrl,
                decoration: const InputDecoration(
                  labelText: 'Sport types',
                  helperText: 'Comma-separated, e.g. Running, Trail',
                  border: InputBorder.none,
                ),
              ),
              Divider(height: 1, color: scheme.outlineVariant),
              TextField(
                controller: _locationCtrl,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  helperText: 'City, country, or "Online"',
                  border: InputBorder.none,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _SectionLabel(label: 'Visibility'),
        _SwitchTile(
          title: _isPublic ? 'Public club' : 'Private club',
          subtitle: _isPublic
              ? 'Anyone can join and see content.'
              : 'Users must request to join.',
          value: _isPublic,
          onChanged: (v) => setState(() => _isPublic = v),
        ),
        if (!_isPublic) ...[
          const SizedBox(height: 12),
          _SectionLabel(label: 'Non-member preview'),
          Text(
            'Choose what guests can see before joining.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          _SwitchTile(
            title: 'Posts',
            subtitle: 'Let guests read posts from members.',
            value: _showPosts,
            onChanged: (v) => setState(() => _showPosts = v),
          ),
          const SizedBox(height: 8),
          _SwitchTile(
            title: 'Challenges',
            subtitle: 'Let guests browse active challenges.',
            value: _showChallenges,
            onChanged: (v) => setState(() => _showChallenges = v),
          ),
          const SizedBox(height: 8),
          _SwitchTile(
            title: 'Members list',
            subtitle: "Let guests see who's in the club.",
            value: _showMembers,
            onChanged: (v) => setState(() => _showMembers = v),
          ),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: scheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: _saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Save changes',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ),
      ],
    );
  }
}

// ============ ADMINS ============

class _AdminsTab extends StatefulWidget {
  final Club club;
  const _AdminsTab({required this.club});

  @override
  State<_AdminsTab> createState() => _AdminsTabState();
}

class _AdminsTabState extends State<_AdminsTab> {
  late Future<List<ClubMember>> _future;
  List<ClubMember>? _members;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<ClubMember>> _load() async {
    final members =
        await context.read<ClubApiService>().getMembers(widget.club.id);
    members.sort((a, b) => a.role.index.compareTo(b.role.index));
    _members = members;
    return members;
  }

  Future<void> _setRole(int i, ClubRole newRole) async {
    final m = _members![i];
    final clubs = context.read<ClubApiService>();
    try {
      final updated = newRole == ClubRole.admin
          ? await clubs.promote(widget.club.id, m.userId)
          : await clubs.demote(widget.club.id, m.userId);
      if (!mounted) return;
      setState(() {
        _members![i] = updated;
        _members!.sort((a, b) => a.role.index.compareTo(b.role.index));
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not change role')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder<List<ClubMember>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError || _members == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Could not load members',
                    style: TextStyle(color: scheme.onSurfaceVariant)),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () =>
                      setState(() => _future = _load()),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final members = _members!;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: members.length,
          itemBuilder: (context, i) {
            final m = members[i];
            final isOwner = m.role == ClubRole.owner;
            final isAdmin = m.role == ClubRole.admin;
            final cardColor =
                Theme.of(context).cardTheme.color ?? scheme.surface;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: scheme.primary.withAlpha(30),
                    child: Text(
                      m.name.isNotEmpty ? m.name[0] : '?',
                      style: TextStyle(
                          color: scheme.primary,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                m.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onSurface,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            _RoleChip(role: m.role),
                          ],
                        ),
                        Text(
                          m.email,
                          style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  if (!isOwner)
                    IconButton(
                      icon: Icon(
                        isAdmin
                            ? Icons.person_remove_alt_1
                            : Icons.shield_outlined,
                        color: scheme.primary,
                      ),
                      tooltip:
                          isAdmin ? 'Demote to member' : 'Promote to admin',
                      onPressed: () => _setRole(i,
                          isAdmin ? ClubRole.member : ClubRole.admin),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ============ PERMISSIONS ============

class _PermissionsTab extends StatefulWidget {
  final Club club;
  const _PermissionsTab({required this.club});

  @override
  State<_PermissionsTab> createState() => _PermissionsTabState();
}

class _PermissionsTabState extends State<_PermissionsTab> {
  late Future<ClubSettings> _future;
  ClubSettings? _settings;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<ClubSettings> _load() async {
    final s =
        await context.read<ClubApiService>().getSettings(widget.club.id);
    _settings = s;
    return s;
  }

  /// Each knob PUTs immediately with just that field set. Makes the UI
  /// feel responsive and avoids a Save button down here — there's
  /// nothing to undo since all changes are atomic and server-echoed.
  Future<void> _save(Map<String, dynamic> patch) async {
    setState(() => _saving = true);
    try {
      final updated = await context
          .read<ClubApiService>()
          .updateSettings(widget.club.id, patch);
      if (!mounted) return;
      setState(() => _settings = updated);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save change')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ClubSettings>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError || _settings == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Could not load settings'),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () =>
                      setState(() => _future = _load()),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final s = _settings!;
        return AbsorbPointer(
          absorbing: _saving,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SectionLabel(label: 'Content'),
              _RoleChoiceTile(
                title: 'Who can post',
                value: s.whoCanPost,
                options: const [
                  ClubRole.owner,
                  ClubRole.admin,
                  ClubRole.member
                ],
                onChanged: (v) =>
                    _save(ClubSettings.patch(whoCanPost: v)),
              ),
              const SizedBox(height: 8),
              _RoleChoiceTile(
                title: 'Who can create challenges',
                value: s.whoCanCreateChallenges,
                options: const [
                  ClubRole.owner,
                  ClubRole.admin,
                  ClubRole.member
                ],
                onChanged: (v) => _save(
                    ClubSettings.patch(whoCanCreateChallenges: v)),
              ),
              const SizedBox(height: 8),
              _SwitchTile(
                title: 'Require approval for posts',
                subtitle: 'Posts by members need an admin to approve '
                    'before going live.',
                value: s.requirePostApproval,
                onChanged: (v) =>
                    _save(ClubSettings.patch(requirePostApproval: v)),
              ),
              const SizedBox(height: 20),
              _SectionLabel(label: 'Membership'),
              _RoleChoiceTile(
                title: 'Who can invite others',
                value: s.whoCanInvite,
                options: const [
                  ClubRole.owner,
                  ClubRole.admin,
                  ClubRole.member
                ],
                onChanged: (v) =>
                    _save(ClubSettings.patch(whoCanInvite: v)),
              ),
              const SizedBox(height: 8),
              _RoleChoiceTile(
                title: 'Who can remove members',
                value: s.whoCanRemoveMembers,
                // Server CHECK constraint forbids MEMBER here.
                options: const [ClubRole.owner, ClubRole.admin],
                onChanged: (v) =>
                    _save(ClubSettings.patch(whoCanRemoveMembers: v)),
              ),
              const SizedBox(height: 8),
              _RoleChoiceTile(
                title: 'Who can approve join requests',
                value: s.whoCanApproveJoinRequests,
                options: const [ClubRole.owner, ClubRole.admin],
                onChanged: (v) => _save(
                    ClubSettings.patch(whoCanApproveJoinRequests: v)),
              ),
              const SizedBox(height: 8),
              _RoleChoiceTile(
                title: 'Who can ban / unban',
                value: s.whoCanBan,
                options: const [ClubRole.owner, ClubRole.admin],
                onChanged: (v) => _save(ClubSettings.patch(whoCanBan: v)),
              ),
              const SizedBox(height: 8),
              _SwitchTile(
                title: 'Allow join without request',
                subtitle: "For private clubs where the owner doesn't "
                    "need to approve anyone — members join directly.",
                value: s.allowJoinWithoutRequest,
                onChanged: (v) =>
                    _save(ClubSettings.patch(allowJoinWithoutRequest: v)),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ============ CRITICAL ============

class _CriticalTab extends StatefulWidget {
  final Club club;
  const _CriticalTab({required this.club});

  @override
  State<_CriticalTab> createState() => _CriticalTabState();
}

class _CriticalTabState extends State<_CriticalTab> {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.orange.withAlpha(20),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.orange.withAlpha(90)),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber, color: Colors.orange),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "These actions can't be undone. Proceed with caution.",
                  style:
                      TextStyle(color: scheme.onSurface, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _DangerActionTile(
          icon: Icons.swap_horiz,
          title: 'Transfer ownership',
          subtitle: 'Hand over this club to another member. They must '
              "accept. You'll become an admin if they do.",
          onTap: () => _showTransferSheet(context),
        ),
        const SizedBox(height: 12),
        _DangerActionTile(
          icon: Icons.delete_forever,
          title: 'Delete club',
          subtitle: 'Permanently remove ${widget.club.name}, its posts, '
              'challenges, and member records.',
          destructive: true,
          onTap: () => _confirmDelete(context),
        ),
      ],
    );
  }

  Future<void> _showTransferSheet(BuildContext context) async {
    final clubs = context.read<ClubApiService>();
    final scheme = Theme.of(context).colorScheme;
    List<ClubMember>? members;
    try {
      members = (await clubs.getMembers(widget.club.id))
          .where((m) => m.role != ClubRole.owner)
          .toList();
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load members')));
      return;
    }

    if (!context.mounted) return;
    if (members.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('No other members to transfer to')));
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Transfer ownership',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                'Pick a member. They\'ll receive a request they can '
                'accept or decline.',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.5),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: members!.length,
                  itemBuilder: (_, i) {
                    final m = members![i];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: scheme.primary.withAlpha(30),
                        child: Text(
                          m.name.isNotEmpty ? m.name[0] : '?',
                          style: TextStyle(color: scheme.primary),
                        ),
                      ),
                      title: Text(m.name),
                      subtitle: Text(m.email),
                      trailing: _RoleChip(role: m.role),
                      onTap: () {
                        Navigator.pop(ctx);
                        _confirmTransfer(context, m);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmTransfer(
      BuildContext context, ClubMember newOwner) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send ownership transfer?'),
        content: Text(
            '${newOwner.name} will be asked to take over as owner. If '
            "they accept, you'll become an admin. They have 7 days to "
            'respond.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (!context.mounted || confirmed != true) return;
    try {
      await context
          .read<ClubApiService>()
          .initiateTransfer(widget.club.id, newOwner.userId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Transfer request sent to ${newOwner.name}')));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send transfer')));
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final typed = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete club?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This will permanently remove ${widget.club.name}. '
                'Type the club name to confirm.'),
            const SizedBox(height: 12),
            TextField(
              controller: typed,
              decoration: InputDecoration(
                hintText: widget.club.name,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (typed.text.trim() == widget.club.name) {
                Navigator.pop(ctx, true);
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!context.mounted || confirmed != true) return;
    try {
      await context.read<ClubApiService>().delete(widget.club.id);
      if (!context.mounted) return;
      // Refresh the "My Clubs" grouping so the now-deleted club
      // disappears on return.
      context.read<GroupsProvider>().loadMyClubs();
      // Pop settings + detail pages.
      Navigator.of(context)
        ..pop()
        ..pop();
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${widget.club.name} deleted')));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete club')));
    }
  }
}

// ============ SHARED WIDGETS ============

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

class _SwitchTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? scheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface)),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                      fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// Role-gated choice tile. Maps between `ClubRole` and a human label on
/// render; saves the typed enum back to the caller.
class _RoleChoiceTile extends StatelessWidget {
  final String title;
  final ClubRole value;
  final List<ClubRole> options;
  final ValueChanged<ClubRole> onChanged;
  const _RoleChoiceTile({
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  static String _label(ClubRole r) => switch (r) {
        ClubRole.owner => 'Owner only',
        ClubRole.admin => 'Admins & owner',
        ClubRole.member => 'All members',
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? scheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: scheme.onSurface)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: options.map((opt) {
              final selected = opt == value;
              return GestureDetector(
                onTap: selected ? null : () => onChanged(opt),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected
                        ? scheme.primary.withAlpha(30)
                        : scheme.surfaceContainerHighest,
                    border: Border.all(
                      color: selected ? scheme.primary : Colors.transparent,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _label(opt),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  final ClubRole role;
  const _RoleChip({required this.role});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg, label) = switch (role) {
      ClubRole.owner =>
        (Colors.amber.withAlpha(40), Colors.amber.shade800, 'OWNER'),
      ClubRole.admin =>
        (scheme.primary.withAlpha(30), scheme.primary, 'ADMIN'),
      ClubRole.member => (
          scheme.surfaceContainerHighest,
          scheme.onSurfaceVariant,
          'MEMBER'
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: fg,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _DangerActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool destructive;
  final VoidCallback onTap;
  const _DangerActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = destructive ? Colors.red : scheme.onSurface;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color ?? scheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: destructive
                ? Colors.red.withAlpha(90)
                : scheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.w700, color: color)),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                        fontSize: 12, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
