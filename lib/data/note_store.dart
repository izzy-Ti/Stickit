import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/note.dart';

/// Bridge to the native Android side. Notes are stored natively (SharedPreferences)
/// so that home-screen widgets and lock-screen notifications can read them
/// without starting Flutter. Only the built-in verse notes use the network
/// (fetched natively, hourly).
class NativeBridge {
  static const _ch = MethodChannel('stickit/native');

  static void Function(String noteId)? onOpenNote;

  /// Widget resize button tapped: {noteId, widgetId, w, h}.
  static void Function(Map<String, dynamic> req)? onResizeWidget;

  static void init() {
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'openNote' && call.arguments is String) {
        onOpenNote?.call(call.arguments as String);
      } else if (call.method == 'resizeWidget' && call.arguments is Map) {
        onResizeWidget?.call(Map<String, dynamic>.from(call.arguments as Map));
      } else if (call.method == 'notesChanged') {
        await NoteStore.instance.reload();
      }
      return null;
    });
  }

  static Future<T?> _call<T>(String method, [Object? args]) async {
    try {
      return await _ch.invokeMethod<T>(method, args);
    } on MissingPluginException {
      return null; // running on a non-Android platform / tests
    } on PlatformException catch (e) {
      debugPrint('Native call $method failed: $e');
      return null;
    }
  }

  static Future<String?> loadNotes() => _call<String>('loadNotes');
  static Future<void> saveNotes(String json) => _call('saveNotes', json);
  static Future<String?> initialNoteId() => _call<String>('initialNoteId');
  static Future<Map<String, dynamic>?> initialResize() async {
    final m = await _call<Map>('initialResize');
    return m == null ? null : Map<String, dynamic>.from(m);
  }

  /// Places a widget of [w]×[h] cells. [replaces] is the widget being resized.
  static Future<bool> pinToHome(String id,
          {int w = 2, int h = 2, int? replaces}) async =>
      await _call<bool>('pinToHome',
          {'noteId': id, 'w': w, 'h': h, 'replaces': replaces}) ??
      false;
  static Future<int> widgetCount(String id) async =>
      await _call<int>('widgetCount', id) ?? 0;
  static Future<bool> requestNotificationPermission() async =>
      await _call<bool>('requestNotificationPermission') ?? true;

  /// Adds the default verse notes on first run and schedules hourly refresh.
  static Future<void> startVerses() => _call('startVerses');

  /// Which verse notes are turned on, e.g. {'bible': true, 'quran': false}.
  static Future<Map<String, bool>> verseSettings() async {
    final m = await _call<Map>('verseSettings');
    return {
      for (final k in verseKinds.keys) k: (m?[k] as bool?) ?? true,
    };
  }

  static Future<void> setVerseEnabled(String kind, bool on) =>
      _call('setVerseEnabled', {'kind': kind, 'on': on});
}

/// Built-in verse notes and their display names.
const verseKinds = {'bible': 'Bible verse', 'quran': 'Quran verse'};

class NoteStore extends ChangeNotifier {
  NoteStore._();
  static final instance = NoteStore._();

  final List<Note> _notes = [];
  Timer? _saveTimer;
  bool loaded = false;

  /// Pinned first, then most recently edited.
  List<Note> get notes {
    final list = [..._notes];
    list.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.updated.compareTo(a.updated);
    });
    return list;
  }

  Note? byId(String id) {
    for (final n in _notes) {
      if (n.id == id) return n;
    }
    return null;
  }

  Future<void> load() async {
    await reload();
    loaded = true;
    notifyListeners();
  }

  /// Re-reads from native storage (e.g. after a checklist was ticked in a widget).
  Future<void> reload() async {
    // Never let stored data overwrite edits that haven't been written yet.
    if (_saveTimer?.isActive ?? false) await flush();
    final raw = await NativeBridge.loadNotes();
    if (raw == null || raw.isEmpty) return;
    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => Note.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      final merged = list.map((n) {
        final existing = byId(n.id);
        if (existing == null) return n;
        return existing..assignFrom(n);
      }).toList();
      _notes
        ..clear()
        ..addAll(merged);
      notifyListeners();
    } catch (e) {
      debugPrint('Could not parse notes: $e');
    }
  }

  Note create({bool checklist = false, Note? styleFrom}) {
    final n = styleFrom?.copy(id: Note.newId()) ?? Note(id: Note.newId());
    n
      ..title = styleFrom?.title ?? ''
      ..checklist = checklist || (styleFrom?.checklist ?? false)
      ..pinned = false
      ..lockScreen = false
      ..touch();
    if (n.checklist && n.items.isEmpty) n.items.add(ChecklistItem(text: ''));
    _notes.add(n);
    notifyListeners();
    return n;
  }

  void insert(Note n) {
    _notes.removeWhere((e) => e.id == n.id);
    _notes.add(n);
    changed(immediate: true);
    // Restoring a deleted verse note turns that verse back on.
    if (n.kind != null) NativeBridge.setVerseEnabled(n.kind!, true);
  }

  void delete(String id) {
    final kind = byId(id)?.kind;
    _notes.removeWhere((n) => n.id == id);
    changed(immediate: true);
    // Deleting a verse note turns it off (it can be re-enabled in settings).
    if (kind != null) NativeBridge.setVerseEnabled(kind, false);
  }

  /// Call after mutating a note. Saves are debounced to keep typing smooth.
  void changed({bool immediate = false}) {
    notifyListeners();
    _saveTimer?.cancel();
    if (immediate) {
      _flush();
    } else {
      _saveTimer = Timer(const Duration(milliseconds: 450), _flush);
    }
  }

  Future<void> flush() async {
    _saveTimer?.cancel();
    await _flush();
  }

  Future<void> _flush() =>
      NativeBridge.saveNotes(jsonEncode(_notes.map((n) => n.toJson()).toList()));
}
