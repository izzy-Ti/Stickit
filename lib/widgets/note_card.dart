import 'package:flutter/material.dart';

import '../models/note.dart';
import 'note_background.dart';

class NoteCard extends StatelessWidget {
  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    required this.onLongPress,
  });

  final Note note;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final fg = note.fgColor;
    final small = note.textStyle(size: (note.fontSize * 0.85).clamp(11, 20));
    return Hero(
      tag: 'note-${note.id}',
      child: Material(
        type: MaterialType.transparency,
        child: NoteBackground(
          note: note,
          radius: 20,
          spacing: 22,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(children: [
                    Expanded(
                      child: note.title.trim().isEmpty
                          ? const SizedBox.shrink()
                          : Text(
                              note.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: note.textStyle(
                                  size: (note.fontSize * 0.95).clamp(13, 22),
                                  forceBold: true),
                            ),
                    ),
                    if (note.lockScreen)
                      Icon(Icons.lock_outline_rounded,
                          size: 15, color: fg.withValues(alpha: 0.6)),
                    if (note.pinned)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Icon(Icons.push_pin_rounded,
                            size: 15, color: fg.withValues(alpha: 0.6)),
                      ),
                  ]),
                  if (note.title.trim().isNotEmpty) const SizedBox(height: 6),
                  if (note.checklist)
                    ...note.items.take(6).map((i) => Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 2, right: 6),
                                child: Icon(
                                  i.done
                                      ? Icons.check_box_rounded
                                      : Icons.check_box_outline_blank_rounded,
                                  size: 15,
                                  color: fg.withValues(alpha: 0.75),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  i.text,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: small.copyWith(
                                    decoration:
                                        i.done ? TextDecoration.lineThrough : null,
                                    color: i.done ? fg.withValues(alpha: 0.5) : fg,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ))
                  else if (note.body.trim().isNotEmpty)
                    Text(note.body,
                        maxLines: 8, overflow: TextOverflow.ellipsis, style: small),
                  if (note.isEmpty)
                    Text('Empty note',
                        style: small.copyWith(color: fg.withValues(alpha: 0.45))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
