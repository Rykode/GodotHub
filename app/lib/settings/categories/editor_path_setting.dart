import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api.dart';
import '../../design/design.dart';
import '../../logic/settings_copy.dart';
import '../../state/settings.dart';
import '../../ui/controls/text_input.dart';
import '../settings_parts.dart';
import 'settings_buttons.dart';
import 'settings_option_controls.dart';

String _ts(String key) => settingsTr(key);

/// The program "Open in IDE" starts with the project folder. Left empty, GodotHub tries
/// the usual editors found on the PATH (VS Code, Rider, IntelliJ, VSCodium, Zed).
class EditorPathSetting extends ConsumerStatefulWidget {
  const EditorPathSetting({super.key});

  @override
  ConsumerState<EditorPathSetting> createState() => _EditorPathSettingState();
}

class _EditorPathSettingState extends ConsumerState<EditorPathSetting> {
  final _controller = TextEditingController();
  bool _loaded = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _commit() {
    final value = _controller.text.trim();
    if (value != _controller.text) _controller.text = value;
    saveSettings(ref, (s) => copySettings(s, externalEditorPath: () => value.isEmpty ? null : value)).ignore();
  }

  Future<void> _browse() async {
    final picked = await Api.pickExecutable();
    if (picked == null || !mounted) return;
    _controller.text = picked;
    _commit();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider).value;
    if (settings == null) return const SizedBox.shrink();
    if (!_loaded) {
      _loaded = true;
      _controller.text = settings.externalEditorPath ?? '';
    }
    final theme = GhTheme.of(context);
    return SettingRow(
      label: _ts('editor_path_label'),
      divider: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: theme.space(2),
        children: [
          GhTextInput(
            controller: _controller,
            placeholder: _ts('editor_path_placeholder'),
            semanticLabel: _ts('editor_path_label'),
            mono: true,
            size: GhTextSize.xs,
            width: theme.space(72),
            onSubmitted: (_) => _commit(),
            onBlur: _commit,
            background: theme.overlay,
            borderColor: theme.outline.withValues(alpha: 0.5),
            focusBorderColor: theme.accentDim,
            borderRadius: BorderRadius.circular(theme.radiusBtn),
            padding: EdgeInsets.symmetric(horizontal: theme.space(3.5), vertical: theme.space(2.5)),
          ),
          SettingsButton(label: _ts('editor_path_browse'), compact: true, onPressed: _browse),
        ],
      ),
    );
  }
}
