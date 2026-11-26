import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'fa_icon_data.dart';

/// Where an icon is while its signature animation plays. Offsets are fractions
/// of the icon's size, the rotation is in radians, everything pivots on the
/// icon's centre.
@immutable
class GhIconPose {
  const GhIconPose({this.dx = 0, this.dy = 0, this.rotation = 0, this.scaleX = 1, this.scaleY = 1});

  static const rest = GhIconPose();

  final double dx;
  final double dy;
  final double rotation;
  final double scaleX;
  final double scaleY;

  bool get isRest => dx == 0 && dy == 0 && rotation == 0 && scaleX == 1 && scaleY == 1;
}

/// The one short animation each icon plays when it is hovered, or when its
/// owner asks for a replay. [duration] is the length at normal speed.
enum GhIconAnimation {
  none(Duration.zero),
  pop(Duration(milliseconds: 360)),
  beat(Duration(milliseconds: 520)),
  spin(Duration(milliseconds: 620)),
  turnQuarter(Duration(milliseconds: 420)),
  turnEighth(Duration(milliseconds: 420)),
  ring(Duration(milliseconds: 620)),
  wiggle(Duration(milliseconds: 480)),
  hop(Duration(milliseconds: 420)),
  blink(Duration(milliseconds: 380)),
  tilt(Duration(milliseconds: 420)),
  nudgeUp(Duration(milliseconds: 380)),
  nudgeDown(Duration(milliseconds: 380)),
  nudgeLeft(Duration(milliseconds: 380)),
  nudgeRight(Duration(milliseconds: 380)),
  launch(Duration(milliseconds: 520));

  const GhIconAnimation(this.duration);

  final Duration duration;

  /// [t] runs 0 to 1. Every motion starts and ends at rest.
  GhIconPose pose(double t) {
    final wave = math.sin(t * math.pi);
    final decay = math.pow(1 - t, 1.6).toDouble();
    switch (this) {
      case GhIconAnimation.none:
        return GhIconPose.rest;
      case GhIconAnimation.pop:
        final s = 1 + 0.22 * wave;
        return GhIconPose(scaleX: s, scaleY: s);
      case GhIconAnimation.beat:
        final s = 1 + 0.18 * math.sin(t * math.pi * 2).abs() * (1 - t * 0.4);
        return GhIconPose(scaleX: s, scaleY: s);
      case GhIconAnimation.spin:
        return GhIconPose(rotation: Curves.easeInOutCubic.transform(t) * math.pi * 2);
      case GhIconAnimation.turnQuarter:
        return GhIconPose(rotation: Curves.easeInOutCubic.transform(t) * math.pi / 2);
      case GhIconAnimation.turnEighth:
        return GhIconPose(rotation: Curves.easeInOutCubic.transform(t) * math.pi / 4);
      case GhIconAnimation.ring:
        return GhIconPose(rotation: math.sin(t * math.pi * 5) * 0.34 * decay);
      case GhIconAnimation.wiggle:
        return GhIconPose(rotation: math.sin(t * math.pi * 4) * 0.2 * decay, dx: math.sin(t * math.pi * 4) * 0.04 * decay);
      case GhIconAnimation.hop:
        return GhIconPose(dy: -0.18 * wave);
      case GhIconAnimation.blink:
        return GhIconPose(scaleY: 1 - 0.8 * math.pow(wave, 2).toDouble());
      case GhIconAnimation.tilt:
        return GhIconPose(rotation: -0.5 * wave);
      case GhIconAnimation.nudgeUp:
        return GhIconPose(dy: -0.2 * wave);
      case GhIconAnimation.nudgeDown:
        return GhIconPose(dy: 0.2 * wave);
      case GhIconAnimation.nudgeLeft:
        return GhIconPose(dx: -0.2 * wave);
      case GhIconAnimation.nudgeRight:
        return GhIconPose(dx: 0.2 * wave);
      case GhIconAnimation.launch:
        final out = Curves.easeIn.transform(t);
        // fly off towards the top right and drop back in from the bottom left
        if (t < 0.5) {
          final k = out * 2;
          return GhIconPose(dx: 0.7 * k, dy: -0.7 * k);
        }
        final k = (1 - t) * 2;
        return GhIconPose(dx: -0.7 * k, dy: 0.7 * k);
    }
  }
}

