import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../design/design.dart';
import '../../motion/motion.dart';
import '../controls/search_bar.dart';
import '../core/i18n.dart';
import '../core/interaction.dart';
import '../core/tooltip.dart';
import 'color_swatch_picker.dart';

String _categoryLabel(BuildContext context, String id) {
  final tr = context.tr.common;
  return switch (id) {
    'general' => tr.icon_category_general,
    'work' => tr.icon_category_work,
    'tech' => tr.icon_category_tech,
    'creative' => tr.icon_category_creative,
    'nature' => tr.icon_category_nature,
    'travel' => tr.icon_category_travel,
    'fun' => tr.icon_category_fun,
    _ => tr.icon_category_all,
  };
}

/// Icon keys that match a search box and a category chip. `all` is every icon.
List<String> ghFilterWorkspaceIcons(String query, String category) {
  final pool = category == 'all' ? workspaceIconKeys : (workspaceIconCategories[category] ?? workspaceIconKeys);
  final words = query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) {
    return pool;
  }
  return [
    for (final key in pool)
      if (words.every(workspaceIconLabel(key).contains)) key,
  ];
}

class GhWorkspaceIconPicker extends StatefulWidget {
  const GhWorkspaceIconPicker({super.key, required this.value, required this.onChanged, required this.tint, required this.label});

  final String value;
  final ValueChanged<String> onChanged;

  /// The workspace colour, so the chosen icon previews in it.
  final Color tint;
  final String label;

  @override
  State<GhWorkspaceIconPicker> createState() => _GhWorkspaceIconPickerState();
}

class _GhWorkspaceIconPickerState extends State<GhWorkspaceIconPicker> {
  String _query = '';
  String _category = 'all';

  @override
  Widget build(BuildContext context) {
    final theme = GhTheme.of(context);
    final tr = context.tr.common;
    final keys = ghFilterWorkspaceIcons(_query, _category);
    final categories = ['all', ...workspaceIconCategories.keys];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.label,
          style: theme.text(size: GhTextSize.xs, weight: GhWeight.medium, color: theme.muted),
        ),
        SizedBox(height: theme.space(2)),
        GhSearchBar(
          key: const ValueKey('workspace-icon-search'),
          value: _query,
          onChanged: (next) => setState(() => _query = next),
          placeholder: tr.icon_search_placeholder,
        ),
        SizedBox(height: theme.space(2.5)),
        Wrap(
          spacing: theme.space(1.5),
          runSpacing: theme.space(1.5),
          children: [
            for (final id in categories)
              _CategoryChip(
                key: ValueKey('workspace-icon-category:$id'),
                label: _categoryLabel(context, id),
                active: _category == id,
                onPressed: () => setState(() => _category = id),
              ),
          ],
        ),
        SizedBox(height: theme.space(2.5)),
        Container(
          height: theme.space(58),
          decoration: BoxDecoration(
            color: theme.base.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(theme.radiusItem),
            border: Border.all(color: theme.outline.withValues(alpha: 0.5)),
          ),
          child: keys.isEmpty
              ? Center(
                  child: Text(
                    tr.icon_no_results,
                    style: theme.text(size: GhTextSize.xs, color: theme.muted),
                  ),
                )
              : _IconGrid(keys: keys, value: widget.value, tint: widget.tint, onChanged: widget.onChanged),
        ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({super.key, required this.label, required this.active, required this.onPressed});

  final String label;
  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = GhTheme.of(context);
    final radius = BorderRadius.circular(999);
    return GhPressable(
      onPressed: onPressed,
      borderRadius: radius,
      selected: active,
      semanticLabel: label,
      builder: (context, states) {
        final hover = states.active && !active;
        return GhAnimatedBox(
          padding: EdgeInsets.symmetric(horizontal: theme.space(2.5), vertical: theme.space(1)),
          borderRadius: radius,
          color: active
              ? theme.accent.withValues(alpha: 0.15)
              : hover
              ? theme.overlay
              : theme.overlay.withValues(alpha: 0),
          border: Border.all(
            color: active
                ? theme.accent
                : hover
                ? theme.accentDim
                : theme.outline.withValues(alpha: 0.5),
          ),
          child: Text(
            label,
            style: theme.text(
              size: GhTextSize.x2s,
              weight: active ? GhWeight.medium : GhWeight.normal,
              color: active ? theme.accentBright : theme.muted,
            ),
          ),
        );
      },
    );
  }
}

class _IconGrid extends StatelessWidget {
  const _IconGrid({required this.keys, required this.value, required this.tint, required this.onChanged});

