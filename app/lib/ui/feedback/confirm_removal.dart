import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../logic/settings_copy.dart';
import '../../state/settings.dart';
import 'confirm_dialog.dart';

/// A destructive confirmation that can be skipped on its own. [id] is what
/// `skippedConfirmations` stores, so it must never change; [labelKey] is the
/// settings string that names it.
enum RemovalConfirm {
  projectRemove('project_remove', 'confirm_project_remove'),
  projectDelete('project_delete', 'confirm_project_delete'),
  projectBulkRemove('project_bulk_remove', 'confirm_project_bulk_remove'),
  projectBulkDelete('project_bulk_delete', 'confirm_project_bulk_delete'),
  versionUninstall('version_uninstall', 'confirm_version_uninstall'),
  exportTemplatesRemove('export_templates_remove', 'confirm_export_templates_remove'),
  exportTemplatesOrphanDelete('export_templates_orphan_delete', 'confirm_export_templates_orphan_delete');

  const RemovalConfirm(this.id, this.labelKey);

  final String id;
  final String labelKey;

  static RemovalConfirm? byId(String id) {
    for (final kind in values) {
      if (kind.id == id) return kind;
    }
    return null;
  }
}

/// Confirms a remove, delete or uninstall of a project or version.
///
/// The dialog carries a "Don't ask again" checkbox. Confirming with it ticked
/// adds only [kind] to `skippedConfirmations`; every other confirmation still
/// asks. While [kind] is skipped this resolves to true without showing
/// anything. Settings > Advanced lists the skipped ones so they can be turned
/// back on.
Future<bool> confirmRemoval(
  BuildContext context,
  RemovalConfirm kind, {
  required String title,
  String? description,
  required String confirmLabel,
  GhConfirmVariant variant = GhConfirmVariant.normal,
}) async {
  final container = ProviderScope.containerOf(context);
  final settings = container.read(settingsProvider).value;
  if (settings != null && settings.skippedConfirmations.contains(kind.id)) return true;
  var dontAskAgain = false;
  final ok = await showGhConfirmDialog(
    context,
    title: title,
    description: description,
    confirmLabel: confirmLabel,
    variant: variant,
    onDontAskAgainChanged: (value) => dontAskAgain = value,
  );
  if (ok && dontAskAgain && settings != null) {
    final latest = container.read(settingsProvider).value ?? settings;
    if (!latest.skippedConfirmations.contains(kind.id)) {
      container
          .read(settingsProvider.notifier)
          .save(copySettings(latest, skippedConfirmations: [...latest.skippedConfirmations, kind.id]))
          .ignore();
    }
  }
  return ok;
}
