import 'package:material_ui/material_ui.dart';

import '../../design/design.dart';

class GhFilterBar extends StatelessWidget {
  const GhFilterBar({super.key, required this.primary, this.secondary = const [], this.trailing});

  final List<Widget> primary;
  final List<Widget> secondary;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = GhTheme.of(context);
    final gap = theme.space(2);
    return Container(
      padding: EdgeInsets.all(theme.space(2)),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(theme.radiusCard),
        border: Border.all(color: theme.outline.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Wrap(
              spacing: gap,
              runSpacing: gap,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ...primary,
                if (secondary.isNotEmpty) ...[
                  Container(width: 1, height: theme.space(6), color: theme.outline.withValues(alpha: 0.5)),
                  ...secondary,
                ],
              ],
            ),
          ),
          if (trailing != null)
            Padding(
              padding: EdgeInsetsDirectional.only(start: theme.space(3), end: theme.space(2)),
              child: trailing,
            ),
        ],
      ),
    );
  }
}
