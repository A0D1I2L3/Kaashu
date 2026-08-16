# Kashu

<div align="center">
  <img alt="Kashu icon" src="promotional/icons/icon.jpeg" width="150px">
</div>

**Kashu** is a private, local-first money management app for Android and web. Track expenses, plan budgets, set goals, and manage multiple accounts and currencies — all on your own device. No accounts, no cloud, no paywalls.

Kashu is a fork of the [Cashew](https://github.com/jameskokoska/Cashew) expense tracker, rebuilt with a focus on privacy and UPI-centric features for Indian users. Built with **Flutter** and [Drift](https://drift.simonbinder.eu/) (SQLite).

---

## Features

### 🧾 Transactions

- Track expenses, income, upcoming payments, subscriptions, repeating transactions, debts (borrowed) and credits (lent).
- Custom categories with custom icons and default types (expense / income).
- Auto-assign recurring merchants to categories and custom titles.
- Full-text search and filters by date, category, amount, or custom tags.
- Batch operations: long-press to select, swipe to edit or delete multiple entries at once.

### 🎯 Budgets & Goals

- Flexible budgets with custom time periods — monthly, weekly, daily, or your own.
- Opt-in transactions per budget and per-category spending limits.
- Review past budget history to spot spending trends.
- Spending and saving goals with progress tracking.

### 📸 UPI Screenshot Extraction

- Scan a UPI payment screenshot (PhonePe, Google Pay, Paytm, BHIM, and more) from inside the app, or share it straight to Kashu from any UPI app's share sheet.
- On-device OCR (ML Kit) parses the amount, merchant, date, and transaction type, then pre-fills a new transaction. Screenshots never leave your device.
- Review mode flags low-confidence parses so you can correct them before saving.

### 💱 Multiple Currencies & Accounts

- Manage finances across currencies with up-to-date conversion rates.
- Switch accounts and currencies freely — everything is converted automatically.
- Option to hide currency labels when all accounts share the same currency.

### 🔒 Privacy & Security

- **100% local storage** (SQLite via Drift) — no cloud, no accounts, no Firebase.
- Optional biometric lock.
- Full database backup (`.sql` / `.sqlite`) and CSV export; restore after reinstall or when switching devices.

### 🎨 Design & Automation

- Material You design with custom accent color, light/dark mode, and a customizable home screen.
- Detailed spending graphs.
- Notifications and reminders for budgets, goals, transactions, and upcoming due dates.
- CSV and Google Sheets import.
- App links and home screen widgets.

---

## Getting Started

### Prerequisites

- [Flutter](https://docs.flutter.dev/get-started/install) 3.38 or newer
- Android SDK (API 24+) and an Android device or emulator

### Run

```bash
cd budget
flutter pub get
flutter run
```

### Build

```bash
cd budget

# Debug APK (for development)
flutter build apk --debug

# Release APK
flutter build apk --release

# Release app bundle
flutter build appbundle --release
```

Release builds are signed with your own keystore — `budget/android/build.gradle` reads `budget/android/key.properties` if present (with `keyAlias`, `keyPassword`, `storeFile`, `storePassword`). Without it, Gradle falls back to debug signing.

---

## Platform Support

| Platform | Status           |
| -------- | ---------------- |
| Android  | ✅ Supported     |
| Web      | ✅ Supported     |
| iOS      | ❌ Removed       |

---

## Developer Notes

### Project structure

- `budget/` — the Flutter application.
- `budget/lib/database/` — Drift schema, tables, and migrations.
- `budget/lib/pages/` — UI screens.
- `budget/lib/struct/` — core logic, including the UPI OCR pipeline (`upiOcr.dart`, `upiParser.dart`, `upiScreenshotScanner.dart`).
- `budget/packages/` — bundled, modified forks of discontinued packages.
- `promotional/` — marketing and store assets.

### Migrate the database

1. Make schema or table changes.
2. Bump the schema version: `int schemaVersionGlobal = ... + 1` in `lib/database/tables.dart`.
3. From `budget/`, generate the code: `dart run build_runner build`.
4. Export the new schema (replace `[schemaVersion]`):
   `dart run drift_dev schema dump lib/database/tables.dart drift_schemas/drift_schema_v[schemaVersion].json`
   See [Drift migrations](https://drift.simonbinder.eu/docs/advanced-features/migrations/#exporting-the-schema).
5. Generate step-by-step migrations: `dart run drift_dev schema steps drift_schemas/ lib/database/schema_versions.dart`.
6. Add the migration strategy for the new version in the `stepByStep(...)` function in `tables.dart`.

### Bundled packages

This repository bundles modified versions of discontinued packages in `budget/packages`:

- [implicitly_animated_reorderable_list](https://pub.dev/packages/implicitly_animated_reorderable_list)
- [sliding_sheet](https://pub.dev/packages/sliding_sheet)

### Code conventions

- **Platform detection:** always use `getPlatform()` from `lib/functions.dart` — `Platform` is not available on web.
- **Navigation:** use `pushRoute(context, page)` from `lib/functions.dart` — it handles platform routing and `PageRouteBuilder`.
- **Naming:** "Wallets" are called "Accounts" in the UI but the internal name `Wallet` is still used. Likewise "Objectives" are "Goals" in the UI but the internal name `Objectives` is still used.

### Develop wirelessly on Android

```bash
adb tcpip 5555
adb connect <IP>
```

Find the phone's IP at `About Phone` → `Status Information` → `IP Address`.

### Publish a release

1. Bump the version in `budget/pubspec.yaml`.
2. Tag and push:
   ```bash
   git tag <version>
   git push origin <version>
   ```
3. Create the release and upload the binaries at https://github.com/A0D1I2L3/Finbud/releases/new.

---

## Translations

App strings live in `lib/struct/languageMap.dart`. Update translations with:

```bash
cd budget
dart run flutter_localizations:generate --output-dir=... # see scripts/
```

Windows helpers are in `scripts/` (`update_translations.bat`, etc.).

---

## License

GNU GPL v3.0. Kashu is a fork of [Cashew](https://github.com/jameskokoska/Cashew) by James Kokoska. See [LICENSE](LICENSE).
