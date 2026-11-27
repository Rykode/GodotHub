import 'package:material_ui/material_ui.dart';

import '../design/design.dart';
import '../survey/survey.dart';
import '../ui/controls/checkbox.dart';
import '../ui/controls/text_input.dart';
import '../ui/core/button.dart';
import '../ui/feedback/modal_shell.dart';
import '../ui/reusables/labelled_field.dart';
import '../ui/reusables/segmented.dart';

// Developer-only survey editor. Plain English, not translated.

final _idPattern = RegExp(r'^[A-Za-z0-9_.-]{1,64}$');

class _OptionDraft {
  _OptionDraft({this.id, String label = '', String description = ''})
    : label = TextEditingController(text: label),
      description = TextEditingController(text: description);

  String? id;
  final TextEditingController label;
  final TextEditingController description;

  void dispose() {
    label.dispose();
    description.dispose();
  }
}

class _QuestionDraft {
  _QuestionDraft({this.id, this.type = SurveyQuestionType.choice, String text = '', this.required = false, List<_OptionDraft>? options})
    : text = TextEditingController(text: text),
      options = options ?? [];

  String? id;
  SurveyQuestionType type;
  final TextEditingController text;
  bool required;
  final List<_OptionDraft> options;

  void dispose() {
    text.dispose();
    for (final o in options) {
      o.dispose();
    }
  }
}

String _slug(String text) {
  final slug = text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
  return slug.length > 40 ? slug.substring(0, 40) : slug;
}

String _unique(String base, Set<String> used) {
  var candidate = base;
  var n = 2;
  while (used.contains(candidate)) {
    candidate = '${base}_$n';
    n++;
  }
  used.add(candidate);
  return candidate;
}

class SurveyFormModal extends StatefulWidget {
  const SurveyFormModal({super.key, this.initial, required this.onSave, required this.onClose});

  final Map<String, Object?>? initial;
  final Future<void> Function(Map<String, Object?> survey, bool activate) onSave;
  final VoidCallback onClose;

  @override
  State<SurveyFormModal> createState() => _SurveyFormModalState();
}

class _SurveyFormModalState extends State<SurveyFormModal> {
  late final TextEditingController _id;
  late final TextEditingController _title;
  late final TextEditingController _intro;
  late final TextEditingController _expires;
  final List<_QuestionDraft> _questions = [];
  bool _activate = false;
  bool _busy = false;
  String? _error;

  bool get _isNew => widget.initial == null;

  @override
  void initState() {
    super.initState();
    final s = widget.initial;
    final now = DateTime.now();
    _id = TextEditingController(text: (s?['id'] as String?) ?? 'survey-${now.year}-${now.month.toString().padLeft(2, '0')}');
    _title = TextEditingController(text: (s?['title'] as String?) ?? '');
    _intro = TextEditingController(text: (s?['intro'] as String?) ?? '');
    _expires = TextEditingController(text: ((s?['expires'] as String?) ?? '').split('T').first);
    if (s != null) {
      for (final q in (s['questions'] as List<Object?>? ?? const [])) {
        if (q is! Map<String, Object?>) continue;
        _questions.add(
          _QuestionDraft(
            id: q['id'] as String?,
            type: q['type'] == 'text' ? SurveyQuestionType.text : SurveyQuestionType.choice,
            text: (q['text'] as String?) ?? '',
            required: q['required'] == true,
            options: [
              for (final o in (q['options'] as List<Object?>? ?? const []))
                if (o is Map<String, Object?>)
                  _OptionDraft(id: o['id'] as String?, label: (o['label'] as String?) ?? '', description: (o['description'] as String?) ?? ''),
            ],
          ),
        );
      }
    }
    if (_questions.isEmpty) _questions.add(_newChoice());
  }

  _QuestionDraft _newChoice() => _QuestionDraft(options: [_OptionDraft(), _OptionDraft()]);

  @override
  void dispose() {
    _id.dispose();
    _title.dispose();
    _intro.dispose();
    _expires.dispose();
    for (final q in _questions) {
      q.dispose();
    }
    super.dispose();
  }

  (Map<String, Object?>?, String?) _build() {
    final id = _id.text.trim();
    if (!_idPattern.hasMatch(id)) return (null, 'The survey id may only use letters, numbers, "_", "." and "-" (max 64).');
    if (_title.text.trim().isEmpty) return (null, 'Add a title.');
    final expires = _expires.text.trim();
    if (expires.isNotEmpty && DateTime.tryParse(expires) == null) return (null, 'Expires must be a date like 2027-03-01, or empty.');
    if (_questions.isEmpty) return (null, 'Add at least one question.');

    final usedQuestionIds = {for (final q in _questions) if (q.id != null) q.id!};
    final questions = <Map<String, Object?>>[];
    for (final (i, q) in _questions.indexed) {
      final text = q.text.text.trim();
      if (text.isEmpty) return (null, 'Question ${i + 1} needs text.');
      final qid = q.id ?? _unique('q${i + 1}', usedQuestionIds);
      if (q.type == SurveyQuestionType.text) {
        questions.add({'id': qid, 'type': 'text', 'text': text, 'required': q.required});
        continue;
      }
      if (q.options.length < 2) return (null, 'Question ${i + 1} needs at least 2 options.');
      final usedOptionIds = {for (final o in q.options) if (o.id != null) o.id!};
      final options = <Map<String, Object?>>[];
      for (final (j, o) in q.options.indexed) {
        final label = o.label.text.trim();
        if (label.isEmpty) return (null, 'Option ${j + 1} of question ${i + 1} needs a label.');
        final oid = o.id ?? _unique(_slug(label).isEmpty ? 'option' : _slug(label), usedOptionIds);
        final description = o.description.text.trim();
        options.add({'id': oid, 'label': label, if (description.isNotEmpty) 'description': description});
      }
      questions.add({'id': qid, 'type': 'choice', 'text': text, 'required': q.required, 'options': options});
    }
    final intro = _intro.text.trim();
    final survey = <String, Object?>{
      'id': id,
      'title': _title.text.trim(),
      if (intro.isNotEmpty) 'intro': intro,
      if (expires.isNotEmpty) 'expires': expires,
      'questions': questions,
    };
    if (Survey.tryParse(survey) == null) return (null, 'This survey is not valid.');
    return (survey, null);
  }

