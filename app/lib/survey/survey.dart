import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../src/ui_prefs.dart';

// Survey text is plain English on purpose: surveys are defined remotely and are not translated UI.
const surveyEndpoint = 'https://godothub-survey-relay.rayyanaziz76.workers.dev';

const surveyInstallIdKey = 'survey_install_id';
const surveyMaxText = 500;
const surveyMaxQuestions = 5;
const surveyTimeout = Duration(seconds: 10);

String surveyDoneKey(String surveyId) => 'survey_done:$surveyId';

class SurveyOption {
  const SurveyOption({required this.id, required this.label, this.description});

  final String id;
  final String label;
  final String? description;
}

enum SurveyQuestionType { choice, text }

class SurveyQuestion {
  const SurveyQuestion({required this.id, required this.type, required this.text, this.required = false, this.options = const []});

  final String id;
  final SurveyQuestionType type;
  final String text;
  final bool required;
  final List<SurveyOption> options;
}

class Survey {
  const Survey({required this.id, required this.title, required this.questions, this.intro, this.expires});

  final String id;
  final String title;
  final String? intro;
  final DateTime? expires;
  final List<SurveyQuestion> questions;

  bool isExpired(DateTime now) => expires != null && now.isAfter(expires!);

  static Survey? tryParse(Object? json) {
    try {
      if (json is! Map<String, Object?>) return null;
      final id = json['id'];
      final title = json['title'];
      final rawQuestions = json['questions'];
      if (id is! String || id.isEmpty || title is! String || rawQuestions is! List) return null;
      final questions = <SurveyQuestion>[];
      for (final raw in rawQuestions.take(surveyMaxQuestions)) {
        if (raw is! Map<String, Object?>) return null;
        final qid = raw['id'];
        final text = raw['text'];
        if (qid is! String || text is! String) return null;
        final type = switch (raw['type']) {
          'choice' => SurveyQuestionType.choice,
          'text' => SurveyQuestionType.text,
          _ => null,
        };
        if (type == null) return null;
        final options = <SurveyOption>[];
        if (type == SurveyQuestionType.choice) {
          final rawOptions = raw['options'];
          if (rawOptions is! List || rawOptions.isEmpty) return null;
          for (final o in rawOptions) {
            if (o is! Map<String, Object?> || o['id'] is! String || o['label'] is! String) return null;
            options.add(SurveyOption(id: o['id']! as String, label: o['label']! as String, description: o['description'] as String?));
          }
        }
        questions.add(SurveyQuestion(id: qid, type: type, text: text, required: raw['required'] == true, options: options));
      }
      if (questions.isEmpty) return null;
      final expires = json['expires'];
      return Survey(
        id: id,
        title: title,
        intro: json['intro'] as String?,
        expires: expires is String ? DateTime.tryParse(expires) : null,
        questions: questions,
      );
    } catch (_) {
      return null;
    }
  }
}

Future<Survey?> fetchActiveSurvey({String endpoint = surveyEndpoint}) async {
  if (endpoint.isEmpty) return null;
  final client = HttpClient()..connectionTimeout = surveyTimeout;
  try {
    final request = await client.getUrl(Uri.parse('${endpoint.replaceAll(RegExp(r'/+$'), '')}/active')).timeout(surveyTimeout);
    final response = await request.close().timeout(surveyTimeout);
    if (response.statusCode != 200) {
      await response.drain<void>();
      return null;
    }
    final body = await response.transform(utf8.decoder).join().timeout(surveyTimeout);
    return Survey.tryParse(jsonDecode(body));
  } catch (_) {
    return null;
  } finally {
    client.close(force: true);
  }
}

bool shouldShowSurvey(Survey survey, {UiPrefsStore? prefs, DateTime? now}) {
  if (survey.isExpired(now ?? DateTime.now())) return false;
  return (prefs ?? UiPrefsStore.instance).getItem(surveyDoneKey(survey.id)) == null;
}

void markSurveyDone(String surveyId, [UiPrefsStore? prefs]) => (prefs ?? UiPrefsStore.instance).setItem(surveyDoneKey(surveyId), '1');

String newInstallId([Random? random]) {
  final rng = random ?? Random.secure();
  final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

String surveyInstallId([UiPrefsStore? prefs]) {
  final store = prefs ?? UiPrefsStore.instance;
  final existing = store.getItem(surveyInstallIdKey);
  if (existing != null && existing.isNotEmpty) return existing;
  final created = newInstallId();
  store.setItem(surveyInstallIdKey, created);
  return created;
}

String surveyPlatform() => Platform.isWindows ? 'windows' : (Platform.isMacOS ? 'macos' : 'linux');

Map<String, Object?> surveyPayload({
  required Survey survey,
  required Map<String, String> answers,
  required String appVersion,
  required String installId,
  required String platform,
}) {
  final clean = <String, String>{};
  for (final q in survey.questions) {
    final value = (answers[q.id] ?? '').trim();
    if (value.isEmpty) continue;
    clean[q.id] = q.type == SurveyQuestionType.text && value.length > surveyMaxText ? value.substring(0, surveyMaxText) : value;
  }
  return {'v': 2, 'surveyId': survey.id, 'installId': installId, 'answers': clean, 'appVersion': appVersion, 'platform': platform};
}

Future<void> sendSurvey(Map<String, Object?> payload, {String endpoint = surveyEndpoint}) async {
  final client = HttpClient()..connectionTimeout = surveyTimeout;
  try {
    final request = await client.postUrl(Uri.parse('${endpoint.replaceAll(RegExp(r'/+$'), '')}/')).timeout(surveyTimeout);
    request.headers.contentType = ContentType.json;
    request.add(utf8.encode(jsonEncode(payload)));
    final response = await request.close().timeout(surveyTimeout);
    await response.drain<void>();
    if (response.statusCode == 429) throw const HttpException('Too many responses from this network. Try again later.');
    if (response.statusCode < 200 || response.statusCode >= 300) throw HttpException('The survey server answered ${response.statusCode}.');
  } finally {
    client.close(force: true);
  }
}
