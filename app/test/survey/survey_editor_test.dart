import 'package:flutter_test/flutter_test.dart';
import 'package:godothub/modals/survey_form_modal.dart';
import 'package:godothub/src/ui_prefs.dart';
import 'package:godothub/survey/survey.dart';
import 'package:godothub/survey/survey_admin.dart';

import '../projects/project_actions_test.dart' as base;
import '../support/fake_rust.dart';
import '../ui/i18n_setup.dart';

Map<String, Object?> sample() => {
  'id': 'edit-me',
  'title': 'Old title',
  'questions': [
    {
      'id': 'a',
      'type': 'choice',
      'text': 'Pick',
      'required': true,
      'options': [
        {'id': 'x', 'label': 'X'},
        {'id': 'y', 'label': 'Y', 'description': 'why'},
      ],
    },
  ],
};

void main() {
  setUpAll(() async {
    await base.loadFont('Inter', ['assets/fonts/inter-latin.ttf']);
  });
  setUp(setUpTestI18n);
  setUp(() {
    base.rust = installFakeRust();
    UiPrefsStore.instance = UiPrefsStore(MemoryUiPrefsBackend());
  });

  test('admin token is stored, read and forgotten', () {
    final prefs = UiPrefsStore(MemoryUiPrefsBackend());
    expect(readSurveyAdminToken(prefs), isNull);
    saveSurveyAdminToken('  secret ', prefs);
    expect(readSurveyAdminToken(prefs), 'secret');
    forgetSurveyAdminToken(prefs);
    expect(readSurveyAdminToken(prefs), isNull);
  });

  testWidgets('editing keeps ids and saves the changed survey', (tester) async {
    Map<String, Object?>? saved;
    var activated = false;
    await base.openModal(
      tester,
      (close) => SurveyFormModal(
        initial: sample(),
        onClose: close,
        onSave: (survey, activate) async {
          saved = survey;
          activated = activate;
        },
      ),
    );
    await tester.enterText(find.text('Old title'), 'New title');
    await tester.tap(find.text('Save'));
    await base.settle(tester);
    expect(saved?['id'], 'edit-me');
    expect(saved?['title'], 'New title');
    final question = (saved!['questions']! as List).single as Map<String, Object?>;
    expect(question['id'], 'a');
    expect((question['options']! as List).map((o) => (o as Map)['id']), ['x', 'y']);
    expect(Survey.tryParse(saved), isNotNull);
    expect(activated, isFalse);
  });

  testWidgets('a survey without a title is not saved and shows why', (tester) async {
    var calls = 0;
    await base.openModal(
      tester,
      (close) => SurveyFormModal(onClose: close, onSave: (_, _) async => calls++),
    );
    await tester.tap(find.text('Save'));
    await base.settle(tester);
    expect(calls, 0);
    expect(find.text('Add a title.'), findsOneWidget);
  });
}
