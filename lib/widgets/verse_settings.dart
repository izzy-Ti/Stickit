import 'package:flutter/material.dart';

import '../data/note_store.dart';
import '../theme.dart';

/// Settings sheet: turn the built-in hourly verse notes on or off.
Future<void> showVerseSettings(BuildContext context) async {
  final initial = await NativeBridge.verseSettings();
  if (!context.mounted) return;
  await showModalBottomSheet(
    context: context,
    builder: (ctx) => _VerseSettings(initial: initial),
  );
}

class _VerseSettings extends StatefulWidget {
  const _VerseSettings({required this.initial});

  final Map<String, bool> initial;

  @override
  State<_VerseSettings> createState() => _VerseSettingsState();
}

class _VerseSettingsState extends State<_VerseSettings> {
  late final Map<String, bool> on = {...widget.initial};

  static const _subtitles = {
    'bible': 'A new Bible verse every hour',
    'quran': 'A new Quran ayah (Arabic + English) every hour',
  };

  Future<void> _toggle(String kind, bool value) async {
    setState(() => on[kind] = value);
    await NoteStore.instance.flush();
    await NativeBridge.setVerseEnabled(kind, value);
    await NoteStore.instance.reload();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 8, 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Verse notes',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text)),
            ),
          ),
          for (final e in verseKinds.entries)
            SwitchListTile(
              value: on[e.key] ?? true,
              onChanged: (v) => _toggle(e.key, v),
              title: Text(e.value),
              subtitle: Text(_subtitles[e.key] ?? '',
                  style: const TextStyle(color: AppColors.muted)),
            ),
        ]),
      ),
    );
  }
}
