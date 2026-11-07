import 'package:flutter/material.dart';

import '../data/note_store.dart';
import '../models/note.dart';
import '../theme.dart';

void _snack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}

/// Asks the launcher to place a widget bound to this note.
Future<void> pinNoteToHome(BuildContext context, Note note) async {
  await NoteStore.instance.flush();
  final ok = await NativeBridge.pinToHome(note.id);
  if (!context.mounted) return;
  if (!ok) {
    _snack(context,
        'Your launcher can\'t pin automatically. Long-press the home screen → Widgets → Stickit.');
  }
}

/// Shows/hides the note on the lock screen (as a persistent notification —
/// the method Android supports on phones).
Future<void> toggleLockScreen(BuildContext context, Note note) async {
  if (!note.lockScreen) {
    final granted = await NativeBridge.requestNotificationPermission();
    if (!granted) {
      if (context.mounted) {
        _snack(context, 'Allow notifications to show notes on the lock screen.');
      }
      return;
    }
  }
  note.lockScreen = !note.lockScreen;
  NoteStore.instance.changed(immediate: true);
  if (context.mounted) {
    _snack(context,
        note.lockScreen ? 'Note shown on lock screen' : 'Removed from lock screen');
  }
}

/// Deletes with an undo snackbar.
void deleteNote(BuildContext context, Note note) {
  final store = NoteStore.instance;
  final backup = note.copy();
  store.delete(note.id);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(note.isVerse
          ? '${verseKinds[note.kind] ?? 'Verse'} turned off. Turn it back on in Settings.'
          : 'Note deleted'),
      action: SnackBarAction(label: 'Undo', onPressed: () => store.insert(backup)),
    ));
}

Future<void> showNoteActions(BuildContext context, Note note) {
  final store = NoteStore.instance;
  return showModalBottomSheet(
    context: context,
    builder: (ctx) {
      Widget tile(IconData icon, String label, VoidCallback onTap,
              {Color? color}) =>
          ListTile(
            leading: Icon(icon, color: color ?? AppColors.purple),
            title: Text(label, style: TextStyle(color: color)),
            onTap: () {
              Navigator.pop(ctx);
              onTap();
            },
          );
      return SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          tile(Icons.widgets_outlined, 'Add to home screen',
              () => pinNoteToHome(context, note)),
          tile(note.lockScreen ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
              note.lockScreen ? 'Remove from lock screen' : 'Show on lock screen',
              () => toggleLockScreen(context, note)),
          tile(note.pinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
              note.pinned ? 'Unpin from top' : 'Pin to top', () {
            note.pinned = !note.pinned;
            store.changed(immediate: true);
          }),
          tile(Icons.copy_rounded, 'Duplicate', () {
            final n = note.copy(id: Note.newId())
              ..pinned = false
              ..lockScreen = false
              ..touch();
            store.insert(n);
          }),
          tile(Icons.delete_outline_rounded, 'Delete',
              () => deleteNote(context, note),
              color: const Color(0xFFFF6B81)),
          const SizedBox(height: 8),
        ]),
      );
    },
  );
}