  final List<String> keys;
  final String value;
  final Color tint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = GhTheme.of(context);
    final gap = theme.space(1.5);
    final pad = theme.space(2);
    return LayoutBuilder(
      builder: (context, constraints) {
        final inner = constraints.maxWidth - pad * 2;
        final columns = math.max(4, (inner / (theme.space(10) + gap)).floor());
        final cell = (inner - gap * (columns - 1)) / columns;
        return SingleChildScrollView(
          padding: EdgeInsets.all(pad),
          child: Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final key in keys)
                SizedBox(
                  width: cell,
                  height: cell,
                  child: _IconCell(iconKey: key, active: key == value, tint: tint, onPressed: () => onChanged(key)),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _IconCell extends StatelessWidget {
  const _IconCell({required this.iconKey, required this.active, required this.tint, required this.onPressed});

  final String iconKey;
  final bool active;
  final Color tint;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = GhTheme.of(context);
    final radius = BorderRadius.circular(theme.radiusBtn);
    final label = workspaceIconLabel(iconKey);
    return GhTooltip(
      message: label,
      child: GhPressable(
        key: ValueKey('workspace-icon:$iconKey'),
        onPressed: onPressed,
        borderRadius: radius,
        semanticLabel: label,
        checked: active,
        builder: (context, states) {
          final hover = states.active && !active;
          return GhAnimatedBox(
            alignment: Alignment.center,
            color: active
                ? tint.withValues(alpha: 0.16)
                : hover
                ? theme.overlay
                : theme.overlay.withValues(alpha: 0),
            borderRadius: radius,
            border: Border.all(
              color: active
                  ? tint
                  : hover
                  ? theme.accentDim
                  : Colors.transparent,
              width: active ? 2 : 1,
            ),
            child: GhAnimatedIcon(workspaceIcon(iconKey), color: active ? tint : (hover ? theme.ink : theme.muted), size: theme.space(4.5)),
          );
        },
      ),
    );
  }
}

const _rainbow = SweepGradient(
  colors: [
    Color(0xFFFF0000),
    Color(0xFFFFFF00),
    Color(0xFF00FF00),
    Color(0xFF00FFFF),
    Color(0xFF0000FF),
    Color(0xFFFF00FF),
    Color(0xFFFF0000),
  ],
);

class GhWorkspaceColorPicker extends StatelessWidget {
  const GhWorkspaceColorPicker({super.key, required this.value, required this.onChanged, required this.label});

  final String value;
  final ValueChanged<String> onChanged;
  final String label;

  bool get _isPreset => workspaceColorPresets.any((c) => c.toLowerCase() == value.toLowerCase());

  @override
  Widget build(BuildContext context) {
    final theme = GhTheme.of(context);
    final tr = context.tr.common;
    final size = theme.space(8);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.text(size: GhTextSize.xs, weight: GhWeight.medium, color: theme.muted),
        ),
        SizedBox(height: theme.space(2)),
        Semantics(
          label: label,
          container: true,
          child: Wrap(
            spacing: theme.space(2),
            runSpacing: theme.space(2),
            children: [
              for (final preset in workspaceColorPresets)
                _ColorDot(
                  key: ValueKey('workspace-color:$preset'),
                  color: preset,
                  size: size,
                  active: preset.toLowerCase() == value.toLowerCase(),
                  onPressed: () => onChanged(preset),
                ),
              GhColorSwatchPicker(
                value: value,
                onChanged: onChanged,
                presets: workspaceColorPresets,
                label: tr.color_custom,
                trigger: (context, open, toggle) => _CustomDot(value: value, size: size, active: _isPreset ? open : true, onPressed: toggle),
              ),
            ],
          ),
        ),
        SizedBox(height: theme.space(3)),
        Row(
          spacing: theme.space(2),
          children: [
            Text(
              tr.color_selected,
              style: theme.text(size: GhTextSize.x2s, color: theme.muted),
            ),
            Text(
              value.toLowerCase(),
              style: theme.text(size: GhTextSize.xs, mono: true, color: theme.ink),
            ),
          ],
        ),
      ],
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({super.key, required this.color, required this.size, required this.active, required this.onPressed});

  final String color;
  final double size;
  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = GhTheme.of(context);
    final motion = GhMotion.of(context);
    final radius = BorderRadius.circular(999);
    return GhPressable(
      onPressed: onPressed,
      borderRadius: radius,
      semanticLabel: color,
      checked: active,
      builder: (context, states) {
        final hover = states.active && !active;
        return AnimatedScale(
          scale: hover ? 1.1 : 1,
          duration: motion.css(GhDurations.interactive),
          curve: GhCurves.outExpo,
          child: GhAnimatedBox(
            width: size,
            height: size,
            duration: motion.css(GhDurations.interactive),
            alignment: Alignment.center,
            color: colorFromHex(color),
            borderRadius: radius,
            boxShadow: active ? GhShadows.ring(theme.ink.withValues(alpha: 0.8), width: 2, offset: 2, offsetColor: theme.raised) : const [],
            child: active ? GhIcon(GhIcons.check, size: theme.space(3.5), color: Colors.white) : null,
          ),
        );
      },
    );
  }
}

/// The last dot of the colour row: a rainbow that opens the full picker, showing
/// the colour itself once the workspace has one that is not a preset.
class _CustomDot extends StatelessWidget {
  const _CustomDot({required this.value, required this.size, required this.active, required this.onPressed});

  final String value;
  final double size;
  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = GhTheme.of(context);
    final motion = GhMotion.of(context);
    final custom = !workspaceColorPresets.any((c) => c.toLowerCase() == value.toLowerCase());
    return GhPressable(
      key: const ValueKey('workspace-color-custom'),
      onPressed: onPressed,
      borderRadius: BorderRadius.circular(999),
      semanticLabel: context.tr.common.color_custom,
      checked: custom,
      builder: (context, states) {
        final hover = states.active;
        return AnimatedScale(
          scale: hover ? 1.1 : 1,
          duration: motion.css(GhDurations.interactive),
          curve: GhCurves.outExpo,
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: custom ? null : _rainbow,
              color: custom ? colorFromHex(value) : null,
              boxShadow: active ? GhShadows.ring(theme.ink.withValues(alpha: 0.8), width: 2, offset: 2, offsetColor: theme.raised) : const [],
            ),
            child: Container(
              width: size * 0.5,
              height: size * 0.5,
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withValues(alpha: 0.35)),
              child: GhIcon(custom ? GhIcons.check : GhIcons.plus, size: theme.space(3), color: Colors.white),
            ),
          ),
        );
      },
    );
  }
}