  Future<void> _save() async {
    final (survey, problem) = _build();
    if (survey == null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSave(survey, _activate);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '$e';
      });
    }
  }

  Widget _optionRow(GhTheme theme, _QuestionDraft q, _OptionDraft o) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: theme.space(2),
    children: [
      Expanded(
        flex: 2,
        child: GhTextInput(controller: o.label, placeholder: 'Label', enabled: !_busy),
      ),
      Expanded(
        flex: 3,
        child: GhTextInput(controller: o.description, placeholder: 'Description (optional)', enabled: !_busy),
      ),
      GhButton(
        onPressed: _busy || q.options.length <= 2
            ? null
            : () => setState(() {
                q.options.remove(o);
                o.dispose();
              }),
        icon: GhIcons.x,
        semanticLabel: 'Remove option',
      ),
    ],
  );

  Widget _questionCard(GhTheme theme, int index, _QuestionDraft q) {
    final isChoice = q.type == SurveyQuestionType.choice;
    return Container(
      padding: EdgeInsets.all(theme.space(3)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(theme.radiusItem),
        border: Border.all(color: theme.outline.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: theme.space(2.5),
        children: [
          Row(
            spacing: theme.space(3),
            children: [
              Text('Question ${index + 1}', style: theme.text(size: GhTextSize.xs, weight: GhWeight.semibold, color: theme.muted)),
              GhSegmented(
                value: isChoice ? 'choice' : 'text',
                options: [ghSegment('choice', 'Choice'), ghSegment('text', 'Text')],
                onChanged: (v) => setState(() {
                  q.type = v == 'text' ? SurveyQuestionType.text : SurveyQuestionType.choice;
                  if (q.type == SurveyQuestionType.choice && q.options.length < 2) {
                    while (q.options.length < 2) {
                      q.options.add(_OptionDraft());
                    }
                  }
                }),
              ),
              const Spacer(),
              GhCheckbox(checked: q.required, onChanged: _busy ? null : (v) => setState(() => q.required = v), label: 'Required'),
              GhButton(
                onPressed: _busy || _questions.length <= 1
                    ? null
                    : () => setState(() {
                        _questions.remove(q);
                        q.dispose();
                      }),
                icon: GhIcons.trash,
                semanticLabel: 'Remove question',
              ),
            ],
          ),
          GhTextInput(controller: q.text, placeholder: 'Question text', enabled: !_busy),
          if (isChoice) ...[
            for (final o in q.options) _optionRow(theme, q, o),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: GhButton(
                onPressed: _busy || q.options.length >= 8 ? null : () => setState(() => q.options.add(_OptionDraft())),
                label: 'Add option',
                icon: GhIcons.plus,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = GhTheme.of(context);
    return GhModalShell(
      icon: GhIcon(GhIcons.pencil, size: theme.space(5), color: theme.muted),
      title: _isNew ? 'New survey' : 'Edit survey',
      maxWidth: GhModalWidth.x2l,
      onClose: _busy ? null : widget.onClose,
      error: _error,
      footer: [
        GhCheckbox(checked: _activate, onChanged: _busy ? null : (v) => setState(() => _activate = v), label: 'Make active after saving'),
        const Spacer(),
        GhButton(onPressed: _busy ? null : widget.onClose, label: 'Cancel'),
        GhButton(onPressed: _busy ? null : _save, label: _busy ? 'Saving…' : 'Save', variant: GhButtonVariant.primary),
      ],
      child: Padding(
        padding: EdgeInsets.all(theme.space(6)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: theme.space(3),
          children: [
            GhLabelledField(
              label: 'Survey id',
              hint: _isNew ? 'Unique. Each install sees a survey id once, so use a new id for a new survey.' : 'The id cannot change after saving.',
              child: GhTextInput(controller: _id, enabled: _isNew && !_busy, mono: true),
            ),
            GhLabelledField(
              label: 'Title',
              required: true,
              child: GhTextInput(controller: _title, enabled: !_busy),
            ),
            GhLabelledField(
              label: 'Intro',
              optional: true,
              child: GhTextInput(controller: _intro, maxLines: 3, minLines: 2, enabled: !_busy),
            ),
            GhLabelledField(
              label: 'Expires',
              optional: true,
              hint: 'A date like 2027-03-01. After it the survey is no longer shown or accepted.',
              child: GhTextInput(controller: _expires, placeholder: 'YYYY-MM-DD', enabled: !_busy),
            ),
            for (final (i, q) in _questions.indexed) _questionCard(theme, i, q),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: GhButton(
                onPressed: _busy || _questions.length >= surveyMaxQuestions ? null : () => setState(() => _questions.add(_newChoice())),
                label: 'Add question',
                icon: GhIcons.plus,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
