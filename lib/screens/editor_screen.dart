import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/note_store.dart';
import '../models/note.dart';
import '../widgets/note_actions.dart';
import '../widgets/note_background.dart';
import '../widgets/style_sheet.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key, required this.note});

  final Note note;

  static Route<void> route(Note note) =>
      MaterialPageRoute(builder: (_) => EditorScreen(note: note));

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final store = NoteStore.instance;
  late final TextEditingController _title;
  late final TextEditingController _body;
  final _ctrls = <ChecklistItem, TextEditingController>{};
  final _focus = <ChecklistItem, FocusNode>{};

  Note get note => widget.note;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: note.title);
    _body = TextEditingController(text: note.body);
    store.addListener(_onStore);
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    store.removeListener(_onStore);
    _title.dispose();
    _body.dispose();
    for (final c in _ctrls.values) {
      c.dispose();
    }
    for (final f in _focus.values) {
      f.dispose();
    }
    super.dispose();
  }

  TextEditingController _ctrlFor(ChecklistItem i) =>
      _ctrls.putIfAbsent(i, () => TextEditingController(text: i.text));
  FocusNode _focusFor(ChecklistItem i) => _focus.putIfAbsent(i, FocusNode.new);

  void _changed() {
    note.touch();
    store.changed();
    setState(() {});
  }

  void _toggleChecklist() {
    setState(() {
      if (note.checklist) {
        note.body = note.items.map((i) => i.text).where((t) => t.isNotEmpty).join('\n');
        _body.text = note.body;
        note.items.clear();
        note.checklist = false;
      } else {
        note.items = note.body
            .split('\n')
            .where((l) => l.trim().isNotEmpty)
            .map((l) => ChecklistItem(text: l.trim()))
            .toList();
        if (note.items.isEmpty) note.items.add(ChecklistItem(text: ''));
        note.body = '';
        note.checklist = true;
      }
    });
    _changed();
  }

  void _addItem({int? after}) {
    final item = ChecklistItem(text: '');
    setState(() {
      final at = after == null ? note.items.length : after + 1;
      note.items.insert(at, item);
    });
    _changed();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _focusFor(item).requestFocus());
  }

  void _removeItem(ChecklistItem item) {
    final idx = note.items.indexOf(item);
    setState(() => note.items.remove(item));
    _ctrls.remove(item)?.dispose();
    _focus.remove(item)?.dispose();
    if (idx > 0) _focusFor(note.items[idx - 1]).requestFocus();
    _changed();
  }

  Future<void> _close() async {
    if (note.isEmpty && store.byId(note.id) != null) {
      store.delete(note.id);
    } else {
      await store.flush();
    }
  }

  @override
  Widget build(BuildContext context) {
    final fg = note.fgColor;
    final dark = note.bgColor.computeLuminance() < 0.45 || note.opacity < 0.5;
    final iconColor = note.opacity < 0.5 ? Colors.white : fg;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: PopScope(
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) _close();
        },
        child: Scaffold(
          backgroundColor: const Color(0xFF0A0A0D),
          body: Hero(
            tag: 'note-${note.id}',
            child: Material(
              type: MaterialType.transparency,
              child: NoteBackground(
                note: note,
                radius: 0,
                child: SafeArea(
                  child: Column(children: [
                    _toolbar(iconColor),
                    Expanded(child: _content(fg)),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _toolbar(Color c) {
    Widget btn(IconData icon, String tip, VoidCallback onTap, {bool active = false}) =>
        IconButton(
          tooltip: tip,
          onPressed: onTap,
          icon: Icon(icon, color: active ? c : c.withValues(alpha: 0.8)),
          style: active
              ? IconButton.styleFrom(backgroundColor: c.withValues(alpha: 0.14))
              : null,
        );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(children: [
        btn(Icons.arrow_back_rounded, 'Back', () => Navigator.maybePop(context)),
        const Spacer(),
        btn(note.checklist ? Icons.notes_rounded : Icons.checklist_rounded,
            note.checklist ? 'Convert to text' : 'Convert to checklist',
            _toggleChecklist),
        btn(Icons.palette_outlined, 'Style', () => showStyleSheet(context, note, _changed)),
        btn(Icons.widgets_outlined, 'Add to home screen',
            () => pinNoteToHome(context, note)),
        btn(
          note.lockScreen ? Icons.lock_rounded : Icons.lock_outline_rounded,
          'Lock screen',
          () async {
            await toggleLockScreen(context, note);
            setState(() {});
          },
          active: note.lockScreen,
        ),
        btn(note.pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined, 'Pin',
            () {
          note.pinned = !note.pinned;
          _changed();
        }, active: note.pinned),
        btn(Icons.delete_outline_rounded, 'Delete', () {
          final messengerContext = Navigator.of(context).context;
          Navigator.pop(context);
          deleteNote(messengerContext, note);
        }),
      ]),
    );
  }

  Widget _content(Color fg) {
    final text = note.textStyle();
    final hint = text.copyWith(color: fg.withValues(alpha: 0.4));
    const noBorder = InputDecoration(
      border: InputBorder.none,
      isCollapsed: true,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 120),
      children: [
        TextField(
          controller: _title,
          onChanged: (v) {
            note.title = v;
            _changed();
          },
          style: note.textStyle(size: note.fontSize + 8, forceBold: true),
          cursorColor: fg,
          maxLines: null,
          textCapitalization: TextCapitalization.sentences,
          decoration: noBorder.copyWith(
            hintText: 'Title',
            hintStyle: note
                .textStyle(size: note.fontSize + 8, forceBold: true)
                .copyWith(color: fg.withValues(alpha: 0.35)),
          ),
        ),
        const SizedBox(height: 14),
        if (!note.checklist)
          TextField(
            controller: _body,
            autofocus: note.isEmpty,
            onChanged: (v) {
              note.body = v;
              _changed();
            },
            style: text,
            cursorColor: fg,
            maxLines: null,
            minLines: 12,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            decoration: noBorder.copyWith(hintText: 'Write something…', hintStyle: hint),
          )
        else ...[
          for (var i = 0; i < note.items.length; i++) _itemRow(i, fg, text, hint),
          TextButton.icon(
            onPressed: _addItem,
            style: TextButton.styleFrom(
              foregroundColor: fg.withValues(alpha: 0.7),
              alignment: Alignment.centerLeft,
              padding: EdgeInsets.zero,
            ),
            icon: const Icon(Icons.add_rounded),
            label: Text('Add item', style: text.copyWith(color: fg.withValues(alpha: 0.7))),
          ),
        ],
      ],
    );
  }

  Widget _itemRow(int index, Color fg, TextStyle text, TextStyle hint) {
    final item = note.items[index];
    return Padding(
      key: ObjectKey(item),
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              item.done = !item.done;
              _changed();
            },
            child: Padding(
              padding: const EdgeInsets.only(right: 10, top: 4, bottom: 4),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                child: Icon(
                  item.done
                      ? Icons.check_box_rounded
                      : Icons.check_box_outline_blank_rounded,
                  key: ValueKey(item.done),
                  color: fg.withValues(alpha: item.done ? 0.55 : 0.85),
                  size: note.fontSize + 6,
                ),
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: _ctrlFor(item),
              focusNode: _focusFor(item),
              autofocus: item.text.isEmpty && index == note.items.length - 1,
              onChanged: (v) {
                item.text = v;
                _changed();
              },
              onSubmitted: (_) => _addItem(after: index),
              textInputAction: TextInputAction.next,
              style: text.copyWith(
                decoration: item.done ? TextDecoration.lineThrough : null,
                color: item.done ? fg.withValues(alpha: 0.5) : fg,
              ),
              cursorColor: fg,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(border: InputBorder.none, isCollapsed: true)
                  .copyWith(hintText: 'List item', hintStyle: hint),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => _removeItem(item),
            icon: Icon(Icons.close_rounded, size: 18, color: fg.withValues(alpha: 0.45)),
          ),
        ],
      ),
    );
  }
}
