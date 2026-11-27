import 'dart:convert';
import 'dart:io';

import '../src/ui_prefs.dart';
import 'survey.dart';

// Developer-only: talks to the relay's /admin API to edit surveys. Plain English, not translated.
const surveyAdminTokenKey = 'survey_admin_token';

String? readSurveyAdminToken([UiPrefsStore? prefs]) {
  final value = (prefs ?? UiPrefsStore.instance).getItem(surveyAdminTokenKey);
  return value == null || value.isEmpty ? null : value;
}

void saveSurveyAdminToken(String token, [UiPrefsStore? prefs]) => (prefs ?? UiPrefsStore.instance).setItem(surveyAdminTokenKey, token.trim());

void forgetSurveyAdminToken([UiPrefsStore? prefs]) => (prefs ?? UiPrefsStore.instance).removeItem(surveyAdminTokenKey);

typedef SurveyAdminList = ({String? active, List<Map<String, Object?>> surveys});

class SurveyAdminException implements Exception {
  const SurveyAdminException(this.message, {this.unauthorized = false});

  final String message;
  final bool unauthorized;

  @override
  String toString() => message;
}

class SurveyAdminClient {
  SurveyAdminClient({required this.token, this.endpoint = surveyEndpoint});

  final String token;
  final String endpoint;

  Uri _uri(String path) => Uri.parse('${endpoint.replaceAll(RegExp(r'/+$'), '')}$path');

  Future<Object?> _call(String method, String path, [Object? body]) async {
    final client = HttpClient()..connectionTimeout = surveyTimeout;
    try {
      final request = await client.openUrl(method, _uri(path)).timeout(surveyTimeout);
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.add(utf8.encode(jsonEncode(body)));
      }
      final response = await request.close().timeout(surveyTimeout);
      final text = await response.transform(utf8.decoder).join().timeout(surveyTimeout);
      if (response.statusCode == 401) throw const SurveyAdminException('Wrong admin token.', unauthorized: true);
      if (response.statusCode == 429) throw const SurveyAdminException('Too many failed attempts. Try again in an hour.');
      if (response.statusCode == 404 && path.startsWith('/admin/') && text.contains('not_found')) {
        throw const SurveyAdminException('The survey server has no admin token set (SURVEY_ADMIN_TOKEN).');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final detail = (() {
          try {
            return (jsonDecode(text) as Map<String, Object?>)['error'];
          } catch (_) {
            return null;
          }
        })();
        throw SurveyAdminException('The survey server answered ${response.statusCode}${detail == null ? '' : ' ($detail)'}.');
      }
      return text.isEmpty ? null : jsonDecode(text);
    } on SurveyAdminException {
      rethrow;
    } catch (e) {
      throw SurveyAdminException('Could not reach the survey server: $e');
    } finally {
      client.close(force: true);
    }
  }

  Future<SurveyAdminList> list() async {
    final data = await _call('GET', '/admin/surveys') as Map<String, Object?>;
    return (
      active: data['active'] as String?,
      surveys: [for (final s in (data['surveys'] as List<Object?>? ?? const [])) if (s is Map<String, Object?>) s],
    );
  }

  Future<void> save(Map<String, Object?> survey) => _call('PUT', '/admin/surveys/${survey['id']}', survey);

  Future<void> delete(String id) => _call('DELETE', '/admin/surveys/$id');

  Future<void> setActive(String? id) => _call('PUT', '/admin/active', {'id': id});
}
