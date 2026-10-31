# Taka · টাকা

A daily khata for hall life — what you ate, what you spent, who owes you, and how
much of the month is left.

**Built by Mazidul Islam Mahim** (মাজিদুল ইসলাম মাহিম).

<p align="center">
  <img src="docs/icon.png" width="132" alt="Taka app icon">
</p>

![Flutter](https://img.shields.io/badge/Flutter-3.47-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.13-0175C2?logo=dart&logoColor=white)
![Android](https://img.shields.io/badge/Android-API%2021%2B-3DDC84?logo=android&logoColor=white)
![Tests](https://img.shields.io/badge/tests-45%20passing-0E9F6E)
[![Download APK](https://img.shields.io/badge/download-v1.2.0%20APK-0E9F6E?logo=android&logoColor=white)](https://github.com/mahimmazidul/taka/releases/latest)
[![Build & Release](https://github.com/mahimmazidul/taka/actions/workflows/release.yml/badge.svg)](https://github.com/mahimmazidul/taka/actions/workflows/release.yml)

---

## Screenshots

Every screen, rendered from the real widgets by the golden test suite
(`flutter test test/golden_test.dart --update-goldens` → `docs/screenshots/`), and
refreshed whenever the UI changes. No mockups.

| Home | Home (dark) |
|---|---|
| ![Home](docs/screenshots/home_light.png) | ![Home dark](docs/screenshots/home_dark.png) |

| Add entry | History |
|---|---|
| ![Add entry](docs/screenshots/add_entry.png) | ![History](docs/screenshots/history.png) |

| Udhar | Budgets |
|---|---|
| ![Udhar](docs/screenshots/udhar.png) | ![Budgets](docs/screenshots/budgets.png) |

| Categories | Settings |
|---|---|
| ![Categories](docs/screenshots/categories.png) | ![Settings](docs/screenshots/settings.png) |

| About | Small phone (320 × 568) |
|---|---|
| ![About](docs/screenshots/about.png) | ![Small phone](docs/screenshots/home_small.png) |

---

## The mark

![Taka icon](docs/icon.png)

A sage-to-eucalyptus gradient with the taka sign, rendered by
[`tool/make_icon.py`](tool/make_icon.py) — one script draws every Android density,
the adaptive icon and its monochrome layer, so the icon can never drift out of sync
with the app.

## Motion

Nothing snaps. Tabs glide between each other over 280 ms, pages fade and rise into
place over 320 ms, rows and chips press to 97% under the finger, amounts count
up instead of jumping, and Home's seven bars grow in one after another. Sized so it
still feels instant on a two-year-old phone.

---

## What it does

**Log an entry in one tap.** Open, tap ভাত, type the amount, save. The category
picker opens on the group you used last, so the common case never scrolls. A meal
tag (breakfast / lunch / dinner) is pre-picked from the clock and is one tap to
change — or to remove.

**Two levels of categories, seeded for hall life.** A group holds items, and an
item is what you log. Everything is renameable, recolourable and re-iconable, and
you can add your own groups or park a new item at the top level.

| Group | Items |
|---|---|
| মেইন কোর্স · Main course | ভাত, মাছ, মাংস, পোলাও, খিচুড়ি, সবজি, ডাল, ডিম |
| ড্রিংকস · Drinks | ড্রিংকো, স্পিড, মোজো, কোক / পেপসি, জুস, পানি, কফি |
| নাস্তা · Snacks | পরোটা, সমুচা, সিঙ্গারা, টোস্ট, বিস্কুট, চিপস, চা |
| মিষ্টি · Sweets | মিষ্টি, দই, আইসক্রিম, চকলেট |
| ফল · Fruits | কলা, আপেল, আম, পেয়ারা, পেঁপে, কমলা, তরমুজ |
| কসমেটিকস · Cosmetics & grooming | বডি ওয়াশ, ফেস ওয়াশ, শ্যাম্পু, সাবান, শেভিং ক্রিম, রেজর, ডিওডোরেন্ট, হেয়ার অয়েল, টুথপেস্ট |
| বই-খাতা · Books & stationery | শিট, নোটবুক, কলম, পেন্সিল, ইরেজার, ফটোকপি, খাতা, বই |
| কাপড় · Clothes | জামা, প্যান্ট, টি-শার্ট, জুতা, মোজা, আন্ডারগার্মেন্ট |
| স্বাস্থ্য · Health | ওষুধ, ডাক্তার, টেস্ট, জিম, সাপ্লিমেন্ট |
| হল খরচ · Hall & room | রুম ভাড়া, বিদ্যুৎ, পানি বিল, ওয়াইফাই, হল চাঁদা, মেস বিল |
| যাতায়াত · Transport | রিকশা, সিএনজি, বাস, ট্রেন, রাইড শেয়ার, পার্কিং |
| মোবাইল · Mobile & internet | রিচার্জ, ডেটা প্যাক, এক্সেসরিজ |
| বিনোদন · Entertainment | সিনেমা, গেম, সাবস্ক্রিপশন, ঘুরতে যাওয়া |
| উপহার ও পরিবার · Gifts & family | উপহার দেওয়া, দান, পরিবার |
| ফি ও জরিমানা · Fees & fines | পরীক্ষা ফি, লাইব্রেরি ফি, জরিমানা |

Plus three that sit on the top row themselves — **বাইরের খাবার · Dining out**,
**লন্ড্রি · Laundry**, **অন্যান্য · Other** — and six income sources (বাসা থেকে,
টিউশন, বৃত্তি, ফ্রিল্যান্স, উপহার, অন্যান্য).

**See where the month went.** A hero balance, today / week / month, a 7-day chart,
today's meals, the budget bars closest to their limit, udhar and the last five
entries.

**Budgets that roll up.** Cap a whole group (food: ৳ 5,000) or a single item
(shampoo: ৳ 200). Amber at 80%, red and "over by ৳ x" past the limit.

**History that answers questions.** Grouped by day with per-day totals, live note
search, expense/income filter, a group filter that covers everything inside it,
and date ranges. Tap to edit, long-press to delete.

**Udhar.** Money lent and borrowed per person, one tap to settle.

**Backups you can pick up on another phone.** JSON export / import and CSV for
Excel or Sheets.

---

## Install

Grab the newest file from [Releases](https://github.com/mahimmazidul/taka/releases):

| File | Use it for |
|---|---|
| `taka-<version>-arm64.apk` | **Almost every phone** made since ~2016 (64-bit ARM) |
| `taka-<version>-arm32.apk` | Very old or very cheap 32-bit devices |
| `taka-<version>-x86_64.apk` | Emulators only |
| `taka-<version>.aab` | Publishing to a store — not something you install by hand |

Same features, same UI, same code — the APKs only differ in which CPU build they
carry. Android will ask you to allow installs from unknown sources; that is
expected for an app that isn't on the Play Store.

### About the download size

One universal APK bundles three CPU builds — arm64, arm32 and x86 — so v1.0 was
53 MB. Split per ABI (and with the Dart debug info stripped out of the shipped
binary), the same app with the same features and UI is:

| File | Size | What is inside |
|---|---|---|
| `taka-1.1.0-arm64.apk` | 17.8 MB | one CPU build, 1.2 MB of it Hind Siliguri |
| `taka-1.1.0-arm32.apk` | 15.0 MB | the same for very old phones |
| `taka-1.1.0.aab` | 48.9 MB | all three plus what a store needs — Google Play serves ~18 MB from it |

What is left is mostly the Flutter engine itself (11.8 MB `libflutter.so`) and the
compiled Dart (`libapp.so`, ~5 MB). Regular R8 resource shrinking would win a few
hundred kilobytes and cost readable stack traces; the symbol files are uploaded as a
separate build artifact instead, so a crash report can still be symbolicated.

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
flutter test --concurrency=1                  # 45 tests
dart format --output=none --set-exit-if-changed lib test
```

## Release flow

`git tag v1.1.0 && git push origin v1.1.0` →
[`.github/workflows/release.yml`](.github/workflows/release.yml) runs formatting,
analysis and the tests, builds one APK per CPU plus an app bundle, keeps them as
workflow artifacts and attaches them to a GitHub Release. Pushes to `main` build
the same artifacts without publishing a release.

The APK is signed with Flutter's debug key so CI can always produce an installable
file. For a store-ready build, add your keystore and `android/key.properties`, then
point `signingConfigs.release` at it.

---

## How it is built

```
lib/
├── main.dart                  open the database, load state, run the app
├── app.dart                   MaterialApp, theme mode, system UI
├── core/
│   ├── app_theme.dart         palette, Hind Siliguri text theme, light/dark
│   ├── motion.dart            Pressable, Reveal, AnimatedMoney, page route
│   ├── clock.dart             the one place DateTime.now() lives
│   └── app_info.dart          name, version, author — read by About
├── constants/
│   ├── default_categories.dart    15 groups, 3 standalone items, 6 income sources
│   ├── default_subcategories.dart the 90+ items inside those groups
│   └── category_icons.dart        70 icon keys, the picker subset, colour swatches
├── models/                    transaction_entry (+meal), app_category (+parent),
│                              udhar_entry, app_settings, meal_slot,
│                              period_totals, budget_progress, day_group
├── db/                        database.dart (schema v3, migrations, additive
│                              seeding) and one repository per table
├── store/                     app_state.dart (ChangeNotifier) plus extensions:
│                              settings_actions, category_actions, udhar_actions,
│                              data_actions
├── utils/                     format_currency, date_helpers, budget_calculator,
│                              currency_catalog, export_data, color_hex, id
├── components/                category_picker, hero_balance, stat_strip, week_bars,
│                              budget_line, entry_row, category_tile, segmented,
│                              amount_keypad, app_sheet, primary_button,
│                              settings_row, section_title, empty_state
└── screens/                   app_shell, home, add_entry, history, udhar, budgets,
                               categories, category_editor_sheet, settings, about
```

Five runtime dependencies, all of them boring: `sqflite` (local SQLite), `path`,
`path_provider` (where the backup is written), `share_plus` 13 (hand a file to
Android's share sheet) and `file_picker` 13 (pick a JSON file to restore). No
state-management package, no chart package, no HTTP client, no analytics.

### Data model (SQLite `taka.db`, schema v3)

```sql
categories(id, name, name_bn, icon, color, kind, budget_minor,
           sort_order, parent_id, is_group)
transactions(id, type, amount_minor, category_id, note,
             occurred_at, created_at, updated_at, meal)
udhar_entries(id, type, person, amount_minor, note, occurred_at,
              returned, returned_at, created_at, updated_at)
settings(key, value)
```

- **Money is an integer count of paisa.** `0.1 + 0.2` drift is impossible;
  `৳ 1,250.50` exists only at the UI edge (`utils/format_currency.dart`).
- **Timestamps are epoch milliseconds**, so today/week/month are indexed range
  queries, and the whole ledger filters in memory for instant search.
- **A group is a row with `is_group = '1'`**; its items point at it through
  `parent_id`, so a group budget and a group filter are a rollup, not a second
  table.
- **Income sources are categories** with `kind = 'income'`.
- **Weeks start Sunday** (Bangladesh convention) — one constant in `date_helpers.dart`.
- **"Now" comes from `AppClock`**, never from `DateTime.now()` directly. Tests point
  it at a frozen instant, which is why the screenshots are byte-stable.

### Upgrades never eat your ledger

Three deliberate rules, because losing last month's khata over an app update would
be unforgivable:

1. **Category ids are never renamed.** When the flat list became groups, ভাত kept
   `id = 'rice'`; it only gained `parent_id = 'g_main'`. Every old transaction still
   points at the right category.
2. **Seeding is additive and runs on every open.** Any seeded category missing from
   the database is inserted; nothing that already exists is ever overwritten — your
   names, colours and limits win.
3. **Migrations are idempotent.** Columns are added only if absent, so an
   interrupted upgrade cannot leave a database that refuses to open.

`test/database_test.dart` builds a v2 database by hand, reopens it with the current
code and asserts the old entry, its category and its budget all survived.

### Tests

45 tests, all offline (29 logic + database, 6 screen, 10 golden):

| File | Covers |
|---|---|
| `test/logic_test.dart` | money formatting, exact keypad→paisa conversion, date helpers, budget thresholds, labels |
| `test/database_test.dart` | the real schema and SQL on SQLite: seeds and the category tree, CRUD, totals, per-day buckets, filters, category reassignment and group deletion, udhar settlement, settings, backup round-trip, CSV, and the v2 → v3 migration |
| `test/screens_test.dart` | the whole app at 320 / 360 / 414 / 768 widths, 1.3× text scale, tab switching, adding an entry end-to-end, dark-mode toggle |
| `test/golden_test.dart` | every screenshot in this README |

---

## Credits

- **Mazidul Islam Mahim** (মাজিদুল ইসলাম মাহিম) — idea, requirements, and the refusal
  to accept a boxy app or an emoji.
- **Hind Siliguri** (Indian Type Foundry / Google Fonts) — SIL Open Font License 1.1.
  Bundled in `assets/fonts/` so Bangla, Latin and ৳ all render in one family.
- Icons: Material Symbols via `flutter/material`.

## Changelog

- **v1.2.0** — new launcher icon (rendered from `tool/make_icon.py`), animated tab
  changes and richer page transitions, credit corrected to Mazidul Islam Mahim.
- **v1.1.0** — two-level categories (groups + items, 90+ seeded items), meal tags
  with a "today's meals" strip, group budgets and group filters, additive seeding
  and a safe v2 → v3 migration, About screen with the author credit, and CI now
  ships one APK per CPU plus an app bundle instead of one 50 MB universal APK.
- **v1.0.1** — budget rows no longer printed the category twice; budgets and
  categories joined the screenshot suite; time routed through `AppClock`.
- **v1.0.0** — first full build: dashboard, add/edit, history with filters, udhar,
  budgets, category manager, JSON/CSV backup, dark mode, CI release pipeline.
