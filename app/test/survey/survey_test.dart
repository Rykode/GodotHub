import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:godothub/src/ui_prefs.dart';
import 'package:godothub/survey/survey.dart';

Map<String, Object?> definition() => {
  'id': 's1',
  'title': 'T',
  'expires': '2027-01-01',
  'questions': [
    {
      'id': 'a',
      'type': 'choice',
      'text': 'Q',
      'required': true,
      'options': [
        {'id': 'x', 'label': 'X'},
      ],
    },
    {'id': 'c', 'type': 'text', 'text': 'More?'},
  ],
};

void main() {
  test('parses a valid survey and rejects malformed ones', () {
    final survey = Survey.tryParse(definition())!;
    expect(survey.questions.length, 2);
    expect(survey.questions.first.required, isTrue);
    expect(Survey.tryParse(null), isNull);
    expect(Survey.tryParse({...definition(), 'questions': []}), isNull);
    expect(Survey.tryParse({...definition(), 'questions': [{'id': 'a', 'type': 'choice', 'text': 'Q'}]}), isNull);
    expect(Survey.tryParse({...definition(), 'questions': [{'id': 'a', 'type': 'nope', 'text': 'Q'}]}), isNull);
  });

  test('install id is a v4 uuid the relay accepts', () {
    final id = newInstallId(Random(1));
    expect(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$').hasMatch(id), isTrue);
  });

  test('payload drops blank answers and caps text', () {
    final survey = Survey.tryParse(definition())!;
    final payload = surveyPayload(
      survey: survey,
      answers: {'a': 'x', 'c': 'z' * 900},
      appVersion: '1.6.4',
      installId: 'i',
      platform: 'windows',
    );
    expect(payload['v'], 2);
    expect(payload['surveyId'], 's1');
    expect(((payload['answers']! as Map)['c'] as String).length, surveyMaxText);
    final blank = surveyPayload(survey: survey, answers: {'a': 'x', 'c': '  '}, appVersion: '1', installId: 'i', platform: 'linux');
    expect((blank['answers']! as Map).containsKey('c'), isFalse);
  });

  test('a survey shows once per id and not after it expires', () {
    final prefs = UiPrefsStore(MemoryUiPrefsBackend());
    final survey = Survey.tryParse(definition())!;
    final now = DateTime(2026, 11, 27);
    expect(shouldShowSurvey(survey, prefs: prefs, now: now), isTrue);
    expect(shouldShowSurvey(survey, prefs: prefs, now: DateTime(2027, 2, 1)), isFalse);
    markSurveyDone('s1', prefs);
    expect(shouldShowSurvey(survey, prefs: prefs, now: now), isFalse);
    final other = Survey.tryParse({...definition(), 'id': 's2'})!;
    expect(shouldShowSurvey(other, prefs: prefs, now: now), isTrue);
  });

  test('install id is created once and reused', () {
    final prefs = UiPrefsStore(MemoryUiPrefsBackend());
    expect(surveyInstallId(prefs), surveyInstallId(prefs));
  });
}
