import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godothub/logic/settings_copy.dart';
import 'package:godothub/state/settings.dart';
import 'package:godothub/state/update_available.dart';

import '../support/settings_fakes.dart';
import '../titlebar_test.dart' show baseSettings;

void main() {
  ProviderContainer container(UpdateChecker checker) {
    final c = ProviderContainer(
      overrides: [updateCheckerProvider.overrideWithValue(checker), fakeSettings(() => baseSettings)],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('checks once on first read and flags an available update', () async {
    var calls = 0;
    final c = container(() async {
      calls++;
      return true;
    });
    expect(c.read(updateAvailableProvider).updateAvailable, isFalse);
    await pumpEventQueue();
    expect(c.read(updateAvailableProvider).updateAvailable, isTrue);
    expect(calls, 1);

    c.read(updateAvailableProvider.notifier).dismissUpdate();
    expect(c.read(updateAvailableProvider).updateAvailable, isFalse);
  });

  test('a failed check leaves the flag off and preview toggles independently', () async {
    final c = container(() async => throw StateError('offline'));
    c.read(updateAvailableProvider);
    await pumpEventQueue();
    expect(c.read(updateAvailableProvider).updateAvailable, isFalse);

    c.read(updateAvailableProvider.notifier).setPreviewUpdate(true);
    expect(c.read(updateAvailableProvider).previewUpdate, isTrue);
    c.read(updateAvailableProvider.notifier).togglePreviewUpdate();
    expect(c.read(updateAvailableProvider).previewUpdate, isFalse);
  });

  test('a downloaded update keeps its restart action', () async {
    final c = container(() async => false);
    c.read(updateAvailableProvider);
    await pumpEventQueue();
    expect(c.read(updateAvailableProvider).downloaded, isFalse);

    var applied = 0;
    c.read(updateAvailableProvider.notifier).markDownloaded(() async => applied++);
    final state = c.read(updateAvailableProvider);
    expect(state.updateAvailable, isTrue);
    expect(state.downloaded, isTrue);
    await state.applyDownloaded!();
    expect(applied, 1);

    c.read(updateAvailableProvider.notifier).setPreviewUpdate(true);
    expect(c.read(updateAvailableProvider).downloaded, isTrue);
  });

  test('the default checker reports no update', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(updateAvailableProvider);
    await pumpEventQueue();
    expect(c.read(updateAvailableProvider), const UpdateAvailableState());
  });

  group('the startup check setting', () {
    ProviderContainer withSetting(bool on, UpdateChecker checker) {
      final c = ProviderContainer(
        overrides: [
          updateCheckerProvider.overrideWithValue(checker),
          fakeSettings(() => copySettings(baseSettings, checkUpdatesOnStartup: on)),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('off: nothing is asked at startup, and turning it on checks right away', () async {
      var calls = 0;
      final c = withSetting(false, () async {
        calls++;
        return true;
      });
      c.read(updateAvailableProvider);
      await pumpEventQueue();
      expect(calls, 0);
      expect(c.read(updateAvailableProvider).updateAvailable, isFalse);

      await c.read(settingsProvider.notifier).save(copySettings(baseSettings, checkUpdatesOnStartup: true));
      await pumpEventQueue();
      expect(calls, 1);
      expect(c.read(updateAvailableProvider).updateAvailable, isTrue);
    });

    test('on: the check runs at startup', () async {
      var calls = 0;
      final c = withSetting(true, () async {
        calls++;
        return false;
      });
      c.read(updateAvailableProvider);
      await pumpEventQueue();
      expect(calls, 1);
    });
  });
}
