import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godothub/design/design.dart';
import 'package:godothub/motion/motion.dart';
import 'package:godothub/ui/core/interaction.dart';
import 'package:material_ui/material_ui.dart';

Widget _host(Widget child, {GhMotionPrefs prefs = const GhMotionPrefs(), bool osReduced = false}) {
  return MaterialApp(
    theme: GhTheme.defaults().toThemeData(),
    home: GhMotion(
      prefs: prefs,
      osReduced: osReduced,
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

Future<void> _hover(WidgetTester tester, Finder target) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: const Offset(1, 1));
  addTearDown(mouse.removePointer);
  await mouse.moveTo(tester.getCenter(target));
  await tester.pump();
}

void main() {
  group('icon motion poses', () {
    test('every motion starts and ends at rest', () {
      // a whole turn looks the same as no turn
      // the quarter and eighth turns only suit icons that look the same after one (x, plus, gear, sun)
      const turn = {GhIconAnimation.turnQuarter: 3.141592653589793 / 2, GhIconAnimation.turnEighth: 3.141592653589793 / 4};
      bool atRest(GhIconAnimation motion, GhIconPose p) {
        final step = turn[motion] ?? 2 * 3.141592653589793;
        final turns = p.rotation / step;
        return p.dx.abs() < 1e-9 && p.dy.abs() < 1e-9 && p.scaleX == 1 && p.scaleY == 1 && (turns - turns.round()).abs() < 1e-9;
      }
      for (final motion in GhIconAnimation.values) {
        expect(atRest(motion, motion.pose(0)), isTrue, reason: '$motion at 0');
        expect(atRest(motion, motion.pose(1)), isTrue, reason: '$motion at 1');
      }
    });

    test('every icon in the set has a motion entry that points at a real icon or falls back to pop', () {
      expect(ghIconMotionFor(GhIcons.bell), GhIconAnimation.ring);
      expect(ghIconMotionFor(GhIcons.gear), GhIconAnimation.turnEighth);
      expect(ghIconMotionFor(GhIcons.square), GhIconAnimation.pop);
    });
  });

  group('GhIcon hover', () {
    testWidgets('the first hover on the icon itself animates', (tester) async {
      await tester.pumpWidget(_host(const GhIcon(GhIcons.bell, size: 24)));
      expect(tester.hasRunningAnimations, isFalse);
      await _hover(tester, find.byType(GhIcon));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpAndSettle();
    });

    testWidgets('a still icon does not animate', (tester) async {
      await tester.pumpWidget(_host(const GhIcon(GhIcons.bell, size: 24, motion: GhIconAnimation.none)));
      await _hover(tester, find.byType(GhIcon));
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('motion off in the settings keeps the icon still', (tester) async {
      await tester.pumpWidget(
        _host(const GhIcon(GhIcons.bell, size: 24), prefs: const GhMotionPrefs(intensity: GhMotionIntensity.none)),
      );
      await _hover(tester, find.byType(GhIcon));
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('the OS reduced-motion flag keeps the icon still', (tester) async {
      await tester.pumpWidget(_host(const GhIcon(GhIcons.bell, size: 24), osReduced: true));
      await _hover(tester, find.byType(GhIcon));
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('replay plays the motion again when the value changes', (tester) async {
      await tester.pumpWidget(_host(const GhIcon(GhIcons.bell, size: 24, replay: 0)));
      await tester.pumpWidget(_host(const GhIcon(GhIcons.bell, size: 24, replay: 1)));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpAndSettle();
    });
  });

  group('GhIconPlay', () {
    testWidgets('hovering the surrounding widget, not the icon, plays the icon', (tester) async {
      await tester.pumpWidget(
        _host(
          const GhIconPlay(
            child: SizedBox(
              key: ValueKey('surface'),
              width: 200,
              height: 80,
              child: Align(alignment: Alignment.topLeft, child: GhIcon(GhIcons.bell, size: 16)),
            ),
          ),
        ),
      );
      final surface = find.byKey(const ValueKey('surface'));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(1, 1));
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getBottomRight(surface) - const Offset(4, 4));
      await tester.pump();
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpAndSettle();
    });

    testWidgets('a disabled scope keeps icons still', (tester) async {
      await tester.pumpWidget(
        _host(
          const GhIconPlay(
            enabled: false,
            child: SizedBox(
              key: ValueKey('surface'),
              width: 200,
              height: 80,
              child: Align(alignment: Alignment.topLeft, child: GhIcon(GhIcons.bell, size: 16)),
            ),
          ),
        ),
      );
      final surface = find.byKey(const ValueKey('surface'));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(1, 1));
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getBottomRight(surface) - const Offset(4, 4));
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
    });

    for (final enabled in [true, false]) {
      testWidgets('a ${enabled ? 'enabled' : 'disabled'} GhPressable ${enabled ? 'plays' : 'keeps still'} the icon inside it', (
        tester,
      ) async {
        await tester.pumpWidget(
          _host(
            GhPressable(
              onPressed: enabled ? () {} : null,
              builder: (context, states) => const SizedBox(
                key: ValueKey('surface'),
                width: 200,
                height: 80,
                child: Align(alignment: Alignment.topLeft, child: GhIcon(GhIcons.bell, size: 16)),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: const Offset(1, 1));
        addTearDown(mouse.removePointer);
        // the pointer is over the pressable but nowhere near the 16px icon
        await mouse.moveTo(tester.getBottomRight(find.byKey(const ValueKey('surface'))) - const Offset(4, 4));
        await tester.pump();
        expect(tester.hasRunningAnimations, enabled);
        await tester.pumpAndSettle();
      });
    }
  });
}
