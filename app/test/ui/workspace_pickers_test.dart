import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godothub/design/design.dart';
import 'package:godothub/ui/core/i18n.dart';
import 'package:godothub/ui/core/interaction.dart';
import 'package:godothub/ui/shell/workspace_pickers.dart';

import 'i18n_setup.dart';

Widget _host(Widget child) => MaterialApp(
  theme: GhTheme.defaults().toThemeData(),
  home: Scaffold(
    body: SingleChildScrollView(child: SizedBox(width: 460, child: child)),
  ),
);

void main() {
  setUp(setUpTestI18n);

  group('workspace icon set', () {
    test('every key has an icon and sits in exactly one category', () {
      final seen = <String>[];
      for (final keys in workspaceIconCategories.values) {
        seen.addAll(keys);
      }
      expect(seen.toSet().length, seen.length, reason: 'a key is listed in two categories');
      expect(seen.toSet(), workspaceIconKeys.toSet());
      expect(workspaceIconKeys, hasLength(greaterThan(80)));
    });

    test('unknown keys fall back to the briefcase', () {
      expect(workspaceIcon('no_such_icon'), GhIcons.briefcase);
    });

    test('the original keys keep their place', () {
      expect(workspaceIconKeys.take(4), ['briefcase', 'house', 'user', 'code']);
    });

    test('search matches words in any order and respects the category', () {
      expect(ghFilterWorkspaceIcons('', 'all'), workspaceIconKeys);
      expect(ghFilterWorkspaceIcons('map pin', 'all'), ['map_pin']);
      expect(ghFilterWorkspaceIcons('pin map', 'all'), ['map_pin']);
      expect(ghFilterWorkspaceIcons('  ROCKET ', 'all'), ['rocket']);
      expect(ghFilterWorkspaceIcons('rocket', 'tech'), isEmpty);
      expect(ghFilterWorkspaceIcons('rocket', 'travel'), ['rocket']);
      expect(ghFilterWorkspaceIcons('', 'nature'), workspaceIconCategories['nature']);
    });
  });

  group('GhWorkspaceIconPicker', () {
    Future<void> pump(WidgetTester tester, {required String value, required ValueChanged<String> onChanged}) {
      return tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (context, setState) => GhWorkspaceIconPicker(
              label: 'Icon',
              value: value,
              tint: const Color(0xFF23A55A),
              onChanged: (next) {
                setState(() => value = next);
                onChanged(next);
              },
            ),
          ),
        ),
      );
    }

    testWidgets('picks an icon from the grid', (tester) async {
      String? picked;
      await pump(tester, value: 'briefcase', onChanged: (v) => picked = v);
      await tester.tap(find.byKey(const ValueKey('workspace-icon:rocket')));
      await tester.pump();
      expect(picked, 'rocket');
    });

    testWidgets('a category chip narrows the grid and search narrows it further', (tester) async {
      await pump(tester, value: 'briefcase', onChanged: (_) {});
      expect(find.byKey(const ValueKey('workspace-icon:rocket')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('workspace-icon-category:tech')));
      await tester.pump();
      expect(find.byKey(const ValueKey('workspace-icon:rocket')), findsNothing);
      expect(find.byKey(const ValueKey('workspace-icon:code')), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'zzzz');
      await tester.pump();
      expect(find.text(t.common.icon_no_results), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'code');
      await tester.pump();
      expect(find.byKey(const ValueKey('workspace-icon:code')), findsOneWidget);
      expect(find.text(t.common.icon_no_results), findsNothing);
    });
  });

  group('GhWorkspaceColorPicker', () {
    testWidgets('picks a preset', (tester) async {
      String? picked;
      await tester.pumpWidget(_host(GhWorkspaceColorPicker(label: 'Color', value: '#457ff2', onChanged: (v) => picked = v)));
      await tester.tap(find.byKey(const ValueKey('workspace-color:#eb459e')));
      await tester.pump();
      expect(picked, '#eb459e');
    });

    testWidgets('a custom colour opens the full picker and takes a hex value', (tester) async {
      String? picked;
      await tester.pumpWidget(_host(GhWorkspaceColorPicker(label: 'Color', value: '#457ff2', onChanged: (v) => picked = v)));
      await tester.tap(find.byKey(const ValueKey('workspace-color-custom')));
      await tester.pumpAndSettle();
      final hex = find.widgetWithText(TextField, '#457ff2');
      expect(hex, findsOneWidget);
      await tester.enterText(hex, '#12ab34');
      await tester.pump();
      expect(picked, '#12ab34');
    });

    testWidgets('shows a colour that is not a preset on the custom dot and in the readout', (tester) async {
      await tester.pumpWidget(_host(GhWorkspaceColorPicker(label: 'Color', value: '#12AB34', onChanged: (_) {})));
      expect(find.text('#12ab34'), findsOneWidget);
      final custom = tester.widget<GhPressable>(find.byKey(const ValueKey('workspace-color-custom')));
      expect(custom.checked, isTrue);
    });
  });
}
