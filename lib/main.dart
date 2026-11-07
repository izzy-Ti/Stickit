import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/note_store.dart';
import 'screens/editor_screen.dart';
import 'screens/home_screen.dart';
import 'theme.dart';

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
