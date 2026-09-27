import 'package:flutter/material.dart';

import '../../data/account_options.dart';
import '../../services/account_controller.dart';
import '../../theme/medivo_palette.dart';
import '../../theme/medivo_text.dart';
import '../../widgets/form_message.dart';
import '../../widgets/medivo_app_bar.dart';

/// Super administrators only (blueprint §23, §39). The database also
/// checks the permission, so this screen cannot be misused.
class UsersRolesScreen extends StatefulWidget {
  const UsersRolesScreen({super.key});

  @override
  State<UsersRolesScreen> createState() => _UsersRolesScreenState();
}

class _UsersRolesScreenState extends State<UsersRolesScreen> {
  late Future<List<Profile>> _future;

  @override
  void initState() {
    super.initState();
    _future = AccountController.instance.listProfiles();
  }

  Future<void> _reload() async {
    final future = AccountController.instance.listProfiles();
    setState(() => _future = future);
    await future;
  }

  Future<void> _changeRole(Profile person) async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final p = sheetContext.palette;
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    'Role for ${person.fullName.isEmpty ? 'this user' : person.fullName}',
                    style: MedivoText.heading.copyWith(color: p.ink),
                  ),
                ),
                for (final entry in roleLabels.entries)
                  ListTile(
                    title: Text(entry.value),
                    subtitle: Text(roleDescriptions[entry.key] ?? ''),
                    trailing: entry.key == person.role
                        ? Icon(Icons.check_circle, color: p.brand)
                        : null,
                    onTap: () => Navigator.of(sheetContext).pop(entry.key),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );

    if (chosen == null || chosen == person.role || !mounted) return;
    final error = await AccountController.instance.setRole(userId: person.id, role: chosen);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? 'Role changed to ${roleLabels[chosen]}')),
    );
    if (error == null) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final myId = AccountController.instance.user?.id;

    return Scaffold(
      appBar: medivoAppBar(context, 'Users and roles'),
      body: FutureBuilder<List<Profile>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                FormMessage(message: friendlyError(snapshot.error!)),
                const SizedBox(height: 16),
                FilledButton(onPressed: _reload, child: const Text('Try again')),
              ],
            );
          }

          final people = snapshot.data ?? const <Profile>[];
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: people.length + 1,
              separatorBuilder: (context, index) => Divider(height: 1, color: p.line),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Text(
                      '${people.length} ${people.length == 1 ? 'account' : 'accounts'}. '
                      'Tap a person to change their role. Every change is recorded in the audit log.',
                      style: MedivoText.bodySm.copyWith(color: p.muted),
                    ),
                  );
                }
                final person = people[index - 1];
                final isMe = person.id == myId;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: p.tint,
                    foregroundColor: p.brand,
                    child: Text(person.initials),
                  ),
                  title: Text(
                    person.fullName.isEmpty ? 'No name yet' : person.fullName,
                    style: MedivoText.body.copyWith(color: p.ink, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    [person.profession, person.institution]
                        .whereType<String>()
                        .where((s) => s.isNotEmpty)
                        .join(' · '),
                    style: MedivoText.bodySm.copyWith(color: p.muted),
                  ),
                  trailing: _RoleChip(label: isMe ? '${person.roleLabel} (you)' : person.roleLabel),
                  onTap: isMe ? null : () => _changeRole(person),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: p.tint, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: MedivoText.label.copyWith(color: p.ink, letterSpacing: 0)),
    );
  }
}
