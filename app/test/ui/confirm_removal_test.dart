import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godothub/design/design.dart';
import 'package:godothub/logic/settings_copy.dart';
import 'package:godothub/ui/controls/checkbox.dart';
import 'package:godothub/ui/feedback/confirm_removal.dart';
import 'package:godothub/settings/categories/skipped_confirmations_setting.dart';
import 'package:godothub/ui/core/interaction.dart';
import 'package:godothub/i18n/i18n.dart';
import 'package:godothub/state/settings.dart';
import 'package:material_ui/material_ui.dart';

import '../support/settings_fakes.dart';
import '../titlebar_test.dart' show baseSettings;
import 'i18n_setup.dart';

Future<(BuildContext, ProviderContainer)> _pump(WidgetTester tester, List<String> skipped) async {
  late BuildContext host;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [fakeSettings(() => copySettings(baseSettings, setupComplete: true, skippedConfirmations: skipped))],
      child: MaterialApp(
        theme: GhTheme.defaults().toThemeData(),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              host = context;
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final container = ProviderScope.containerOf(host);
  await container.read(settingsProvider.future);
  return (host, container);
}

Future<bool> _ask(BuildContext host, RemovalConfirm kind) =>
    confirmRemoval(host, kind, title: 'Title', description: 'Sure?', confirmLabel: 'Do it');

void main() {
  setUp(setUpTestI18n);
  _settingsTests();

  testWidgets('"Don\'t ask again" skips only the confirmation it was ticked on', (tester) async {
    final (host, container) = await _pump(tester, []);
    await tester.pumpAndSettle();
    bool? result;
    _ask(host, RemovalConfirm.projectRemove).then((v) => result = v);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(GhCheckbox));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Do it'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
    expect(container.read(settingsProvider).value!.skippedConfirmations, ['project_remove']);

    var skippedResult = false;
    _ask(host, RemovalConfirm.projectRemove).then((v) => skippedResult = v);
    await tester.pump();
    expect(find.text('Do it'), findsNothing);
    await tester.pumpAndSettle();
    expect(skippedResult, isTrue);

    _ask(host, RemovalConfirm.projectDelete);
    await tester.pumpAndSettle();
    expect(find.text('Do it'), findsOneWidget);
  });

  testWidgets('cancelling with the box ticked skips nothing', (tester) async {
    final (host, container) = await _pump(tester, []);
    bool? result;
    _ask(host, RemovalConfirm.versionUninstall).then((v) => result = v);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(GhCheckbox));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.common.cancel));
    await tester.pumpAndSettle();
    expect(result, isFalse);
    expect(container.read(settingsProvider).value!.skippedConfirmations, isEmpty);
  });
}

void _settingsTests() {
  testWidgets('settings lists skipped confirmations and removing one asks again', (tester) async {
    final saved = <List<String>>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fakeSettings(
            () => copySettings(baseSettings, setupComplete: true, skippedConfirmations: ['project_remove', 'version_uninstall']),
            onSave: (next) {
              saved.add(next.skippedConfirmations);
              return next;
            },
          ),
        ],
        child: MaterialApp(
          theme: GhTheme.defaults().toThemeData(),
          home: const Scaffold(body: SingleChildScrollView(child: SkippedConfirmationsSetting())),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('skipped:project_remove')), findsOneWidget);
    expect(find.byKey(const ValueKey('skipped:version_uninstall')), findsOneWidget);
    expect(find.byKey(const ValueKey('skipped:project_delete')), findsNothing);

    await tester.tap(find.descendant(of: find.byKey(const ValueKey('skipped:project_remove')), matching: find.byType(GhPressable)));
    await tester.pumpAndSettle();
    expect(saved.last, ['version_uninstall']);
    expect(find.byKey(const ValueKey('skipped:project_remove')), findsNothing);
  });
}
