import 'package:flutter/material.dart';

import '../offline/offline_service.dart';
import '../services/account_controller.dart';
import '../services/notification_service.dart';
import '../theme/medivo_palette.dart';
import '../theme/medivo_text.dart';
import '../widgets/form_message.dart';
import '../widgets/medivo_app_bar.dart';
import 'offline_library_screen.dart';
import 'open_content.dart';

/// Notifications (blueprint §27): guideline and content updates, drug
/// safety updates, CPD events, and offline library updates.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  ({DateTime at, int count})? _offlineNotice;

  @override
  void initState() {
    super.initState();
    NotificationService.instance.refresh();
    OfflineService.instance.lastUpdateNotice().then((n) {
      if (mounted) setState(() => _offlineNotice = n);
    });
  }

  @override
  void dispose() {
    NotificationService.instance.markAllRead();
    super.dispose();
  }

  bool get _isSuperAdmin => AccountController.instance.profile?.role == 'super_admin';

  IconData _icon(String kind) => switch (kind) {
        'guideline_update' => Icons.menu_book_outlined,
        'content_update' => Icons.update,
        'new_content' => Icons.fiber_new_outlined,
        'drug_safety' => Icons.medication_outlined,
        'cpd_event' => Icons.school_outlined,
        _ => Icons.campaign_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final service = NotificationService.instance;
    return Scaffold(
      appBar: medivoAppBar(context, 'Notifications'),
      floatingActionButton: _isSuperAdmin
          ? FloatingActionButton.extended(
              onPressed: () async {
                final posted = await showDialog<bool>(context: context, builder: (_) => const _PostDialog());
                if (posted == true) service.refresh();
              },
              icon: const Icon(Icons.campaign_outlined),
              label: const Text('Post notice'),
            )
          : null,
      body: ListenableBuilder(
        listenable: service,
        builder: (context, _) {
          final offline = _offlineNotice;
          return RefreshIndicator(
            onRefresh: service.refresh,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 96),
              children: [
                if (offline != null)
                  ListTile(
                    leading: Icon(Icons.offline_pin_outlined, color: p.brand),
                    title: Text('Offline library updated', style: MedivoText.body.copyWith(color: p.ink)),
                    subtitle: Text(
                        '${offline.count} ${offline.count == 1 ? 'topic' : 'topics'} added or updated · ${formatLongDate(offline.at)}',
                        style: MedivoText.bodySm.copyWith(color: p.muted)),
                    onTap: () => Navigator.of(context)
                        .push(MaterialPageRoute<void>(builder: (_) => const OfflineLibraryScreen())),
                  ),
                if (!service.loaded)
                  const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
                else if (service.items.isEmpty && offline == null)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text('No notifications yet.',
                        textAlign: TextAlign.center, style: MedivoText.body.copyWith(color: p.muted)),
                  ),
                for (final n in service.items)
                  ListTile(
                    leading: Stack(children: [
                      Icon(_icon(n.kind), color: n.kind == 'drug_safety' ? p.alert : p.brand),
                      if (!service.isRead(n.id))
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                              width: 8, height: 8, decoration: BoxDecoration(color: p.alert, shape: BoxShape.circle)),
                        ),
                    ]),
                    title: Text(n.title,
                        style: MedivoText.body.copyWith(
                            color: p.ink, fontWeight: service.isRead(n.id) ? FontWeight.w400 : FontWeight.w700)),
                    subtitle: Text(
                      '${notificationKindLabels[n.kind] ?? n.kind} · ${formatLongDate(n.createdAt)}'
                      '${n.body != null ? '\n${n.body}' : ''}',
                      style: MedivoText.bodySm.copyWith(color: p.muted),
                    ),
                    isThreeLine: n.body != null,
                    trailing: n.linkCode != null ? Icon(Icons.chevron_right, color: p.muted) : null,
                    onTap: () {
                      service.markRead(n.id);
                      if (n.linkCode != null) openContent(context, n.linkCode!);
                    },
                    onLongPress: _isSuperAdmin
                        ? () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Remove this notice?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                  FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
                                ],
                              ),
                            );
                            if (ok == true) {
                              await NotificationService.delete(n.id);
                              service.refresh();
                            }
                          }
                        : null,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PostDialog extends StatefulWidget {
  const _PostDialog();

  @override
  State<_PostDialog> createState() => _PostDialogState();
}

class _PostDialogState extends State<_PostDialog> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _link = TextEditingController();
  String _kind = 'drug_safety';
  String _audience = 'all';
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_title, _body, _link]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _post() async {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Enter a title.');
      return;
    }
    setState(() => _busy = true);
    try {
      await NotificationService.post(
        kind: _kind,
        title: _title.text.trim(),
        body: _body.text.trim().isEmpty ? null : _body.text.trim(),
        linkCode: _link.text.trim().isEmpty ? null : _link.text.trim().toUpperCase(),
        audience: _audience,
        createdBy: AccountController.instance.profile?.fullName ?? 'Medivo Clinical',
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _busy = false;
        _error = 'Could not post: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Post a notice'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(
            initialValue: _kind,
            decoration: const InputDecoration(labelText: 'Type'),
            items: const [
              DropdownMenuItem(value: 'drug_safety', child: Text('Drug safety update')),
              DropdownMenuItem(value: 'cpd_event', child: Text('CPD event')),
              DropdownMenuItem(value: 'announcement', child: Text('Announcement')),
            ],
            onChanged: (v) => setState(() => _kind = v ?? _kind),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _audience,
            decoration: const InputDecoration(labelText: 'Who sees it'),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('Everyone')),
              DropdownMenuItem(value: 'staff', child: Text('Content staff only')),
            ],
            onChanged: (v) => setState(() => _audience = v ?? _audience),
          ),
          const SizedBox(height: 12),
          TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title')),
          const SizedBox(height: 12),
          TextField(controller: _body, maxLines: 4, decoration: const InputDecoration(labelText: 'Message')),
          const SizedBox(height: 12),
          TextField(controller: _link, decoration: const InputDecoration(labelText: 'Link to content code (optional)', hintText: 'e.g. DIS-INF-001')),
          if (_error != null) ...[const SizedBox(height: 8), FormMessage(message: _error!)],
        ]),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: _busy ? null : _post, child: const Text('Post')),
      ],
    );
  }
}
