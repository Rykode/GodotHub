import 'package:flutter_test/flutter_test.dart';
import 'package:godothub/design/design.dart';
import 'package:godothub/shell/tabs.dart';
import 'package:godothub/src/ui_prefs.dart';

void main() {
  const fresh = AppTabDef(id: 'fresh', navKey: 'fresh', icon: GhIcons.star, isNew: true);
  const old = AppTabDef(id: 'old', navKey: 'old', icon: GhIcons.star);

  test('no tab is tagged New right now', () {
    expect(appTabs.where((t) => t.isNew), isEmpty);
  });

  test('a New tag lasts three days from the first time it is shown, then expires', () {
    final prefs = UiPrefsStore(MemoryUiPrefsBackend());
    final start = DateTime(2026, 12, 1, 9);
    expect(tabIsNew(fresh, prefs: prefs, now: start), isTrue);
    expect(tabIsNew(fresh, prefs: prefs, now: start.add(const Duration(days: 2, hours: 23))), isTrue);
    expect(tabIsNew(fresh, prefs: prefs, now: start.add(const Duration(days: 3, minutes: 1))), isFalse);
    expect(tabIsNew(fresh, prefs: prefs, now: start.add(const Duration(days: 30))), isFalse);
  });

  test('the clock starts at the first show, not at launch', () {
    final prefs = UiPrefsStore(MemoryUiPrefsBackend());
    expect(prefs.getItem(newTabFirstSeenKey('fresh')), isNull);
    tabIsNew(fresh, prefs: prefs, now: DateTime(2026, 12, 5));
    expect(prefs.getItem(newTabFirstSeenKey('fresh')), isNotNull);
  });

  test('a tab without the flag is never New and records nothing', () {
    final prefs = UiPrefsStore(MemoryUiPrefsBackend());
    expect(tabIsNew(old, prefs: prefs, now: DateTime(2026, 12, 1)), isFalse);
    expect(prefs.getItem(newTabFirstSeenKey('old')), isNull);
  });
}
