import '../design/design.dart';
import '../i18n/i18n.dart';
import '../logic/features.dart';
import '../src/rust/api/types.dart';
import '../src/ui_prefs.dart';
import '../state/keyboard_shortcuts.dart';
import '../ui/shell/sidebar.dart';

/// How long a tab's "New" tag shows, counted from the first time the sidebar showed it. The tag also
/// goes away as soon as the tab is opened. To tag a new tab, set `isNew: true` on it and leave the rest to this.
const newTabLifetime = Duration(days: 3);

String newTabFirstSeenKey(String tabId) => 'new_tab_first_seen:$tabId';

/// Whether [tab] still gets its "New" tag. The first call starts its [newTabLifetime] clock.
bool tabIsNew(AppTabDef tab, {UiPrefsStore? prefs, DateTime? now}) {
  if (!tab.isNew) return false;
  final store = prefs ?? UiPrefsStore.instance;
  final at = (now ?? DateTime.now()).millisecondsSinceEpoch;
  try {
    final first = int.tryParse(store.getItem(newTabFirstSeenKey(tab.id)) ?? '');
    if (first == null) {
      store.setItem(newTabFirstSeenKey(tab.id), '$at');
      return true;
    }
    return at - first < newTabLifetime.inMilliseconds;
  } catch (_) {
    return true;
  }
}

class AppTabDef {
  const AppTabDef({required this.id, required this.navKey, required this.icon, this.hidden = false, this.isNew = false, this.group});

  final String id;
  final String navKey;
  final FaIconData icon;
  final bool hidden;
  final bool isNew;
  final String? group;
}

const tabGroupIcons = {'workspace': GhIcons.code, 'resources': GhIcons.layoutGrid, 'explore': GhIcons.eye};

const appTabs = [
  AppTabDef(id: 'dashboard', navKey: 'dashboard', icon: GhIcons.house, hidden: true),
  AppTabDef(id: 'projects', navKey: 'projects', icon: GhIcons.folder, group: 'workspace'),
  AppTabDef(id: 'versions', navKey: 'versions', icon: GhIcons.cloudArrowDown, group: 'workspace'),
  AppTabDef(id: 'templates', navKey: 'templates', icon: GhIcons.rocket, group: 'workspace'),
  AppTabDef(id: 'vault', navKey: 'vault', icon: GhIcons.briefcase, group: 'resources'),
  AppTabDef(id: 'storage', navKey: 'storage_view', icon: GhIcons.hardDrive, group: 'resources'),
  AppTabDef(id: 'asset-store', navKey: 'asset_store', icon: GhIcons.store, group: 'explore'),
  AppTabDef(id: 'news', navKey: 'news', icon: GhIcons.news, group: 'explore'),
  AppTabDef(id: 'settings', navKey: 'settings', icon: GhIcons.gear, hidden: true),
  AppTabDef(id: 'changelog', navKey: 'changelog', icon: GhIcons.bookOpen, hidden: true),
];

AppTabDef? appTabById(String id) {
  for (final tab in appTabs) {
    if (tab.id == id) return tab;
  }
  return null;
}

List<AppTabDef> enabledTabsFor(AppSettings settings) => appTabs.where((tab) => isFeatureEnabled(settings, tab.id)).toList(growable: false);

String resolveTab(String requested, List<AppTabDef> enabled) => enabled.any((tab) => tab.id == requested) ? requested : 'projects';

String tabLabel(AppTabDef tab, [Translations? translations]) => ghTr('nav:${tab.navKey}', translations: translations);

List<GhSidebarTab> sidebarTabsFor(AppSettings settings, {int newsUnread = 0, Translations? translations, UiPrefsStore? prefs, DateTime? now}) {
  final shortcuts = shortcutTabsFor(settings);
  return [
    for (final tab in enabledTabsFor(settings))
      if (!tab.hidden)
        GhSidebarTab(
          id: tab.id,
          label: tabLabel(tab, translations),
          icon: tab.icon,
          isNew: tabIsNew(tab, prefs: prefs, now: now),
          group: tab.group == null
              ? null
              : GhSidebarGroup(
                  id: tab.group!,
                  label: ghTr('nav:group_${tab.group}', translations: translations),
                  icon: tabGroupIcons[tab.group]!,
                ),
          shortcut: shortcuts.contains(tab.id) ? shortcuts.indexOf(tab.id) + 1 : null,
          badge: tab.id == 'news' && newsUnread > 0 ? newsUnread : null,
        ),
  ];
}
