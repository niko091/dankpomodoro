# Dank Pomodoro Timer++

A Pomodoro and stopwatch widget for Dux Modular Shell (DMS), with configurable
work/break profiles, daily work history, streaks and a statistics dashboard.

Requires **DMS 2.1 or newer**. The plugin uses the shared `qs.DCommon.Widgets`
components and the bar/dock host's icon and text sizes.

## Install or update

Build the plugin archive with Node.js 22.18+ and npm:

```sh
npm ci
npm run package
```

Install the archive into the plugin directory used by your DMS installation:

```sh
mkdir -p ~/.config/dms/plugins/DankPomodoroTimerPlusPlus
tar -xzf dist/DankPomodoroTimerPlusPlus.tar.gz \
  -C ~/.config/dms/plugins/DankPomodoroTimerPlusPlus
```

Older installations may use `~/.config/DankMaterialShell/plugins` instead.
When updating, extract into the existing plugin directory.

In DMS Settings → Plugins, scan for plugins and enable **Dank Pomodoro Timer++**.
Add it to a bar or dock through the host's widget settings.

Reload an installed plugin after updating its files:

```sh
dms ipc call plugins reload dankPomodoroTimerPlusPlus
dms ipc call plugins status dankPomodoroTimerPlusPlus
```

If an update adds QML or JavaScript files to an already loaded directory, use
`dms restart` once so Qt refreshes its cached directory listing.

## Use

- Choose a timer profile or the stopwatch from the popout's selector.
- Pause suspends the timer. **Record session** saves whole work minutes and
  prepares a new timer; completed work sessions save automatically.
- Reset discards unsaved work. Breaks do not count toward work statistics.
- Configure the daily goal and minimum recorded minutes per day for a streak.
  The streak minimum defaults to one minute and applies to the saved history.
- Open the dashboard for work totals, weekly comparisons and day/week/month/year
  charts. The comparison is against the preceding calendar week. A missing
  nonzero baseline displays “—”; two empty weeks display 0%.

Settings are stored through the DMS settings API. Work history, recorded-session
statistics and the selected profile use the separate plugin state API. On
current DMS, state is stored at
`~/.local/state/dms/plugins/dankPomodoroTimerPlusPlus_state.json`.
The plugin ID stays stable so existing settings and history remain associated
with the same plugin.

The manifest declares `settings_read`, `settings_write` and `process` permissions.
The process permission supports completion notifications through `dms notify`.

## Development

Follow the [official DMS plugin development guide](https://duxlabs.dev/docs/dms/plugin-development).
For live development, use a symlink in your active DMS plugin directory instead
of an extracted copy, then reload the plugin after changes. Do not replace an
existing installed directory with a symlink without first moving that copy.

`src/` contains the TypeScript timer and statistics logic. `npm run build`
generates `Pomodoro.js`, which is committed and loaded directly by QML.
`scripts/package.ts` creates the runtime-only archive in `dist/`.

```sh
npm run check       # TypeScript checks
npm run validate:plugin # Manifest, runtime dependencies and entry points
npm test            # Timer, statistics and translation tests
npm run test:qml    # Qt Quick interaction tests
npm run lint:qml    # QML syntax/format parsing
npm run package     # Build the distributable archive
npm run verify:package # Verify the archive matches the current sources
```

The QML scripts default to Qt 6 tools under `/usr/lib/qt6/bin`; set `QT_BIN_DIR`
to use another installation. The tests run
offscreen against local DMS/Quickshell substitutes; they do not replace a live
check in DMS. Check horizontal and vertical hosts, multiple instances, opening
the preset selector from a hover popout, and completing work with the bar hidden.

Idle updates stop when the host is hidden. Active timers keep running so work
is recorded and completion notifications arrive while a bar or dock is hidden.

## Continuous integration

[Plugin CI](.github/workflows/ci.yml) runs on every push and pull request, and
can also be started manually from GitHub Actions. It checks the manifest and
documented DMS dependency replacements, TypeScript, timer/statistics/translation
tests, committed JavaScript consistency, QML parsing and offscreen interactions
with Qt 6.8.3. It also builds and verifies the runtime archive and uploads it as
an artifact retained for 14 days. Pull requests from forks need no repository secrets.

These checks cover this plugin repository. The registry's own `generate.py` and
`validate_links.py` checks must still run on the submission in a fork of
`dux-plugin-registry`, where the registry JSON, screenshot URL and compositor
declarations live. Screenshots, live compositor tests, upstream differentiation
and the registry's human-authored submission requirements remain release checks;
a green CI result does not certify them.

## Translations

English strings live in QML. Italian translations ship in `translations/it.json`.
Every `I18n.trFor` call uses the literal `dankPomodoroTimerPlusPlus` ID so DMS's
translation extraction can discover it. Add other locales using the same JSON
structure. The test suite checks coverage and placeholder preservation for Italian.

## License

MIT; see [LICENSE](LICENSE).
