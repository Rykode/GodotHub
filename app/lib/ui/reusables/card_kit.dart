import 'package:material_ui/material_ui.dart';

import '../../design/design.dart';
import '../../motion/motion.dart';
import '../../motion/presence.dart' show ghFadeInFrameBuilder;
import '../core/interaction.dart';
import '../core/tooltip.dart';
import 'state_panel.dart' show GhSkeleton;

enum GhTone { accent, mint, amber, danger, muted }

({Color bg, Color fg, Color border}) ghToneColors(GhTheme theme, GhTone tone) => switch (tone) {
  GhTone.accent => (bg: theme.accent.withValues(alpha: 0.1), fg: theme.accentBright, border: theme.accentDim.withValues(alpha: 0.4)),
  GhTone.mint => (bg: theme.mint.withValues(alpha: 0.1), fg: theme.mint, border: theme.mint.withValues(alpha: 0.25)),
  GhTone.amber => (bg: theme.amber.withValues(alpha: 0.1), fg: theme.amber, border: theme.amber.withValues(alpha: 0.25)),
  GhTone.danger => (bg: theme.danger.withValues(alpha: 0.1), fg: theme.danger, border: theme.danger.withValues(alpha: 0.3)),
  GhTone.muted => (bg: theme.raised, fg: theme.muted, border: theme.outline.withValues(alpha: 0.5)),
};

class GhBadge extends StatelessWidget {
  const GhBadge({
    super.key,
    required this.label,
    this.tone = GhTone.muted,
    this.icon,
    this.mono = false,
    this.tooltip,
    this.maxWidth,
    this.size = GhTextSize.x3s,
  });

  final String label;
  final GhTone tone;
  final FaIconData? icon;
  final bool mono;
  final String? tooltip;
  final double? maxWidth;
  final GhTextSize size;

  @override
  Widget build(BuildContext context) {
    final theme = GhTheme.of(context);
    final colors = ghToneColors(theme, tone);
    Widget badge = DecoratedBox(
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(theme.radiusMd),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: theme.space(2), vertical: theme.space(0.5)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: theme.space(1),
          children: [
            if (icon != null) GhIcon(icon!, size: theme.space(2.5), color: colors.fg),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.text(size: size, weight: mono ? GhWeight.medium : GhWeight.semibold, mono: mono, color: colors.fg),
              ),
            ),
          ],
        ),
      ),
    );
    if (maxWidth != null) {
      badge = ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth!),
        child: badge,
      );
    }
    if (tooltip != null) badge = GhTooltip(message: tooltip!, child: badge);
    return badge;
  }
}

class GhCard extends StatefulWidget {
  const GhCard({
    super.key,
    required this.builder,
    this.onPressed,
    this.selected = false,
    this.semanticLabel,
    this.tooltip,
    this.padding,
    this.tone,
    this.lift = false,
  });

  final Widget Function(BuildContext context, bool highlighted) builder;

  final bool lift;
  final VoidCallback? onPressed;
  final bool selected;
  final String? semanticLabel;
  final String? tooltip;
  final EdgeInsetsGeometry? padding;

  final GhTone? tone;

  @override
  State<GhCard> createState() => _GhCardState();
}

class _GhCardState extends State<GhCard> {
  bool _hovered = false;
  bool _focusWithin = false;

  BoxDecoration _decoration(GhTheme theme, bool highlighted) {
    final toneBorder = widget.tone == null ? null : ghToneColors(theme, widget.tone!).border;
    return BoxDecoration(
      color: widget.selected
          ? Color.alphaBlend(theme.accent.withValues(alpha: 0.05), theme.overlay)
          : (highlighted ? theme.raised : theme.overlay),
      borderRadius: BorderRadius.circular(widget.lift ? theme.radiusCard : theme.radiusItem),
      border: Border.all(
        color: widget.selected
            ? theme.accent
            : highlighted
            ? theme.accentDim.withValues(alpha: 0.6)
            : (toneBorder ?? theme.outline.withValues(alpha: 0.5)),
      ),
    );
  }

