import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/note.dart';

/// Bridge to the native Android side. Notes are stored natively (SharedPreferences)
/// so that home-screen widgets and lock-screen notifications can read them
/// without starting Flutter. Everything is local — no network needed.
class NativeBridge {
  static const _ch = MethodChannel('stickit/native');

  static void Function(String noteId)? onOpenNote;

  static void init() {
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'openNote' && call.arguments is String) {
        onOpenNote?.call(call.arguments as String);
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
  static Future<bool> pinToHome(String id) async =>
      await _call<bool>('pinToHome', id) ?? false;
  static Future<int> widgetCount(String id) async =>
      await _call<int>('widgetCount', id) ?? 0;
  static Future<bool> requestNotificationPermission() async =>
      await _call<bool>('requestNotificationPermission') ?? true;
}

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
    final raw = await NativeBridge.loadNotes();
    if (raw == null || raw.isEmpty) return;
    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => Note.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      _notes
        ..clear()
        ..addAll(list);
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
  }

  void delete(String id) {
    _notes.removeWhere((n) => n.id == id);
    changed(immediate: true);
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
