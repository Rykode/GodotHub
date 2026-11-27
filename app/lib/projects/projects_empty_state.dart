import 'package:material_ui/material_ui.dart';

import '../design/design.dart';
import '../ui/core/i18n.dart';

class ProjectsEmptyState extends StatelessWidget {
  const ProjectsEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = GhTheme.of(context);
    final tr = context.tr.common;
    final stageSize = Size(theme.space(44), theme.space(30));
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: theme.rem(28)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: theme.space(2),
            children: [
              SizedBox(
                width: stageSize.width,
                height: stageSize.height,
                child: _Stage(theme: theme, size: stageSize),
              ),
              Text(
                tr.projects_empty_title,
                textAlign: TextAlign.center,
                style: theme.text(size: GhTextSize.x2l, weight: GhWeight.bold, color: theme.ink),
              ),
              Text(
                tr.no_projects_yet,
                textAlign: TextAlign.center,
                style: theme.text(size: GhTextSize.sm, color: theme.muted, lineHeight: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stage extends StatelessWidget {
  const _Stage({required this.theme, required this.size});

  final GhTheme theme;
  final Size size;

  @override
  Widget build(BuildContext context) {
    final ghostSize = theme.space(34);
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        GhIcon(GhIcons.ghost, size: ghostSize, color: Colors.white.withValues(alpha: 0.2), motion: GhIconAnimation.none),
        for (final (i, spec) in const [(0.1, 0.18), (0.9, 0.3), (0.82, 0.8)].indexed)
          _Twinkle(theme: theme, x: spec.$1, y: spec.$2, index: i, size: size),
      ],
    );
  }
}

class _Twinkle extends StatelessWidget {
  const _Twinkle({required this.theme, required this.x, required this.y, required this.index, required this.size});

  final GhTheme theme;
  final double x;
  final double y;
  final int index;
  final Size size;

  @override
  Widget build(BuildContext context) {
    final dot = theme.space(index == 0 ? 2 : 1.5);
    final color = [theme.mint, theme.amber, theme.accentBright][index];
    return Positioned(
      left: size.width * x,
      top: size.height * y,
      child: Container(
        width: dot,
        height: dot,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.75)),
      ),
    );
  }
}