  Widget _surface(BuildContext context, GhTheme theme, bool highlighted) {
    final motion = GhMotion.of(context);
    final rise = widget.lift && highlighted && !motion.off ? -3.0 : 0.0;
    return AnimatedContainer(
      duration: motion.css(GhDurations.interactive),
      curve: GhCurves.outExpo,
      transform: Matrix4.translationValues(0, rise, 0),
      clipBehavior: Clip.antiAlias,
      padding: widget.padding,
      decoration: _decoration(theme, highlighted),
      child: widget.builder(context, highlighted),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = GhTheme.of(context);
    if (widget.onPressed != null) {
      // The focus listener also covers nested controls (delete, create), so
      // tabbing into them highlights the card and reveals hover affordances.
      return Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onFocusChange: (value) => setState(() => _focusWithin = value),
        child: GhPressable(
          onPressed: widget.onPressed,
          semanticLabel: widget.semanticLabel,
          tooltip: widget.tooltip,
          selected: widget.selected,
          borderRadius: BorderRadius.circular(widget.lift ? theme.radiusCard : theme.radiusItem),
          pressMotion: false,
          builder: (context, states) => _surface(context, theme, states.highlighted || _focusWithin),
        ),
      );
    }
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onFocusChange: (value) => setState(() => _focusWithin = value),
        child: Semantics(
          container: true,
          explicitChildNodes: true,
          label: widget.semanticLabel,
          child: _surface(context, theme, _hovered || _focusWithin),
        ),
      ),
    );
  }
}

class GhCardMedia extends StatelessWidget {
  const GhCardMedia({
    super.key,
    this.imageUrl,
    required this.fallbackIcon,
    this.height = 24,
    this.overlay = const [],
    this.dim = false,
    this.tile = false,
  });

  final String? imageUrl;
  final FaIconData fallbackIcon;

  final double height;
  final List<Widget> overlay;

  final bool dim;

  final bool tile;

  Widget _image(String url, BoxFit fit) => Image.network(
    url,
    fit: fit,
    excludeFromSemantics: true,
    frameBuilder: ghFadeInFrameBuilder,
    errorBuilder: (context, error, stack) => const SizedBox.shrink(),
  );

  @override
  Widget build(BuildContext context) {
    final theme = GhTheme.of(context);
    final url = imageUrl;
    final hasImage = url != null && url.isNotEmpty;
    if (tile) {
      final box = theme.space(14);
      return SizedBox(
        height: theme.space(height),
        child: ColoredBox(
          color: theme.raised,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasImage) Opacity(opacity: 0.12, child: _image(url, BoxFit.cover)),
              PositionedDirectional(
                start: 0,
                end: 0,
                bottom: 0,
                height: theme.space(height / 2),
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [theme.overlay.withValues(alpha: 0.6), theme.overlay.withValues(alpha: 0)],
                      ),
                    ),
                  ),
                ),
              ),
              Center(
                child: Container(
                  width: box,
                  height: box,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: theme.surface.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(theme.radiusBtn),
                    border: Border.all(color: theme.outline.withValues(alpha: 0.6)),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Center(
                        child: GhIcon(fallbackIcon, size: theme.space(5), color: theme.muted.withValues(alpha: 0.5)),
                      ),
                      if (hasImage) _image(url, BoxFit.cover),
                    ],
                  ),
                ),
              ),
              ...overlay,
            ],
          ),
        ),
      );
    }
    return SizedBox(
      height: theme.space(height),
      child: ColoredBox(
        color: theme.raised,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: GhIcon(fallbackIcon, size: theme.space(6), color: theme.muted.withValues(alpha: 0.35)),
            ),
            if (url != null && url.isNotEmpty)
              Opacity(
                opacity: dim ? 0.85 : 1,
                child: Image.network(
                  url,
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                  frameBuilder: ghFadeInFrameBuilder,
                  errorBuilder: (context, error, stack) => const SizedBox.shrink(),
                ),
              ),
            ...overlay,
          ],
        ),
      ),
    );
  }
}

class GhCardBody extends StatelessWidget {
  const GhCardBody({
    super.key,
    required this.title,
    this.meta = const [],
    this.description,
    this.descriptionLines = 2,
    this.badges = const [],
    this.leading,
    this.trailing,
    this.titleWrapper,
  });

  final String title;
  final List<String> meta;
  final String? description;
  final int descriptionLines;
  final List<Widget> badges;
  final Widget? leading;
  final Widget? trailing;

  final Widget Function(Widget title)? titleWrapper;

  @override
  Widget build(BuildContext context) {
    final theme = GhTheme.of(context);
    final metaStyle = theme.text(size: GhTextSize.x2s, color: theme.muted.withValues(alpha: 0.8));
    final desc = description;
    Widget titleText = Text(
      title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: theme.text(size: GhTextSize.lg, weight: GhWeight.medium, color: theme.ink, lineHeight: 1.375),
    );
    if (titleWrapper != null) titleText = titleWrapper!(titleText);
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(theme.space(4), theme.space(4), theme.space(4), theme.space(3)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: theme.space(1.5),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: theme.space(2.5),
            children: [
              ?leading,
              Expanded(child: titleText),
              ?trailing,
            ],
          ),
          if (meta.isNotEmpty)
            Row(
              spacing: theme.space(1.5),
              children: [
                for (var i = 0; i < meta.length; i++) ...[
                  if (i > 0) ExcludeSemantics(child: Text('·', style: metaStyle)),
                  Flexible(
                    child: Text(meta[i], maxLines: 1, overflow: TextOverflow.ellipsis, style: metaStyle),
                  ),
                ],
              ],
            ),
          if (desc != null && desc.isNotEmpty)
            Text(
              desc,
              maxLines: descriptionLines,
              overflow: TextOverflow.ellipsis,
              style: theme.text(size: GhTextSize.xs, color: theme.muted, lineHeight: 1.625),
            ),
          if (badges.isNotEmpty) ...[
            const Spacer(),
            Padding(
              padding: EdgeInsets.only(top: theme.space(1.5)),
              child: Wrap(spacing: theme.space(1.5), runSpacing: theme.space(1.5), children: badges),
            ),
          ],
        ],
      ),
    );
  }
}

