# dev

Everything here is for working on GodotHub. Nothing in this folder ships in
the app or reaches users.

| Folder | What it holds |
|---|---|
| `tool/` | `ci_local.sh` (the CI checks, locally), the i18n checks (`i18n/`), the third-party Rust notices generator (`gen_rust_notices.mjs`), the collation table and date fixture generators, the benchmark (`bench/`), the README screenshot generator (`screenshots/`), the updater lab (`updater_lab.dart`), the update path CI scripts (`update_ci/`) and the Windows update sandbox (`update_sandbox/`) |
| `docs/` | The bridge release runbook and the environment checks |
| `fixtures/` | Data from older GodotHub versions, read by the Rust tests |

Tests stay next to the code they test, where Flutter and Cargo look for them:
`app/test`, `app/integration_test` and the `#[cfg(test)]` modules in the
crates. The user FAQ stays at `docs/migration/FAQ.md` because published
release notes link to it.

Dart tools import the app package, so run them from `app/`:

```bash
cd app
dart run ../dev/tool/i18n/check_keys.dart --check-values
```

Node and shell tools run from the repository root, for example
`bash dev/tool/ci_local.sh` or `node dev/tool/gen_rust_notices.mjs`.

Some committed files came from generators that have since been removed: the
test fixtures in `app/test/fixtures` other than `intl_dates.json` (which
`gen_date_fixtures.ts` still writes) are fixed test data now.

Icons are drawn as stroke-based sources in `dev/icons/source` (style rules in
`icons.yaml`, made with the draw-icons skill) and flattened into
`app/lib/design/icons.g.dart` by `dev/tool/icons/gen_icons.mjs`. To add or
change one, edit its source, then:

```
cd dev/tool/icons
npm install
node gen_icons.mjs --verify
```

Run the skill's `build` first (`node .agents/skills/draw-icons/scripts/icons.js
build` from the repository root) so `dev/icons/*.svg` is current. A new source
gets its `GhIcons` entry added automatically (`foo-bar.svg` becomes
`GhIcons.fooBar`). Each icon's hover animation is set in
`app/lib/design/icon_motion.dart`; icons that are not listed there get a pop.

Brand logos (`GhIcons.github`, `GhIcons.gitlab`) are not drawn by us. They are
the Font Awesome Free brands glyphs (see `app/assets/icons/FontAwesome-LICENSE.txt`),
they have no source in `dev/icons/source`, and the generator leaves them alone.
Add any new brand logo the same way, from an icon library, never as a drawing.
