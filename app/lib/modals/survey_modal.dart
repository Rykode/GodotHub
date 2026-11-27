import 'package:material_ui/material_ui.dart';

import '../design/design.dart';
import '../survey/survey.dart';
import '../ui/controls/text_input.dart';
import '../ui/core/button.dart';
import '../ui/core/interaction.dart';
import '../ui/feedback/modal_shell.dart';
import '../ui/reusables/labelled_field.dart';

// Plain English on purpose (remote surveys are not translated, see survey.dart).

class SurveyModal extends StatefulWidget {
  const SurveyModal({super.key, required this.survey, required this.onSend, required this.onClose});

  final Survey survey;

  final Future<void> Function(Map<String, String> answers) onSend;
  final VoidCallback onClose;

  @override
  State<SurveyModal> createState() => _SurveyModalState();
}

class _SurveyModalState extends State<SurveyModal> {
  final Map<String, String> _choices = {};
  final Map<String, TextEditingController> _texts = {};
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final q in widget.survey.questions) {
      if (q.type == SurveyQuestionType.text) {
        _texts[q.id] = TextEditingController()..addListener(() => setState(() {}));
      }
    }
  }

  @override
  void dispose() {
    for (final c in _texts.values) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, String> _answers() => {
    ..._choices,
    for (final e in _texts.entries)
      if (e.value.text.trim().isNotEmpty) e.key: e.value.text,
  };

  bool get _ready {
    final answers = _answers();
    final any = answers.isNotEmpty;
    return any && widget.survey.questions.every((q) => !q.required || answers.containsKey(q.id));
  }

  Future<void> _send() async {
    if (!_ready || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.onSend(_answers());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = e is Exception ? e.toString().replaceFirst(RegExp(r'^\w*Exception: '), '') : 'Could not send your answers.';
      });
    }
  }

  Widget _choice(GhTheme theme, SurveyQuestion q, SurveyOption option) {
    final selected = _choices[q.id] == option.id;
    final description = option.description;
    return GhPressable(
      key: ValueKey('survey-option:${q.id}:${option.id}'),
      onPressed: _sending ? null : () => setState(() => _choices[q.id] = option.id),
      selected: selected,
      semanticLabel: option.label,
      excludeChildSemantics: true,
      borderRadius: BorderRadius.circular(theme.radiusBtn),
      builder: (context, states) => Container(
        width: double.infinity,
        padding: EdgeInsets.all(theme.space(3)),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(theme.radiusBtn),
          border: Border.all(color: selected ? theme.accent : theme.outline.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: theme.space(0.5),
          children: [
            Text(option.label, style: theme.text(size: GhTextSize.sm, weight: GhWeight.medium)),
            if (description != null) Text(description, style: theme.text(size: GhTextSize.xs, color: theme.muted)),
          ],
        ),
      ),
    );
  }

  Widget _question(GhTheme theme, SurveyQuestion q) {
    if (q.type == SurveyQuestionType.text) {
      return GhLabelledField(
        label: q.text,
        optional: !q.required,
        required: q.required,
        child: GhTextInput(
          controller: _texts[q.id],
          placeholder: 'Max $surveyMaxText characters',
          maxLines: 4,
          minLines: 3,
          enabled: !_sending,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: theme.space(2),
      children: [
        Text(q.text, style: theme.text(size: GhTextSize.sm, weight: GhWeight.medium)),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < theme.rem(30) || q.options.length > 4) {
              return Column(spacing: theme.space(2), children: [for (final option in q.options) _choice(theme, q, option)]);
            }
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: theme.space(2),
                children: [for (final option in q.options) Expanded(child: _choice(theme, q, option))],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _surveyBadge(GhTheme theme) {
    final count = widget.survey.questions.length;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: theme.space(2.5), vertical: theme.space(1)),
        decoration: BoxDecoration(
          color: theme.accent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(theme.space(10)),
          border: Border.all(color: theme.accent.withValues(alpha: 0.4)),
        ),
        child: Text(
          'SURVEY · $count ${count == 1 ? 'question' : 'questions'} · optional',
          style: theme.text(size: GhTextSize.x2s, weight: GhWeight.semibold, color: theme.accentBright),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = GhTheme.of(context);
    final intro = widget.survey.intro;
    return GhModalShell(
      icon: GhIcon(GhIcons.info, size: theme.space(5), color: theme.muted),
      title: widget.survey.title,
      maxWidth: GhModalWidth.x2l,
      dismissOnBackdrop: false,
      onClose: _sending ? null : widget.onClose,
      error: _error,
      footer: [
        const Spacer(),
        GhButton(onPressed: _ready && !_sending ? _send : null, label: _sending ? 'Sending…' : 'Send', variant: GhButtonVariant.primary),
      ],
      child: Padding(
        padding: EdgeInsets.fromLTRB(theme.space(6), 0, theme.space(6), theme.space(4)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: theme.space(4),
          children: [
            _surveyBadge(theme),
            Text(
              '${intro == null ? '' : '$intro '}\nYour answers go to me (Ryko) only. They are sent with a random ID, '
              'the app version and your operating system. Nothing about you or your projects.',
              style: theme.text(size: GhTextSize.sm, color: theme.muted, lineHeight: 1.625),
            ),
            for (final q in widget.survey.questions) _question(theme, q),
          ],
        ),
      ),
    );
  }
}
