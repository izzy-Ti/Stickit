import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/note_store.dart';
import 'screens/editor_screen.dart';
import 'screens/home_screen.dart';
import 'theme.dart';
import 'widgets/note_actions.dart';

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  NativeBridge.init();
  NativeBridge.onOpenNote = _openFromWidget;
  NativeBridge.onResizeWidget = _resizeFromWidget;
  await NoteStore.instance.load();
  runApp(const StickitApp());

  // Default Bible / Quran verse notes (first run) + hourly refresh.
  await NativeBridge.startVerses();
  await NoteStore.instance.reload();

  // App launched by tapping a widget / lock-screen note.
  final initial = await NativeBridge.initialNoteId();
  if (initial != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _openFromWidget(initial));
  }
  final resize = await NativeBridge.initialResize();
  if (resize != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _resizeFromWidget(resize));
  }
}

/// The resize button on a widget was tapped.
Future<void> _resizeFromWidget(Map<String, dynamic> req) async {
  final store = NoteStore.instance;
  await store.reload();
  final note = store.byId(req['noteId'] as String);
  final nav = navigatorKey.currentState;
  if (note == null || nav == null || !nav.mounted) return;
  nav.popUntil((r) => r.isFirst);
  await pinNoteToHome(nav.context, note,
      w: req['w'] as int? ?? 2,
      h: req['h'] as int? ?? 2,
      replaces: req['widgetId'] as int?);
}

Future<void> _openFromWidget(String id) async {
  final store = NoteStore.instance;
  await store.reload();
  final note = store.byId(id);
  final nav = navigatorKey.currentState;
  if (note == null || nav == null) return;
  nav.popUntil((r) => r.isFirst);
  nav.push(EditorScreen.route(note));
}

class StickitApp extends StatelessWidget {
  const StickitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stickit',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: buildTheme(),
      home: const HomeScreen(),
    );
  }
}
