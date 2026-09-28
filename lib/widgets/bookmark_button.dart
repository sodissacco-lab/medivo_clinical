import 'package:flutter/material.dart';

import '../services/library_service.dart';
import '../theme/medivo_palette.dart';

/// ⭐ Save (blueprint §9, §25). Tap to save or remove; after saving,
/// "Add to folder" puts it in one of the person's folders.
class BookmarkButton extends StatelessWidget {
  const BookmarkButton({super.key, required this.code, required this.title, this.type, this.colour});

  final String code;
  final String title;
  final String? type;

  /// Icon colour when not saved (e.g. white on the red emergency bar).
  final Color? colour;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final library = LibraryService.instance;
    return ListenableBuilder(
      listenable: library,
      builder: (context, _) {
        final saved = library.isSaved(code);
        return IconButton(
          tooltip: saved ? 'Saved' : 'Save',
          icon: Icon(saved ? Icons.star : Icons.star_border, color: saved ? p.accent : (colour ?? p.ink)),
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            if (saved) {
              await library.remove(code);
              messenger.showSnackBar(const SnackBar(content: Text('Removed from Saved')));
            } else {
              await library.save(code, title, type);
              if (!context.mounted) return;
              messenger.showSnackBar(SnackBar(
                content: const Text('Saved'),
                action: SnackBarAction(label: 'Add to folder', onPressed: () => chooseFolder(context, code)),
              ));
            }
          },
        );
      },
    );
  }
}

/// Lets the person pick (or create) a folder for a saved item.
Future<void> chooseFolder(BuildContext context, String code) async {
  final library = LibraryService.instance;
  final current = library.bookmark(code)?.folderId;
  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            leading: Icon(current == null ? Icons.radio_button_checked : Icons.radio_button_unchecked),
            title: const Text('No folder'),
            onTap: () => Navigator.pop(context, ''),
          ),
          for (final f in library.folders)
            ListTile(
              leading: Icon(current == f.id ? Icons.radio_button_checked : Icons.radio_button_unchecked),
              title: Text(f.name),
              onTap: () => Navigator.pop(context, f.id),
            ),
          ListTile(
            leading: const Icon(Icons.create_new_folder_outlined),
            title: const Text('New folder…'),
            onTap: () => Navigator.pop(context, '+new'),
          ),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) return;
  if (choice == '+new') {
    final name = await askFolderName(context);
    if (name == null) return;
    final id = await library.addFolder(name);
    await library.moveTo(code, id);
  } else {
    await library.moveTo(code, choice.isEmpty ? null : choice);
  }
}

Future<String?> askFolderName(BuildContext context, {String? initial}) {
  final c = TextEditingController(text: initial ?? '');
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(initial == null ? 'New folder' : 'Rename folder'),
      content: TextField(
        controller: c,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: 'e.g. My Ward Round'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(context, c.text.trim().isEmpty ? null : c.text.trim()),
          child: const Text('Save'),
        ),
      ],
    ),
  );
}
