import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/design.dart';
import '../../logic/settings_copy.dart';
import '../../state/settings.dart';
import '../../ui/core/interaction.dart';
import '../../ui/overlays/dropdown.dart';
import '../../ui/overlays/menu.dart';
import '../../ui/feedback/confirm_removal.dart';
import '../../ui/core/ui_settings.dart';
import '../settings_parts.dart';
import 'settings_option_controls.dart' show saveSettings, settingsTr;
import 'settings_buttons.dart';

String _ts(String key) => settingsTr(key);

/// Manages which destructive confirmations are skipped. A confirmation lands
/// here when "Don't ask again" is ticked on it; removing it asks again.
class SkippedConfirmationsSetting extends ConsumerWidget {
  const SkippedConfirmationsSetting({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = GhTheme.of(context);
    final skipped = ref.watch(settingsProvider.select((s) => s.value?.skippedConfirmations)) ?? const <String>[];
    final active = [for (final id in skipped) ?RemovalConfirm.byId(id)];
    final available = [
      for (final kind in RemovalConfirm.values)
        if (!skipped.contains(kind.id)) kind,
    ];

    void save(List<String> Function(List<String> current) change) =>
        saveSettings(ref, (s) => copySettings(s, skippedConfirmations: change(s.skippedConfirmations))).ignore();

    return SettingsSubsection(
      id: 'advanced-skipped-confirmations',
      title: _ts('skipped_confirmations_label'),
      searchText: '${_ts('skipped_confirmations_label')} ${[for (final k in RemovalConfirm.values) _ts(k.labelKey)].join(' ')}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: theme.space(2.5),
        children: [
          if (available.isNotEmpty)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: GhDropdown(
                align: GhSide.left,
                items: [
                  for (final kind in available)
                    GhMenuItem(id: kind.id, label: _ts(kind.labelKey), onSelected: () => save((current) => [...current, kind.id])),
                ],
                trigger: (context, open, toggle) => SettingsButton(
                  onPressed: toggle,
                  label: _ts('skipped_confirmations_add'),
                  icon: GhIcons.plus,
                  tone: SettingsButtonTone.quiet,
                  compact: true,
                  radius: theme.radiusItem,
                ),
              ),
            ),
          if (active.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: theme.space(1.5),
              children: [
                for (final kind in active)
                  Container(
                    key: ValueKey('skipped:${kind.id}'),
                    padding: EdgeInsets.symmetric(horizontal: theme.space(3), vertical: theme.space(2)),
                    decoration: BoxDecoration(
                      color: theme.raised,
                      borderRadius: BorderRadius.circular(theme.radiusItem),
                      border: Border.all(color: theme.line),
                    ),
                    child: Row(
                      spacing: theme.space(3),
                      children: [
                        Expanded(
                          child: Text(
                            _ts(kind.labelKey),
                            overflow: TextOverflow.ellipsis,
                            style: theme.text(size: GhTextSize.xs, color: theme.ink),
                          ),
                        ),
                        GhPressable(
                          onPressed: () => save(
                            (current) => [
                              for (final id in current)
                                if (id != kind.id) id,
                            ],
                          ),
                          semanticLabel: _ts('skipped_confirmations_remove'),
                          borderRadius: BorderRadius.circular(theme.radiusMd),
                          builder: (context, states) => GhAnimatedBox(
                            width: theme.space(6),
                            height: theme.space(6),
                            alignment: Alignment.center,
                            color: states.active ? theme.danger.withValues(alpha: 0.1) : theme.danger.withValues(alpha: 0),
                            borderRadius: BorderRadius.circular(theme.radiusMd),
                            child: GhIcon(GhIcons.x, size: theme.space(3.5), color: states.active ? theme.danger : theme.muted),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
