import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godothub/modals/survey_modal.dart';
import 'package:godothub/src/ui_prefs.dart';
import 'package:godothub/survey/survey.dart';

import '../projects/project_actions_test.dart' as base;
import '../support/fake_rust.dart';
import '../ui/i18n_setup.dart';

Survey survey() => Survey.tryParse({
  'id': 's',
  'title': 'T',
  'questions': [
    {
      'id': 'a',
      'type': 'choice',
      'text': 'Pick',
      'required': true,
      'options': [
        {'id': 'x', 'label': 'Option X'},
        {'id': 'y', 'label': 'Option Y'},
        {'id': 'z', 'label': 'Option Z'},
      ],
    },
  ],
})!;

void main() {
  setUpAll(() async {
    await base.loadFont('Inter', ['assets/fonts/inter-latin.ttf']);
  });
  setUp(setUpTestI18n);
  setUp(() {
    base.rust = installFakeRust();
    UiPrefsStore.instance = UiPrefsStore(MemoryUiPrefsBackend());
  });

  testWidgets('choices sit side by side and clicking outside does not dismiss but Escape does', (tester) async {
    var closed = false;
    await base.openModal(tester, (close) => SurveyModal(survey: survey(), onSend: (_) async {}, onClose: () => closed = true));
    final x = tester.getTopLeft(find.text('Option X'));
    final y = tester.getTopLeft(find.text('Option Y'));
    expect(y.dx, greaterThan(x.dx));
    expect(y.dy, x.dy);

    await tester.tapAt(const Offset(5, 5));
    await base.settle(tester);
    expect(closed, isFalse);

    expect(find.text('No thanks'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await base.settle(tester);
    expect(closed, isTrue);
  });
}
