# Kaashu

<div align="center">
  <img alt="Kaashu icon" src="promotional/icons/icon.jpeg" width="150px">
</div>

**Kaashu** is a private, local-first money management app for Android and web. Track expenses, plan budgets, set goals, and manage multiple accounts and currencies — all on your own device. No accounts, no cloud, no paywalls.

Kaashu is a fork of the [Cashew](https://github.com/jameskokoska/Cashew) expense tracker, rebuilt with a focus on privacy and UPI-centric features for Indian users. Built with **Flutter** and [Drift](https://drift.simonbinder.dev/) (SQLite).

> **Current status:** Kaashu is currently in development. The application is functional for testing, but **only debug builds are currently supported**. Release builds are still being worked on and should not be considered production-ready.

---

## Features

### Transactions

* Track expenses, income, upcoming payments, subscriptions, repeating transactions, debts (borrowed) and credits (lent).
* Custom categories with custom icons and default types (expense / income).
* Auto-assign recurring merchants to categories and custom titles.
* Full-text search and filters by date, category, amount, or custom tags.
* Batch operations: long-press to select, swipe to edit or delete multiple entries at once.

### Budgets & Goals

* Flexible budgets with custom time periods — monthly, weekly, daily, or custom periods.
* Opt-in transactions per budget and per-category spending limits.
* Review past budget history to identify spending trends.
* Spending and saving goals with progress tracking.

### UPI Screenshot Extraction

* Scan UPI payment screenshots from PhonePe, Google Pay, Paytm, BHIM, and other UPI apps.
* Share screenshots directly to Kaashu from a UPI app to automatically start the scan.
* Pre-fills the transaction form with the detected amount, merchant, UPI ID, date, and transaction type.
* Fully on-device OCR using **PP-OCR v5 with ONNX Runtime**.
* Low-confidence results are flagged for review before saving.

### Multiple Currencies & Accounts

* Manage multiple accounts and currencies.
* Automatically convert between currencies using up-to-date exchange rates.
* Switch between accounts and currencies seamlessly.
* Option to hide currency labels when all accounts use the same currency.

### Privacy & Security

* **100% local storage** using SQLite via Drift.
* No accounts, cloud storage, Firebase, or external data collection.
* Optional biometric lock.
* Full database backup and restore using `.sql` / `.sqlite` files.
* CSV export for external use.

### Design & Automation

* Material You interface with custom accent colors and light/dark mode.
* Customizable home screen.
* Spending graphs and statistics.
* Notifications and reminders for budgets, goals, transactions, and upcoming payments.
* CSV and Google Sheets import.
* App links and home screen widgets.

---

## Current Development Status

Kaashu is currently in active development.

The core application and UPI screenshot scanning workflow are functional, but several areas still require work before a stable release can be provided.

**Current build status:**

* Android debug builds are currently working.
* Release builds are still under development and testing.
* UPI OCR is functional but requires further optimization and accuracy improvements.
* Production release testing has not yet been completed.

### TODO

* [ ] Fix and stabilize release builds.
* [ ] Improve UPI OCR processing speed.
* [ ] Improve OCR accuracy across different UPI apps and screenshot formats.
* [ ] Improve handling of OCR errors, particularly amount extraction.
* [ ] Improve merchant, UPI ID, date, and transaction type extraction.
* [ ] Expand testing across different UPI applications and screenshot layouts.
* [ ] Complete release-build testing and stability checks.

---

## Getting Started

### Prerequisites

* [Flutter](https://docs.flutter.dev/get-started/install) 3.38 or newer
* Android SDK (API 24+)
* Android device or emulator

### Run

```bash
cd budget
flutter pub get
flutter run
```

### Build

```bash
cd budget

# Debug APK
flutter build apk --debug

# Release APK
flutter build apk --release

# Release app bundle
flutter build appbundle --release
```

**Note:** Debug builds are currently the recommended way to run Kaashu. Release builds are still under development.

Release builds are signed with your own keystore — `budget/android/build.gradle` reads `budget/android/key.properties` if present with `keyAlias`, `keyPassword`, `storeFile`, and `storePassword`. Without it, Gradle falls back to debug signing.

---

## Platform Support

| Platform | Status                        |
| -------- | ----------------------------- |
| Android  | Development / Debug supported |
| Web      | Development                   |
| iOS      | Removed                       |

---

## Developer Notes

### Project structure

* `budget/` — Flutter application.
* `budget/lib/database/` — Drift schema, tables, and migrations.
* `budget/lib/pages/` — UI screens.
* `budget/lib/struct/` — core logic, including the UPI OCR pipeline (`upiOcr.dart`, `upiParser.dart`, `upiScreenshotScanner.dart`).
* `budget/packages/` — bundled, modified forks of discontinued packages.
* `promotional/` — marketing and store assets.

### Database migrations

1. Make schema or table changes.
2. Bump `schemaVersionGlobal` in `lib/database/tables.dart`.
3. From `budget/`, generate the code:

   ```bash
   dart run build_runner build
   ```
4. Export the new schema:

   ```bash
   dart run drift_dev schema dump lib/database/tables.dart drift_schemas/drift_schema_v[schemaVersion].json
   ```
5. Generate migration steps:

   ```bash
   dart run drift_dev schema steps drift_schemas/ lib/database/schema_versions.dart
   ```
6. Add the migration strategy for the new version in `stepByStep(...)` in `tables.dart`.

See the [Drift migration documentation](https://drift.simonbinder.eu/docs/advanced-features/migrations/#exporting-the-schema).

### Bundled packages

This repository includes modified versions of discontinued packages:

* [implicitly_animated_reorderable_list](https://pub.dev/packages/implicitly_animated_reorderable_list)
* [sliding_sheet](https://pub.dev/packages/sliding_sheet)

### Code conventions

* **Platform detection:** use `getPlatform()` from `lib/functions.dart`. `Platform` is not available on web.
* **Navigation:** use `pushRoute(context, page)` from `lib/functions.dart`.
* **Naming:** "Wallets" are called "Accounts" in the UI, while the internal name `Wallet` is retained. Similarly, "Objectives" are called "Goals" in the UI while the internal name `Objectives` is retained.

### Wireless Android development

```bash
adb tcpip 5555
adb connect <IP>
```

Find the device IP under `About Phone` → `Status Information` → `IP Address`.

### Publishing a release

1. Complete the remaining release and OCR work.
2. Bump the version in `budget/pubspec.yaml`.
3. Create and push a version tag:

   ```bash
   git tag <version>
   git push origin <version>
   ```
4. Create the GitHub release and upload the binaries.

---

## Translations

App strings are maintained in `lib/struct/languageMap.dart`.

Translation utilities are available through the project's scripts. Windows helpers are located in `scripts/`, including `update_translations.bat`.

---

## License

GNU GPL v3.0.

Kaashu is a fork of [Cashew](https://github.com/jameskokoska/Cashew) by James Kokoska.

