import 'package:flutter/widgets.dart';
import 'package:path_parsing/path_parsing.dart';

import '../motion/motion.dart';
import 'icon_motion.dart';

@immutable
class FaIconData {
  const FaIconData(this.prefix, this.name, this.width, this.height, this.path);

  final String prefix;
  final String name;
  final int width;
  final int height;
  final String path;

  static final Map<String, Path> _cache = {};

  Path get parsed => _cache.putIfAbsent('$prefix:$name', () {
    final proxy = _PathProxy();
    writeSvgPathDataToPath(path, proxy);
    return proxy.path;
  });

  double aspectRatio() => width / height;
}

class _PathProxy extends PathProxy {
  final Path path = Path();

  @override
  void close() => path.close();

  @override
  void cubicTo(double x1, double y1, double x2, double y2, double x3, double y3) => path.cubicTo(x1, y1, x2, y2, x3, y3);

  @override
  void lineTo(double x, double y) => path.lineTo(x, y);

  @override
  void moveTo(double x, double y) => path.moveTo(x, y);
}

class GhIcon extends StatefulWidget {
  const GhIcon(
    this.icon, {
    super.key,
    this.size,
    this.width,
    this.natural = false,
    this.color,
    this.faded = false,
    this.semanticLabel,
    this.motion,
    this.replay,
  });

  final FaIconData icon;
  final double? size;
  final double? width;
  final bool natural;
  final Color? color;
  final bool faded;
  final String? semanticLabel;

  /// The animation played on hover. Defaults to the icon's own signature
  /// motion; pass [GhIconAnimation.none] for a still icon.
  final GhIconAnimation? motion;

  /// Plays the animation again whenever this value changes.
  final Object? replay;

  @override
  State<GhIcon> createState() => _GhIconState();
}

class _GhIconState extends State<GhIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);
  bool _hovering = false;
  bool _scopeHovering = false;

  GhIconAnimation get _motion => widget.motion ?? ghIconMotionFor(widget.icon);

  void _play() {
    final motion = _motion;
    if (motion == GhIconAnimation.none || GhMotion.of(context).off) {
      return;
    }
    _controller.duration = Duration(microseconds: (motion.duration.inMicroseconds / GhMotion.of(context).speed).round());
    _controller.forward(from: 0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final now = GhIconPlay.hovering(context);
    if (now && !_scopeHovering) {
      _play();
    }
    _scopeHovering = now;
  }

  @override
  void didUpdateWidget(GhIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.replay != oldWidget.replay) {
      _play();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final icon = widget.icon;
    final iconTheme = IconTheme.of(context);
    final height = widget.size ?? iconTheme.size ?? DefaultTextStyle.of(context).style.fontSize ?? 14;
    final paintColor = widget.color ?? iconTheme.color ?? DefaultTextStyle.of(context).style.color ?? const Color(0xFF000000);
    Widget result = SizedBox(
      width: widget.width ?? (widget.natural ? height * icon.aspectRatio() : height),
      height: height,
      child: CustomPaint(painter: _FaIconPainter(icon, paintColor, _motion, _controller)),
    );
    if (_motion != GhIconAnimation.none) {
      result = MouseRegion(
        opaque: false,
        onEnter: (_) {
          if (!_hovering) {
            _hovering = true;
            if (!_scopeHovering) {
              _play();
            }
          }
        },
        onExit: (_) => _hovering = false,
        child: result,
      );
    }
    final faded = widget.faded;
    final semanticLabel = widget.semanticLabel;
    if (faded) {
      result = Opacity(opacity: 0.45, child: result);
    }
    return Semantics(
      label: semanticLabel,
      excludeSemantics: true,
      child: semanticLabel == null ? ExcludeSemantics(child: result) : result,
    );
  }
}

class _FaIconPainter extends CustomPainter {
  _FaIconPainter(this.icon, this.color, this.motion, this.animation) : super(repaint: animation);

  final FaIconData icon;
  final Color color;
  final GhIconAnimation? motion;
  final Animation<double>? animation;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / icon.width < size.height / icon.height ? size.width / icon.width : size.height / icon.height;
    canvas.save();
    final t = animation?.value ?? 0;
    if (motion != null && t > 0 && t < 1) {
      final pose = motion!.pose(t);
      canvas.translate(size.width / 2 + pose.dx * size.width, size.height / 2 + pose.dy * size.height);
      canvas.rotate(pose.rotation);
      canvas.scale(pose.scaleX, pose.scaleY);
      canvas.translate(-size.width / 2, -size.height / 2);
    }
    canvas.translate((size.width - icon.width * scale) / 2, (size.height - icon.height * scale) / 2);
    canvas.scale(scale);
    canvas.drawPath(
      icon.parsed,
      Paint()
        ..color = color
        ..isAntiAlias = true,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FaIconPainter oldDelegate) =>
      oldDelegate.icon != icon || oldDelegate.color != color || oldDelegate.motion != motion || oldDelegate.animation != animation;
}
