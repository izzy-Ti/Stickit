import 'package:flutter_test/flutter_test.dart';
import 'package:stickit/main.dart';
import 'package:stickit/models/note.dart';

void main() {
  test('note JSON round-trip', () {
    final n = Note(id: 'a', title: 'Hi', checklist: true, items: [
      ChecklistItem(text: 'one', done: true),
    ])
      ..style = BgStyle.dots
      ..font = NoteFont.mono
      ..bold = true;
    final back = Note.fromJson(n.toJson());
    expect(back.title, 'Hi');
    expect(back.items.single.done, isTrue);
    expect(back.style, BgStyle.dots);
    expect(back.font, NoteFont.mono);
    expect(back.bold, isTrue);
  });

  testWidgets('home screen shows empty state', (tester) async {
    await tester.pumpWidget(const StickitApp());
    await tester.pumpAndSettle();
    expect(find.text('Stickit'), findsOneWidget);
  });
}
