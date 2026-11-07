import 'package:flutter/material.dart';

import '../models/note.dart';
import '../theme.dart';
import 'note_background.dart';

/// Widget sizes the app can place, in home-screen cells. Must match
/// WidgetSizes.kt on the Android side.
const _minW = 2, _maxW = 4, _minH = 1, _maxH = 4;

/// Lets the user drag a corner handle (like a resizable text box) to choose how
/// many home-screen cells the widget takes. Works on every launcher, because
/// the app places a widget of the chosen size instead of asking the launcher to
/// resize one. Returns (width, height) in cells, or null if cancelled.
Future<(int, int)?> showWidgetSizePicker(
  BuildContext context,
  Note note, {
  int w = 2,
  int h = 2,
  bool resizing = false,
}) {
  return showModalBottomSheet<(int, int)>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _SizePicker(note: note, w: w, h: h, resizing: resizing),
  );
}

class _SizePicker extends StatefulWidget {
  const _SizePicker({
    required this.note,
    required this.w,
    required this.h,
    required this.resizing,
  });

  final Note note;
  final int w, h;
  final bool resizing;

  @override
  State<_SizePicker> createState() => _SizePickerState();
}

class _SizePickerState extends State<_SizePicker> {
  late int w = widget.w.clamp(_minW, _maxW);
  late int h = widget.h.clamp(_minH, _maxH);

  // Live size in pixels while dragging, so the note follows the finger
  // smoothly; it snaps to whole cells when released.
  double? dragW, dragH;

  @override
  Widget build(BuildContext context) {
    final note = widget.note;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.resizing ? 'Resize widget' : 'Widget size',
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.text)),
            const SizedBox(height: 4),
            const Text('Drag the corner to make it bigger or smaller.',
                style: TextStyle(color: AppColors.muted)),
            const SizedBox(height: 18),
            LayoutBuilder(builder: (context, c) {
              const gap = 8.0;
              final cell = (c.maxWidth - gap * (_maxW - 1)) / _maxW;
              final cellH = cell * 0.82;
              double px(int n, double unit) => n * unit + (n - 1) * gap;
              final noteW = dragW ?? px(w, cell);
              final noteH = dragH ?? px(h, cellH);

              // Nearest whole-cell count for a pixel length.
              int snap(double v, double unit, int lo, int hi) =>
                  ((v + gap) / (unit + gap)).round().clamp(lo, hi);

              return SizedBox(
                width: c.maxWidth,
                height: px(_maxH, cellH),
                child: Stack(clipBehavior: Clip.none, children: [
                  // Home-screen grid
                  for (var r = 0; r < _maxH; r++)
                    for (var col = 0; col < _maxW; col++)
                      Positioned(
                        left: col * (cell + gap),
                        top: r * (cellH + gap),
                        width: cell,
                        height: cellH,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.surfaceHi,
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                  // The note
                  Positioned(
                    left: 0,
                    top: 0,
                    width: noteW,
                    height: noteH,
                    child: NoteBackground(
                      note: note,
                      radius: 18,
                      spacing: 18,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        child: Text(
                          [note.title, note.checklist
                              ? note.items.map((i) => i.text).join('\n')
                              : note.body]
                              .where((t) => t.trim().isNotEmpty)
                              .join('\n'),
                          overflow: TextOverflow.fade,
                          style: note.textStyle(size: 13),
                        ),
                      ),
                    ),
                  ),
                  // Size label
                  Positioned(
                    left: 0,
                    top: 0,
                    width: noteW,
                    height: noteH,
                    child: IgnorePointer(
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${snap(noteW, cell, _minW, _maxW)} × ${snap(noteH, cellH, _minH, _maxH)}',
                            style: const TextStyle(
                                color: Colors.white, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Drag handle (bottom-right corner, like a text box)
                  Positioned(
                    left: noteW - 30,
                    top: noteH - 30,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanStart: (_) => setState(() {
                        dragW = noteW;
                        dragH = noteH;
                      }),
                      onPanUpdate: (d) => setState(() {
                        dragW = (dragW! + d.delta.dx)
                            .clamp(px(_minW, cell) * 0.85, px(_maxW, cell));
                        dragH = (dragH! + d.delta.dy)
                            .clamp(px(_minH, cellH) * 0.85, px(_maxH, cellH));
                      }),
                      onPanEnd: (_) => setState(() {
                        w = snap(dragW!, cell, _minW, _maxW);
                        h = snap(dragH!, cellH, _minH, _maxH);
                        dragW = dragH = null;
                      }),
                      child: Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: AppColors.purple,
                            shape: BoxShape.circle,
                            boxShadow: const [
                              BoxShadow(color: Colors.black45, blurRadius: 6),
                            ],
                          ),
                          child: const Icon(Icons.open_in_full_rounded,
                              size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ]),
              );
            }),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.purpleDeep,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => Navigator.pop(context, (w, h)),
                icon: const Icon(Icons.widgets_outlined),
                label: Text(widget.resizing
                    ? 'Place $w × $h widget'
                    : 'Add $w × $h to home screen'),
              ),
            ),
            if (widget.resizing) ...[
              const SizedBox(height: 10),
              const Text(
                'A new widget at this size will be added. The old one will tell you '
                'when it can be removed (long-press it → Remove).',
                style: TextStyle(color: AppColors.muted, fontSize: 12.5),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
