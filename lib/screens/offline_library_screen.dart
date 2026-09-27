import 'package:flutter/material.dart';

import '../offline/offline_service.dart';
import '../theme/medivo_palette.dart';
import '../theme/medivo_text.dart';
import '../widgets/form_message.dart';
import '../widgets/medivo_app_bar.dart';
import '../widgets/medivo_panel.dart';

/// Choose download packs and keep them up to date (blueprint §22).
class OfflineLibraryScreen extends StatelessWidget {
  const OfflineLibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final offline = OfflineService.instance;

    return Scaffold(
      appBar: medivoAppBar(context, 'Offline library'),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: offline,
          builder: (context, _) {
            if (!offline.supported) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'The offline library is part of the Medivo Clinical mobile app for '
                    'Android and iPhone. On the web, content is read online.',
                    style: MedivoText.body.copyWith(color: p.ink),
                  ),
                ],
              );
            }

            final last = offline.lastUpdated;
            final progress = offline.total == 0 ? null : offline.done / offline.total;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        MedivoPanel(
                          title: 'STATUS',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                last == null
                                    ? 'Offline library not downloaded yet'
                                    : 'Offline content last updated: ${formatLongDate(last)}',
                                style: MedivoText.body.copyWith(
                                    color: p.ink, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${offline.itemCount} ${offline.itemCount == 1 ? 'topic' : 'topics'} '
                                'saved on this device. Only content that has passed clinical '
                                'review and been published is downloaded.',
                                style: MedivoText.bodySm.copyWith(color: p.muted),
                              ),
                              if (offline.syncing) ...[
                                const SizedBox(height: 12),
                                LinearProgressIndicator(value: progress, color: p.brand),
                                const SizedBox(height: 4),
                                Text(
                                  offline.total == 0
                                      ? 'Checking for updates…'
                                      : 'Downloading ${offline.done} of ${offline.total}…',
                                  style: MedivoText.bodySm.copyWith(color: p.muted),
                                ),
                              ],
                              if (offline.error != null) ...[
                                const SizedBox(height: 12),
                                FormMessage(message: offline.error!),
                              ],
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: FilledButton.icon(
                                  onPressed: offline.syncing || !offline.ready
                                      ? null
                                      : offline.sync,
                                  icon: const Icon(Icons.sync),
                                  label: const Text('Update now'),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        MedivoPanel(
                          title: 'DOWNLOAD PACKS',
                          child: offline.packs.isEmpty
                              ? Text(
                                  'Connect to the internet and tap Update now to see the packs.',
                                  style: MedivoText.bodySm.copyWith(color: p.muted),
                                )
                              : Column(
                                  children: [
                                    for (final pack in offline.packs)
                                      SwitchListTile(
                                        contentPadding: EdgeInsets.zero,
                                        value: pack.selected,
                                        onChanged: offline.syncing
                                            ? null
                                            : (on) => offline.setPackSelected(pack.code, on),
                                        title: Text(pack.name,
                                            style: MedivoText.body.copyWith(
                                                color: p.ink, fontWeight: FontWeight.w600)),
                                        subtitle: Text(
                                          '${pack.description}\n'
                                          '${offline.itemsInPack(pack)} on this device',
                                          style: MedivoText.bodySm.copyWith(color: p.muted),
                                        ),
                                        isThreeLine: true,
                                      ),
                                  ],
                                ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'The library updates itself when the app opens with internet, '
                          'at most every 12 hours.',
                          style: MedivoText.bodySm.copyWith(color: p.muted),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            style: TextButton.styleFrom(foregroundColor: p.alert),
                            onPressed: offline.syncing || offline.itemCount == 0
                                ? null
                                : () => _confirmRemove(context),
                            child: const Text('Remove offline library from this device'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _confirmRemove(BuildContext context) async {
    final remove = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove offline library?'),
        content: const Text(
            'All downloaded content will be deleted from this device and every pack turned off. '
            'You can download it again at any time.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (remove == true) await OfflineService.instance.removeAll();
  }
}
