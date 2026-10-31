# Taka · টাকা

> **Amar taka gelota koi?** — a personal, offline daily expense tracker for hall life.
> No account. No cloud. No subscription. Your taka, your phone, your file.

![Flutter](https://img.shields.io/badge/Flutter-3.47-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.13-0175C2?logo=dart&logoColor=white)
![Platform](https://img.shields.io/badge/Android-offline%20first-0E9F6E)
![Tests](https://img.shields.io/badge/tests-35%20passing-0E9F6E)
[![Build & Release](https://github.com/mahimmazidul/taka/actions/workflows/release.yml/badge.svg)](https://github.com/mahimmazidul/taka/actions/workflows/release.yml)

---

## Screenshots

Everything below is rendered from the real app by the golden test suite
(`flutter test test/golden_test.dart --update-goldens`), refreshed with every UI change.

| Home | Home (dark) |
|---|---|
| ![Home](docs/screenshots/home_light.png) | ![Home dark](docs/screenshots/home_dark.png) |

| Add entry | History |
|---|---|
| ![Add entry](docs/screenshots/add_entry.png) | ![History](docs/screenshots/history.png) |

| Udhar | Settings |
|---|---|
| ![Udhar](docs/screenshots/udhar.png) | ![Settings](docs/screenshots/settings.png) |

Small phone (320 × 568), same layout, nothing clipped:

![Small phone](docs/screenshots/home_small.png)

---

## What it does

- **Log an entry in seconds** — big keypad, expense/income switch, one-tap category
  chips, note, and a date that defaults to now but can be changed.
- **Granular hall-life categories** — ভাত, মাছ, মাংস, সবজি, নাস্তা, বাইরের খাবার,
  কসমেটিকস, কাপড়, লন্ড্রি, ওষুধ, হল খরচ, যাতায়াত, মোবাইল, বই-খাতা, বিনোদন, অন্যান্য.
  Rice, fish and cosmetics are separate on purpose: the point is knowing *where*
  the taka went without tagging anything by hand. Rename, recolour, re-icon,
  add or delete categories freely — deleting one moves its entries to "Other".
- **Home dashboard** — this month's balance, today / week / month spend, a 7-day
  bar chart, budget bars, udhar summary, latest five entries.
- **History** — grouped by day with per-day totals, live note search,
  expense/income filter, category filter and date range. Tap to edit,
  long-press to delete.
- **Budgets** — a monthly cap plus a limit per category. Amber at 80%, red and
  "over by ৳ x" past the limit.
- **Udhar** — money you lent or borrowed, per person. Tap to settle, long-press
  to delete.
- **Backup** — JSON export/import (everything, restorable) and CSV export for
  Excel/Sheets. One tap wipes the ledger.
- **Bangla-first type** — Hind Siliguri for Latin, Bengali and ৳ alike, with a
  light/dark theme.

Deliberately **not** included: login, cloud sync, Firebase, multi-user
workspaces, ads, paid APIs.

---

## Install

Grab the newest `taka-*.apk` from
[Releases](https://github.com/mahimmazidul/taka/releases) (built by CI on every tag)
or from the `taka-apk` artifact of any green
[workflow run](https://github.com/mahimmazidul/taka/actions/workflows/release.yml).
Android will ask you to allow installs from unknown sources — that's expected for
an app that isn't on the Play Store.

## Run it yourself

```bash
git clone https://github.com/mahimmazidul/taka.git
cd taka
flutter pub get
flutter run               # phone or emulator attached
```

Quality gates used in CI:

```bash
flutter analyze                               # 0 issues
flutter test --concurrency=1                  # 35 tests
dart format --output=none --set-exit-if-changed lib test
```

## Release flow

`git tag v1.0.0 && git push origin v1.0.0` →
[`.github/workflows/release.yml`](.github/workflows/release.yml) runs analysis,
tests, builds a release APK and attaches it to a GitHub Release.
Pushes to `main` still build the APK and keep it as a workflow artifact.

The APK is signed with Flutter's debug key so CI can always produce an
installable file. For a store-ready build, add your keystore and
`android/key.properties`, then point `signingConfigs.release` at it.

---

## How it is built

```
lib/
├── main.dart                  open the database, load state, run the app
├── app.dart                   MaterialApp, theme mode, system UI
├── core/
│   ├── app_theme.dart         palette, Hind Siliguri text theme, light/dark
│   └── motion.dart            Pressable, Reveal, AnimatedMoney, page route
├── constants/
│   ├── default_categories.dart  the 22 seeded categories (Bangla + English)
│   └── category_icons.dart      icon keys, icon picker list, colour swatches
├── models/                    transaction_entry, app_category, udhar_entry,
│                              app_settings, period_totals, budget_progress, day_group
├── db/                        database.dart (schema v2 + migration) and
│                              one repository per table
├── store/                     app_state.dart (ChangeNotifier) plus extensions:
│                              settings_actions, category_actions, udhar_actions,
│                              data_actions
├── utils/                     format_currency, date_helpers, budget_calculator,
│                              currency_catalog, export_data, color_hex, id
├── components/                section_title, hero_balance, stat_strip, week_bars,
│                              budget_line, entry_row, category_tile, segmented,
│                              amount_keypad, app_sheet, primary_button,
│                              settings_row, empty_state
└── screens/                   app_shell (floating tab bar), home, add_entry,
                               history, udhar, budgets, settings, categories,
                               category_editor_sheet
```

Only four runtime dependencies: `sqflite`, `path`, `path_provider`, `share_plus`
(plus `file_picker` for restore). No state-management package, no chart package,
no HTTP client.

### Data model (SQLite `taka.db`, schema v2)

```sql
categories(id, name, name_bn, icon, color, kind, budget_minor, sort_order)
transactions(id, type, amount_minor, category_id, note,
             occurred_at, created_at, updated_at)
udhar_entries(id, type, person, amount_minor, note, occurred_at,
              returned, returned_at, created_at, updated_at)
settings(key, value)
```

- **Money is an integer count of paisa.** `0.1 + 0.2` drift is impossible;
  `৳ 1,250.50` exists only at the UI edge (`utils/format_currency.dart`).
- **Timestamps are epoch milliseconds**, so today/week/month are indexed range
  queries, and the whole ledger filters in memory for instant search.
- **Income sources are categories** with `kind = 'income'`, which is what the
  "source" field needs without a second table.
- **Weeks start Sunday** (Bangladesh convention) — one constant in `date_helpers.dart`.
- Schema v1 → v2 migrates in place: adds `name_bn`, maps old emoji icons to icon
  keys and inserts the new granular categories. No data loss.

### Tests

35 tests, all offline:

| File | Covers |
|---|---|
| `test/logic_test.dart` | money formatting, exact keypad→paisa conversion, date helpers, budget thresholds, labels |
| `test/database_test.dart` | the real schema and SQL on an in-memory SQLite: seeds, CRUD, totals, per-day buckets, filters, category reassignment, udhar settlement, settings, backup round-trip, CSV |
| `test/screens_test.dart` | whole app at 320 / 360 / 414 / 768 widths, 1.3× text scale, tab switching, adding an entry end-to-end, dark-mode toggle |
| `test/golden_test.dart` | the screenshots in this README |

---

## Credits

- **Hind Siliguri** (Indian Type Foundry / Google Fonts) — SIL Open Font License 1.1.
  Bundled in `assets/fonts/` so Bangla, Latin and ৳ all render without network access.
- Icons: Material Symbols via `flutter/material`.
- Built for one hall student in Dhaka, and for whoever else keeps a khata in their pocket.

## Changelog

- **v1.0.0** — first full build: dashboard, add/edit, history with filters, udhar,
  budgets, category manager, JSON/CSV backup, dark mode, CI release pipeline.
