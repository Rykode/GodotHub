import 'package:material_ui/material_ui.dart';

import '../design/design.dart';
import '../survey/survey_admin.dart';
import '../ui/controls/text_input.dart';
import '../ui/core/button.dart';
import '../ui/feedback/confirm_dialog.dart';
import '../ui/feedback/modal_shell.dart';
import '../ui/reusables/labelled_field.dart';
import 'survey_form_modal.dart';

// Developer-only survey manager. Plain English, not translated.

class SurveyEditorModal extends StatefulWidget {
  const SurveyEditorModal({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  State<SurveyEditorModal> createState() => _SurveyEditorModalState();
}

class _SurveyEditorModalState extends State<SurveyEditorModal> {
  final _token = TextEditingController();
  SurveyAdminClient? _client;
  SurveyAdminList? _data;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final token = readSurveyAdminToken();
    if (token != null) {
      _client = SurveyAdminClient(token: token);
      _reload();
    }
  }

  @override
  void dispose() {
    _token.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await action();
    } on SurveyAdminException catch (e) {
      if (!mounted) return;
      if (e.unauthorized) forgetSurveyAdminToken();
      setState(() {
        _error = e.message;
        if (e.unauthorized) {
          _client = null;
          _data = null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reload() => _run(() async {
    final data = await _client!.list();
    if (mounted) setState(() => _data = data);
  });

  void _connect() {
    final token = _token.text.trim();
    if (token.isEmpty) return;
    saveSurveyAdminToken(token);
    _token.clear();
    setState(() => _client = SurveyAdminClient(token: token));
    _reload().ignore();
  }

  void _disconnect() {
    forgetSurveyAdminToken();
    setState(() {
      _client = null;
      _data = null;
      _error = null;
    });
  }

  Future<void> _edit(Map<String, Object?>? survey) async {
    await showGhModal<void>(
      context,
      (modal) => SurveyFormModal(
        initial: survey,
        onClose: () => Navigator.of(modal).pop(),
        onSave: (saved, activate) async {
          final client = _client!;
          if (survey == null && (_data?.surveys.any((s) => s['id'] == saved['id']) ?? false)) {
            throw const SurveyAdminException('A survey with this id already exists. Pick a new id.');
          }
          await client.save(saved);
          if (activate) await client.setActive(saved['id']! as String);
          if (modal.mounted) Navigator.of(modal).pop();
        },
      ),
    );
    if (mounted) await _reload();
  }

  Future<void> _delete(Map<String, Object?> survey) async {
    final confirmed = await showGhConfirmDialog(
      context,
      title: 'Delete survey?',
      description: '"${survey['title']}" is removed from the server. Responses already sent stay in Discord.',
      confirmLabel: 'Delete',
      variant: GhConfirmVariant.danger,
    );
    if (!confirmed || !mounted) return;
    await _run(() => _client!.delete(survey['id']! as String));
    if (mounted) await _reload();
  }

  Future<void> _setActive(String? id) async {
    await _run(() => _client!.setActive(id));
    if (mounted) await _reload();
  }

  Widget _row(GhTheme theme, Map<String, Object?> survey, String? active) {
    final id = survey['id']! as String;
    final isActive = id == active;
    final expires = survey['expires'] as String?;
    final expired = expires != null && (DateTime.tryParse(expires)?.isBefore(DateTime.now()) ?? false);
    final status = [if (isActive) 'Active', if (expired) 'Expired', if (expires != null && !expired) 'Expires $expires'].join(' · ');
    return Container(
      padding: EdgeInsets.all(theme.space(3)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(theme.radiusItem),
        border: Border.all(color: isActive ? theme.accent : theme.outline.withValues(alpha: 0.5)),
      ),
      child: Row(
        spacing: theme.space(3),
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: theme.space(0.5),
              children: [
                Text('${survey['title']}', style: theme.text(size: GhTextSize.sm, weight: GhWeight.medium)),
                Text(
                  [id, if (status.isNotEmpty) status].join(' · '),
                  style: theme.text(size: GhTextSize.x2s, color: theme.muted),
                ),
              ],
            ),
          ),
          GhButton(
            onPressed: _loading ? null : () => _setActive(isActive ? null : id),
            label: isActive ? 'Stop' : 'Activate',
            variant: isActive ? GhButtonVariant.outline : GhButtonVariant.subtle,
          ),
          GhButton(onPressed: _loading ? null : () => _edit(survey).ignore(), label: 'Edit'),
          GhButton(onPressed: _loading ? null : () => _delete(survey).ignore(), icon: GhIcons.trash, semanticLabel: 'Delete survey'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = GhTheme.of(context);
    final data = _data;
    final connected = _client != null;
    return GhModalShell(
      icon: GhIcon(GhIcons.pencil, size: theme.space(5), color: theme.muted),
      title: 'Surveys',
      maxWidth: GhModalWidth.xl,
      onClose: widget.onClose,
      error: _error,
      footer: [
        if (connected) GhButton(onPressed: _disconnect, label: 'Forget admin token'),
        const Spacer(),
        GhButton(onPressed: widget.onClose, label: 'Close'),
        if (connected) GhButton(onPressed: _loading ? null : () => _edit(null).ignore(), label: 'New survey', variant: GhButtonVariant.primary),
      ],
      child: Padding(
        padding: EdgeInsets.all(theme.space(6)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: theme.space(3),
          children: [
            Text(
              'Edit the surveys on the survey server. Changes need no app release. Apps cache the active survey for about 5 minutes.',
              style: theme.text(size: GhTextSize.xs, color: theme.muted, lineHeight: 1.625),
            ),
            if (!connected)
              GhLabelledField(
                label: 'Admin token',
                hint: 'The SURVEY_ADMIN_TOKEN secret of the Worker. It is kept on this computer only.',
                child: Row(
                  spacing: theme.space(2),
                  children: [
                    Expanded(
                      child: GhTextInput(controller: _token, obscureText: true, onSubmitted: (_) => _connect()),
                    ),
                    GhButton(onPressed: _connect, label: 'Connect', variant: GhButtonVariant.primary),
                  ],
                ),
              )
            else if (data == null)
              Text(_loading ? 'Loading…' : 'Could not load surveys.', style: theme.text(size: GhTextSize.sm, color: theme.muted))
            else ...[
              if (data.surveys.isEmpty) Text('No surveys yet.', style: theme.text(size: GhTextSize.sm, color: theme.muted)),
              for (final s in data.surveys) _row(theme, s, data.active),
              if (data.active == null && data.surveys.isNotEmpty)
                Text('No survey is active, so apps show nothing.', style: theme.text(size: GhTextSize.xs, color: theme.muted)),
            ],
          ],
        ),
      ),
    );
  }
}
