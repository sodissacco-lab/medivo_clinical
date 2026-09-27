import 'package:flutter/material.dart';

import '../../data/emergency_protocols.dart';
import '../../services/account_controller.dart';
import '../../services/published_index.dart';
import '../../theme/medivo_palette.dart';
import '../../theme/medivo_text.dart';
import 'emergency_protocol_screen.dart';

/// The Emergency module (blueprint §16): large buttons, minimal text,
/// one tap to each protocol. Works offline once the Emergency pack is saved.
class EmergencyHubScreen extends StatefulWidget {
  const EmergencyHubScreen({super.key});

  @override
  State<EmergencyHubScreen> createState() => _EmergencyHubScreenState();
}

class _EmergencyHubScreenState extends State<EmergencyHubScreen> {
  final _index = PublishedIndex.of('emergency');

  @override
  void initState() {
    super.initState();
    _index.refresh();
  }

  void _open(ProtocolEntry entry) {
    if (!_index.canOpen(entry.code)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${entry.title}: this protocol is still being clinically reviewed. '
            'Follow your facility protocol.'),
      ));
      return;
    }
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => EmergencyProtocolScreen(code: entry.code, fallbackTitle: entry.title),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final onAlert = Theme.of(context).colorScheme.onError;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: p.alert,
        foregroundColor: onAlert,
        title: Row(
          children: [
            const Icon(Icons.emergency),
            const SizedBox(width: 8),
            Text('EMERGENCY', style: MedivoText.heading.copyWith(color: onAlert, letterSpacing: 1.2)),
          ],
        ),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([_index, AccountController.instance]),
        builder: (context, _) {
          final extra = [
            for (final t in _index.topics)
              if (!emergencyProtocols.any((e) => e.code == t.code))
                ProtocolEntry(t.code, t.title, Icons.emergency_outlined),
          ];
          final entries = [...emergencyProtocols, ...extra];
          return RefreshIndicator(
            onRefresh: _index.refresh,
            child: GridView.extent(
              padding: const EdgeInsets.all(12),
              maxCrossAxisExtent: 260,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.1,
              children: [
                for (final entry in entries)
                  _EmergencyButton(
                    entry: entry,
                    available: _index.isPublished(entry.code),
                    preview: !_index.isPublished(entry.code) && PublishedIndex.isStaff,
                    onTap: () => _open(entry),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EmergencyButton extends StatelessWidget {
  const _EmergencyButton({
    required this.entry,
    required this.available,
    required this.preview,
    required this.onTap,
  });

  final ProtocolEntry entry;
  final bool available;
  final bool preview;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final active = available || preview;
    final colour = active ? p.alert : p.muted;
    return Material(
      color: available ? p.alert.withValues(alpha: 0.12) : p.surfaceRaised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colour, width: available ? 2 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(entry.icon, color: colour, size: 30),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: MedivoText.heading.copyWith(color: active ? p.ink : p.muted)),
                    if (!available)
                      Text(preview ? 'PREVIEW' : 'Under review',
                          style: MedivoText.label.copyWith(color: p.muted)),
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
