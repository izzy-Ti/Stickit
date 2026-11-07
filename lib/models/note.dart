import 'dart:math';

import 'package:flutter/material.dart';

/// Background patterns available for a note (also rendered natively in widgets).
enum BgStyle { solid, gradient, lined, grid, dots }

/// Font families that exist on every Android device.
enum NoteFont { sans, serif, mono }

class ChecklistItem {
  ChecklistItem({required this.text, this.done = false});

  String text;
  bool done;

  Map<String, dynamic> toJson() => {'t': text, 'd': done};

  factory ChecklistItem.fromJson(Map<String, dynamic> j) =>
      ChecklistItem(text: j['t'] as String? ?? '', done: j['d'] as bool? ?? false);
}

class Note {
  Note({
    required this.id,
    this.title = '',
    this.body = '',
    this.checklist = false,
    List<ChecklistItem>? items,
    this.bg = 0xFFFFF59D,
    this.fg = 0xFF1A1A1A,
    this.style = BgStyle.solid,
    this.opacity = 1.0,
    this.fontSize = 16,
    this.font = NoteFont.sans,
    this.bold = false,
    this.italic = false,
    this.pinned = false,
    this.lockScreen = false,
    int? updated,
  })  : items = items ?? [],
        updated = updated ?? DateTime.now().millisecondsSinceEpoch;

  final String id;
  String title;
  String body;
  bool checklist;
  List<ChecklistItem> items;
  int bg;
  int fg;
  BgStyle style;
  double opacity;
  double fontSize;
  NoteFont font;
  bool bold;
  bool italic;
  bool pinned;
  bool lockScreen;
  int updated;

  Color get bgColor => Color(bg);
  Color get fgColor => Color(fg);

  String? get fontFamily => switch (font) {
        NoteFont.sans => null,
        NoteFont.serif => 'serif',
        NoteFont.mono => 'monospace',
      };

  TextStyle textStyle({double? size, bool forceBold = false}) => TextStyle(
        color: fgColor,
        fontSize: size ?? fontSize,
        fontFamily: fontFamily,
        fontWeight: (bold || forceBold) ? FontWeight.w700 : FontWeight.w400,
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
        height: 1.35,
      );

  bool get isEmpty =>
      title.trim().isEmpty &&
      body.trim().isEmpty &&
      items.every((i) => i.text.trim().isEmpty);

  void touch() => updated = DateTime.now().millisecondsSinceEpoch;

  static String newId() {
    final r = Random();
    return '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}'
        '${r.nextInt(1 << 20).toRadixString(36)}';
  }

  /// Updates this instance in place (keeps object identity for open editors).
  void assignFrom(Note o) {
    title = o.title;
    body = o.body;
    checklist = o.checklist;
    items = o.items;
    bg = o.bg;
    fg = o.fg;
    style = o.style;
    opacity = o.opacity;
    fontSize = o.fontSize;
    font = o.font;
    bold = o.bold;
    italic = o.italic;
    pinned = o.pinned;
    lockScreen = o.lockScreen;
    updated = o.updated;
  }

  Note copy({String? id}) => Note.fromJson({...toJson(), 'id': id ?? this.id});

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'checklist': checklist,
        'items': items.map((i) => i.toJson()).toList(),
        'bg': bg,
        'fg': fg,
        'style': style.name,
        'opacity': opacity,
        'size': fontSize,
        'font': font.name,
        'bold': bold,
        'italic': italic,
        'pinned': pinned,
        'lock': lockScreen,
        'updated': updated,
      };

  factory Note.fromJson(Map<String, dynamic> j) => Note(
        id: j['id'] as String,
        title: j['title'] as String? ?? '',
        body: j['body'] as String? ?? '',
        checklist: j['checklist'] as bool? ?? false,
        items: (j['items'] as List? ?? [])
            .map((e) => ChecklistItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        bg: (j['bg'] as num?)?.toInt() ?? 0xFFFFF59D,
        fg: (j['fg'] as num?)?.toInt() ?? 0xFF1A1A1A,
        style: BgStyle.values.firstWhere((s) => s.name == j['style'],
            orElse: () => BgStyle.solid),
        opacity: (j['opacity'] as num?)?.toDouble() ?? 1.0,
        fontSize: (j['size'] as num?)?.toDouble() ?? 16,
        font: NoteFont.values.firstWhere((f) => f.name == j['font'],
            orElse: () => NoteFont.sans),
        bold: j['bold'] as bool? ?? false,
        italic: j['italic'] as bool? ?? false,
        pinned: j['pinned'] as bool? ?? false,
        lockScreen: j['lock'] as bool? ?? false,
        updated: (j['updated'] as num?)?.toInt(),
      );
}
