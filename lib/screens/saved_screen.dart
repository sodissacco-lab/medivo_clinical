import 'package:flutter/material.dart';

import '../data/content_options.dart';
import '../services/library_service.dart';
import '../theme/medivo_palette.dart';
import '../theme/medivo_text.dart';
import '../widgets/bookmark_button.dart';
import '../widgets/medivo_app_bar.dart';
import 'open_content.dart';

/// Saved content (blueprint §25): bookmarks organised into folders.
class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  /// null = all saved items; '' = not in a folder; otherwise a folder id.
  String? _folder;

  Future<void> _folderMenu(BookmarkFolder f) async {
    final library = LibraryService.instance;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.edit_outlined), title: const Text('Rename'), onTap: () => Navigator.pop(context, 'rename')),
          ListTile(leading: const Icon(Icons.delete_outline), title: const Text('Delete folder'),
              subtitle: const Text('Saved items stay saved'), onTap: () => Navigator.pop(context, 'delete')),
        ]),
      ),
    );
    if (!mounted) return;
    if (action == 'rename') {
      final name = await askFolderName(context, initial: f.name);
      if (name != null) await library.renameFolder(f.id, name);
    } else if (action == 'delete') {
      await library.deleteFolder(f.id);
      if (_folder == f.id) setState(() => _folder = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final library = LibraryService.instance;
    return Scaffold(
      appBar: medivoAppBar(context, 'Saved', actions: [
        IconButton(
          tooltip: 'New folder',
          icon: const Icon(Icons.create_new_folder_outlined),
          onPressed: () async {
            final name = await askFolderName(context);
            if (name != null) await library.addFolder(name);
          },
        ),
      ]),
      body: ListenableBuilder(
        listenable: library,
        builder: (context, _) {
          final all = library.bookmarks;
          final folders = library.folders;
          final shown = switch (_folder) {
            null => all,
            '' => all.where((b) => b.folderId == null || library.folder(b.folderId)?.deleted != false).toList(),
            final id => all.where((b) => b.folderId == id).toList(),
          };
          int count(String id) => all.where((b) => b.folderId == id).length;

          return Column(children: [
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text('All (${all.length})'),
                      selected: _folder == null,
                      onSelected: (_) => setState(() => _folder = null),
                    ),
                  ),
                  for (final f in folders)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onLongPress: () => _folderMenu(f),
                        child: ChoiceChip(
                          avatar: const Icon(Icons.folder_outlined, size: 18),
                          label: Text('${f.name} (${count(f.id)})'),
                          selected: _folder == f.id,
                          onSelected: (_) => setState(() => _folder = f.id),
                        ),
                      ),
                    ),
                  ChoiceChip(
                    label: const Text('No folder'),
                    selected: _folder == '',
                    onSelected: (_) => setState(() => _folder = ''),
                  ),
                ],
              ),
            ),
            if (_folder != null && _folder!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Text('Press and hold a folder to rename or delete it.',
                    style: MedivoText.bodySm.copyWith(color: p.muted)),
              ),
            Expanded(
              child: shown.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.star_border, color: p.muted, size: 40),
                          const SizedBox(height: 12),
                          Text(all.isEmpty ? 'Nothing saved yet' : 'This folder is empty',
                              style: MedivoText.heading.copyWith(color: p.ink)),
                          const SizedBox(height: 6),
                          Text('Tap the ☆ at the top of any topic, calculator, protocol or guideline to save it here.',
                              textAlign: TextAlign.center, style: MedivoText.bodySm.copyWith(color: p.muted)),
                        ]),
                      ),
                    )
                  : ListView.separated(
                      itemCount: shown.length,
                      separatorBuilder: (context, i) => Divider(height: 1, color: p.line, indent: 16),
                      itemBuilder: (context, i) {
                        final b = shown[i];
                        final folder = library.folder(b.folderId);
                        return Dismissible(
                          key: ValueKey('bm-${b.code}'),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            color: p.alert,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 24),
                            child: const Icon(Icons.delete_outline, color: Colors.white),
                          ),
                          onDismissed: (_) {
                            library.remove(b.code);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('Removed ${b.title}'),
                              action: SnackBarAction(
                                label: 'Undo',
                                onPressed: () => library.save(b.code, b.title, b.type, folderId: b.folderId),
                              ),
                            ));
                          },
                          child: ListTile(
                            leading: Icon(Icons.star, color: p.accent),
                            title: Text(b.title, style: MedivoText.body.copyWith(color: p.ink)),
                            subtitle: Text(
                              [
                                contentTypes[b.type] ?? 'Topic',
                                if (folder != null && !folder.deleted) folder.name,
                              ].join(' · '),
                              style: MedivoText.bodySm.copyWith(color: p.muted),
                            ),
                            trailing: IconButton(
                              tooltip: 'Move to folder',
                              icon: const Icon(Icons.drive_file_move_outline),
                              onPressed: () => chooseFolder(context, b.code),
                            ),
                            onTap: () => openContent(context, b.code),
                          ),
                        );
                      },
                    ),
            ),
          ]);
        },
      ),
    );
  }
}