class GhCardSkeleton extends StatelessWidget {
  const GhCardSkeleton({super.key, this.mediaHeight = 24, this.footer = true, this.showcase = false});

  final double? mediaHeight;
  final bool footer;

  final bool showcase;

  @override
  Widget build(BuildContext context) {
    final theme = GhTheme.of(context);
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.overlay,
          borderRadius: BorderRadius.circular(showcase ? theme.radiusCard : theme.radiusItem),
          border: Border.all(color: theme.outline.withValues(alpha: 0.5)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(showcase ? theme.radiusCard : theme.radiusItem),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (mediaHeight != null)
                SizedBox(
                  height: theme.space(mediaHeight!),
                  child: ColoredBox(color: theme.raised),
                ),
              Padding(
                padding: EdgeInsets.all(theme.space(4)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: theme.space(2.5),
                  children: [
                    GhSkeleton(widthFactor: 0.75, height: theme.space(4)),
                    GhSkeleton(widthFactor: 0.45, height: theme.space(2.5)),
                    GhSkeleton(widthFactor: 1, height: theme.space(2.5)),
                    GhSkeleton(widthFactor: 0.8, height: theme.space(2.5)),
                    Row(
                      spacing: theme.space(1.5),
                      children: [
                        GhSkeleton(width: theme.space(14), height: theme.space(4.5), radius: theme.radiusMd),
                        GhSkeleton(width: theme.space(10), height: theme.space(4.5), radius: theme.radiusMd),
                      ],
                    ),
                  ],
                ),
              ),
              if (footer)
                Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(theme.space(4), 0, theme.space(4), theme.space(4)),
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: GhSkeleton(width: theme.space(28), height: theme.space(8), radius: theme.radiusBtn),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class GhCardNotice extends StatelessWidget {
  const GhCardNotice({super.key, required this.message, this.tone = GhTone.mint, this.icon, this.action});

  final String message;
  final GhTone tone;
  final FaIconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = GhTheme.of(context);
    final colors = ghToneColors(theme, tone);
    return Semantics(
      liveRegion: true,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.bg,
          borderRadius: BorderRadius.circular(theme.radiusItem),
          border: Border.all(color: colors.border),
        ),
        child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(theme.space(3.5), theme.space(2), theme.space(action == null ? 3.5 : 2), theme.space(2)),
          child: Row(
            spacing: theme.space(2),
            children: [
              GhIcon(icon ?? (tone == GhTone.danger ? GhIcons.alertTriangle : GhIcons.check), size: theme.space(3.5), color: colors.fg),
              Expanded(
                child: Text(
                  message,
                  style: theme.text(size: GhTextSize.xs, color: colors.fg),
                ),
              ),
              ?action,
            ],
          ),
        ),
      ),
    );
  }
}

class GhCardFooter extends StatelessWidget {
  const GhCardFooter({super.key, this.leading = const [], this.trailing = const [], this.divided = false, this.fill = false});

  final List<Widget> leading;
  final List<Widget> trailing;
  final bool divided;

  final bool fill;

  @override
  Widget build(BuildContext context) {
    final theme = GhTheme.of(context);
    return Container(
      padding: EdgeInsetsDirectional.fromSTEB(theme.space(4), theme.space(divided ? 3 : 1), theme.space(4), theme.space(4)),
      decoration: divided
          ? BoxDecoration(
              border: Border(top: BorderSide(color: theme.outline.withValues(alpha: 0.35))),
            )
          : null,
      child: Row(
        spacing: theme.space(2),
        children: [
          if (!fill || leading.isNotEmpty)
            Expanded(
              child: Wrap(
                spacing: theme.space(1.5),
                runSpacing: theme.space(1.5),
                crossAxisAlignment: WrapCrossAlignment.center,
                children: leading,
              ),
            ),
          if (fill && trailing.isNotEmpty) ...[...trailing.take(trailing.length - 1), Expanded(child: trailing.last)] else ...trailing,
        ],
      ),
    );
  }
}
