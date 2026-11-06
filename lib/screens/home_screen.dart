import 'package:flutter/material.dart';

import '../data/note_store.dart';
import '../models/note.dart';
import '../theme.dart';
import '../widgets/note_actions.dart';
import '../widgets/note_card.dart';
import 'editor_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final store = NoteStore.instance;
  String query = '';
  bool searching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pick up checklist ticks made from a home-screen widget.
    if (state == AppLifecycleState.resumed) store.reload();
    if (state == AppLifecycleState.paused) store.flush();
  }

  void _open(Note n) => Navigator.of(context).push(EditorScreen.route(n));

  void _new({bool checklist = false}) {
    final n = store.create(checklist: checklist);
    _open(n);
  }

  List<Note> _filtered() {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return store.notes;
    return store.notes.where((n) {
      return n.title.toLowerCase().contains(q) ||
          n.body.toLowerCase().contains(q) ||
          n.items.any((i) => i.text.toLowerCase().contains(q));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) {
            final notes = _filtered();
            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _header(store.notes.length)),
                if (!store.loaded)
                  const SliverFillRemaining(child: SizedBox.shrink())
                else if (notes.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _empty(query.isNotEmpty),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 120),
                    sliver: SliverToBoxAdapter(child: _masonry(notes)),
                  ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'fab-check',
            backgroundColor: AppColors.surfaceHi,
            foregroundColor: AppColors.purple,
            tooltip: 'New checklist',
            onPressed: () => _new(checklist: true),
            child: const Icon(Icons.checklist_rounded),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'fab-note',
            tooltip: 'New note',
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            onPressed: _new,
            child: const Icon(Icons.add_rounded, size: 30),
          ),
        ],
      ),
    );
  }

  Widget _header(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 10, 12),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: searching
            ? Row(key: const ValueKey('search'), children: [
                Expanded(
                  child: TextField(
                    autofocus: true,
                    onChanged: (v) => setState(() => query = v),
                    style: const TextStyle(color: AppColors.text, fontSize: 18),
                    decoration: InputDecoration(
                      hintText: 'Search notes',
                      hintStyle: const TextStyle(color: AppColors.muted),
                      filled: true,
                      fillColor: AppColors.surface,
                      prefixIcon:
                          const Icon(Icons.search_rounded, color: AppColors.muted),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => setState(() {
                    searching = false;
                    query = '';
                  }),
                ),
              ])
            : Row(key: const ValueKey('title'), children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                        colors: [AppColors.purple, AppColors.purpleDeep]),
                  ),
                ),
                const SizedBox(width: 10),
                const Text('Stickit',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                        color: AppColors.text)),
                const SizedBox(width: 10),
                Text('$count',
                    style: const TextStyle(fontSize: 16, color: AppColors.muted)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.search_rounded, color: AppColors.text),
                  onPressed: () => setState(() => searching = true),
                ),
              ]),
      ),
    );
  }

  Widget _masonry(List<Note> notes) {
    final left = <Note>[], right = <Note>[];
    for (var i = 0; i < notes.length; i++) {
      (i.isEven ? left : right).add(notes[i]);
    }
    Widget col(List<Note> list) => Column(
          children: [
            for (final n in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TweenAnimationBuilder<double>(
                  key: ValueKey(n.id),
                  tween: Tween(begin: 0.92, end: 1),
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutBack,
                  builder: (_, s, child) => Transform.scale(scale: s, child: child),
                  child: NoteCard(
                    note: n,
                    onTap: () => _open(n),
                    onLongPress: () => showNoteActions(context, n),
                  ),
                ),
              ),
          ],
        );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: col(left)),
        const SizedBox(width: 12),
        Expanded(child: col(right)),
      ],
    );
  }

  Widget _empty(bool isSearch) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(isSearch ? Icons.search_off_rounded : Icons.sticky_note_2_outlined,
              size: 56, color: AppColors.purple.withValues(alpha: 0.7)),
          const SizedBox(height: 16),
          Text(isSearch ? 'Nothing found' : 'No notes yet',
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.text)),
          const SizedBox(height: 6),
          Text(
            isSearch
                ? 'Try a different word.'
                : 'Tap + to write one, then stick it to your home screen.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted),
          ),
        ]),
      ),
    );
  }
}
