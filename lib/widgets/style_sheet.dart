import 'package:flutter/material.dart';

import '../models/note.dart';
import '../theme.dart';

/// Per-note appearance editor: colours, background, font size and text style.
Future<void> showStyleSheet(BuildContext context, Note note, VoidCallback onChanged) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    barrierColor: Colors.black26,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
      void update(void Function() f) {
        f();
        setSheet(() {});
        onChanged();
      }

      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const _Label('Note colour'),
              _Swatches(
                colors: AppColors.noteColors,
                selected: note.bg,
                onPick: (c) => update(() {
                  // Keep text readable when switching between light/dark.
                  final wasAuto = note.fg == AppColors.contrastFor(note.bg);
                  note.bg = c;
                  if (wasAuto) note.fg = AppColors.contrastFor(c);
                }),
              ),
              const _Label('Text colour'),
              _Swatches(
                colors: AppColors.textColors,
                selected: note.fg,
                onPick: (c) => update(() => note.fg = c),
              ),
              const _Label('Background'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in BgStyle.values)
                    _Chip(
                      label: switch (s) {
                        BgStyle.solid => 'Solid',
                        BgStyle.gradient => 'Gradient',
                        BgStyle.lined => 'Lined',
                        BgStyle.grid => 'Grid',
                        BgStyle.dots => 'Dots',
                      },
                      selected: note.style == s,
                      onTap: () => update(() => note.style = s),
                    ),
                ],
              ),
              const _Label('Widget opacity'),
              Row(children: [
                const Icon(Icons.opacity_rounded, color: AppColors.muted, size: 20),
                Expanded(
                  child: Slider(
                    value: note.opacity,
                    min: 0.15,
                    max: 1,
                    onChanged: (v) => update(() => note.opacity = v),
                  ),
                ),
                SizedBox(
                  width: 44,
                  child: Text('${(note.opacity * 100).round()}%',
                      style: const TextStyle(color: AppColors.muted)),
                ),
              ]),
              const _Label('Font size'),
              Row(children: [
                const Icon(Icons.text_decrease_rounded,
                    color: AppColors.muted, size: 20),
                Expanded(
                  child: Slider(
                    value: note.fontSize,
                    min: 12,
                    max: 32,
                    divisions: 20,
                    onChanged: (v) => update(() => note.fontSize = v),
                  ),
                ),
                const Icon(Icons.text_increase_rounded,
                    color: AppColors.muted, size: 20),
              ]),
              const _Label('Text style'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final f in NoteFont.values)
                    _Chip(
                      label: switch (f) {
                        NoteFont.sans => 'Sans',
                        NoteFont.serif => 'Serif',
                        NoteFont.mono => 'Mono',
                      },
                      fontFamily: switch (f) {
                        NoteFont.sans => null,
                        NoteFont.serif => 'serif',
                        NoteFont.mono => 'monospace',
                      },
                      selected: note.font == f,
                      onTap: () => update(() => note.font = f),
                    ),
                  _Chip(
                    label: 'B',
                    bold: true,
                    selected: note.bold,
                    onTap: () => update(() => note.bold = !note.bold),
                  ),
                  _Chip(
                    label: 'I',
                    italic: true,
                    selected: note.italic,
                    onTap: () => update(() => note.italic = !note.italic),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }),
  );
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 10),
        child: Text(text.toUpperCase(),
            style: const TextStyle(
                color: AppColors.muted,
                fontSize: 11.5,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600)),
      );
}

class _Swatches extends StatelessWidget {
  const _Swatches(
      {required this.colors, required this.selected, required this.onPick});
  final List<int> colors;
  final int selected;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: colors.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final c = colors[i];
          final sel = c == selected;
          return GestureDetector(
            onTap: () => onPick(c),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Color(c),
                shape: BoxShape.circle,
                border: Border.all(
                  color: sel ? AppColors.purple : Colors.white12,
                  width: sel ? 3 : 1,
                ),
              ),
              child: sel
                  ? Icon(Icons.check_rounded,
                      size: 18, color: Color(AppColors.contrastFor(c)))
                  : null,
            ),
          );
        },
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.fontFamily,
    this.bold = false,
    this.italic = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? fontFamily;
  final bool bold;
  final bool italic;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.purple : AppColors.surfaceHi,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.text,
            fontFamily: fontFamily,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
            fontStyle: italic ? FontStyle.italic : FontStyle.normal,
          ),
        ),
      ),
    );
  }
}