/// Every icon has its own motion, picked for what it shows. An icon that is
/// not listed gets a small pop.
GhIconAnimation ghIconMotionFor(FaIconData icon) => _motions[icon.name] ?? GhIconAnimation.pop;

const _motions = <String, GhIconAnimation>{
  'check': GhIconAnimation.pop,
  'check-circle': GhIconAnimation.pop,
  'circle-check': GhIconAnimation.pop,
  'circle-x': GhIconAnimation.wiggle,
  'x': GhIconAnimation.turnQuarter,
  'plus': GhIconAnimation.turnQuarter,
  'minus': GhIconAnimation.pop,
  'chevron-up': GhIconAnimation.nudgeUp,
  'chevron-down': GhIconAnimation.nudgeDown,
  'chevron-left': GhIconAnimation.nudgeLeft,
  'chevron-right': GhIconAnimation.nudgeRight,
  'chevrons-left': GhIconAnimation.nudgeLeft,
  'arrow-up': GhIconAnimation.nudgeUp,
  'arrow-up-down': GhIconAnimation.wiggle,
  'external-link': GhIconAnimation.launch,
  'refresh': GhIconAnimation.spin,
  'spinner': GhIconAnimation.spin,
  'more': GhIconAnimation.wiggle,
  'grip': GhIconAnimation.wiggle,
  'search': GhIconAnimation.tilt,
  'filter': GhIconAnimation.pop,
  'download': GhIconAnimation.nudgeDown,
  'cloud-arrow-down': GhIconAnimation.nudgeDown,
  'import': GhIconAnimation.nudgeRight,
  'play': GhIconAnimation.nudgeRight,
  'pause': GhIconAnimation.pop,
  'gear': GhIconAnimation.turnEighth,
  'sun': GhIconAnimation.turnEighth,
  'moon': GhIconAnimation.tilt,
  'clock': GhIconAnimation.spin,
  'history': GhIconAnimation.spin,
  'stopwatch': GhIconAnimation.wiggle,
  'bell': GhIconAnimation.ring,
  'bug': GhIconAnimation.wiggle,
  'bomb': GhIconAnimation.wiggle,
  'heart': GhIconAnimation.beat,
  'star': GhIconAnimation.spin,
  'info': GhIconAnimation.pop,
  'alert-triangle': GhIconAnimation.wiggle,
  'lock': GhIconAnimation.hop,
  'eye': GhIconAnimation.blink,
  'eye-slash': GhIconAnimation.blink,
  'pin': GhIconAnimation.tilt,
  'rocket': GhIconAnimation.launch,
  'folder': GhIconAnimation.hop,
  'folder-plus': GhIconAnimation.hop,
  'house': GhIconAnimation.hop,
  'store': GhIconAnimation.hop,
  'briefcase': GhIconAnimation.hop,
  'trash': GhIconAnimation.wiggle,
  'pencil': GhIconAnimation.tilt,
  'plug': GhIconAnimation.nudgeRight,
  'wifi-off': GhIconAnimation.wiggle,
  'dumbbell': GhIconAnimation.wiggle,
  'gamepad': GhIconAnimation.wiggle,
  'flask': GhIconAnimation.tilt,
  'graduation-cap': GhIconAnimation.hop,
  'language': GhIconAnimation.spin,
  'palette': GhIconAnimation.tilt,
  'book': GhIconAnimation.pop,
  'book-open': GhIconAnimation.pop,
};

/// Wrap a button, card or row in this to play the signature motion of every
/// [GhIcon] inside it while the pointer is over the whole thing, not only over
/// the icon itself.
class GhIconPlay extends StatefulWidget {
  const GhIconPlay({super.key, this.enabled = true, required this.child});

  /// A disabled button keeps its icons still.
  final bool enabled;

  final Widget child;

  static bool hovering(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_Hover>()?.hovering ?? false;

  @override
  State<GhIconPlay> createState() => _GhIconPlayState();
}

class _GhIconPlayState extends State<GhIconPlay> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    opaque: false,
    onEnter: (_) => setState(() => _hovering = true),
    onExit: (_) => setState(() => _hovering = false),
    child: _Hover(hovering: _hovering && widget.enabled, child: widget.child),
  );
}

class _Hover extends InheritedWidget {
  const _Hover({required this.hovering, required super.child});

  final bool hovering;

  @override
  bool updateShouldNotify(_Hover oldWidget) => oldWidget.hovering != hovering;
}
