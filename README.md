<h1 align="center" style="font-size:28px; line-height:1"><b>Kashu</b></h1>

<div align="center">
  <a href="https://github.com/A0D1I2L3/Finbud">
    <img alt="Icon" src="promotional/icons/icon.png" width="150px" >
  </a>
</div>

<br />

<div align="center">
  <a href="https://github.com/A0D1I2L3/Finbud/releases/">
    <img alt="GitHub Badge" src="promotional/store-banners/github-badge.png" height="60px">
  </a>
</div>

---

<br />

Kashu is a full-fledged, feature-rich application designed to empower users in managing their finances effectively. Built using Flutter with Drift's SQL package. It is a fork of the [Cashew](https://github.com/jameskokoska/Cashew) expense tracker, rebranded and adapted for personal use — fully local, no Firebase, no paywalls.

> **Note:** The app icon and promotional images still use the upstream Cashew assets. Replace them with your own artwork before shipping.

---

## Key Features

### 💸 Budget Management

- Custom Budgets and Time Periods: Set up personalized budgets with flexible time periods, such as monthly, weekly, daily, or any custom time period that suits your financial planning needs.
- Added Budgets: Selectively add transactions to specific budgets, allowing you to focus on specific expense categories.
- Category Spending Limits per Budget: Set limits for each category within a budget, ensuring responsible spending.
- Past Budget History Viewing: Analyze your spending habits over time by accessing past budget history.
- Goals: Create spending and saving goals and track your progress towards achieving them.

### 💰 Transaction Management

- Support for Different Transaction Types: Upcoming, subscription, repeating, debts (borrowed), and credit (lent).
- Custom Categories: Create personalized categories with custom icons, and set the default type (expense or income).
- Custom Titles: Automatically assign transactions with the same name to specific categories.
- Search and Filters: Search and filter transactions by date, category, amount, or custom tags.
- Easy Editing: Long-press and swipe to select multiple budgets, edit, or delete at once.

### 📸 UPI Payment Extraction

- Scan a UPI payment screenshot (PhonePe, GPay, BHIM) from inside the app, or share the screenshot directly to Kashu from any UPI app's share sheet.
- On-device OCR parses the amount, merchant, date, and transaction type, then pre-fills a new transaction.

### 💱 Financial Flexibility

- Multiple Currencies and Accounts: Manage finances across different currencies with up-to-date conversion rates.
- Switch Accounts and Currencies with Ease: Everything is converted automatically in an instant.

### 🔒 Enhanced Security and Accessibility

- Biometric Lock: Secure budget data using biometric authentication.

### 🎨 User Experience and Design

- Material You Design
- Custom Accent Color
- Light and Dark Mode
- Customizable Home Screen
- Detailed Graph Visuals

### 💿 Smart Automation

- Notifications: Reminders for budget goals, transactions, and upcoming due dates.
- Import CSV Files
- Import Google Sheets
- App Links / Home Screen Widgets

### 💾 Local-Only Storage & Backup

- All data is stored locally (SQLite via Drift) — no cloud, no accounts.
- Export a full database backup (`.sql` / `.sqlite`) or CSV, and import it later to restore after an uninstall/reinstall or device change.

## Developer Notes

### Android Release

- To build an APK: `flutter build apk --release`
- To build an app-bundle: `flutter build appbundle --release`

Note: required Android SDK.

### GitHub release

- Create a tag for the current version specified in `pubspec.yaml`
- `git tag <version>`
- Push the tag
- `git push origin <version>`
- Create the release and upload binaries
- https://github.com/A0D1I2L3/Finbud/releases/new

### Bundled Packages

This repository contains, bundled in, modified versions of the discontinued packages listed below. They can be found in the folder `/budget/packages`

- https://pub.dev/packages/implicitly_animated_reorderable_list
- https://pub.dev/packages/sliding_sheet

### Develop Wirelessly on Android

- `adb tcpip 5555`
- `adb connect <IP>`
- Get the phone's IP by going to `About Phone` > `Status Information` > `IP Address`

### Migrate Database

1. Make any database changes to the schema and tables
2. Bump the schema version
   - Change `int schemaVersionGlobal = ...+1` in `tables.dart`
3. Make sure you are in application root directory
   - `cd ./budget/`
4. Generate database code
   - Run `dart run build_runner build`
5. Export the new schema
   - Generate schema dump for the newly created schema
   - Replace `[schemaVersion]` in the command below with the value of `schemaVersionGlobal`
   - Run `dart run drift_dev schema dump lib/database/tables.dart drift_schemas//drift_schema_v[schemaVersion].json`
   - Read more: https://drift.simonbinder.eu/docs/advanced-features/migrations/#exporting-the-schema
6. Generate step-by-step migrations
   - Run `dart run drift_dev schema steps drift_schemas/ lib/database/schema_versions.dart`
7. Implement migration strategy
   - Edit `await stepByStep(...)` function in `tables.dart` and add the migration strategy for the new version migration

### Get Platform

- Use `getPlatform()` from `functions.dart`
- Since `Platform` is not supported on web, we must create a wrapper and always use this to determine the current platform

### Push Route

- If we want to navigate to a new page, stick to `pushRoute(context, page)` function from `functions.dart`
- It handles the platform routing and `PageRouteBuilder`

### Wallets vs. Accounts

- `Wallets` have been renamed to `Accounts` on the front-end but internally, the name `Wallet` is still used.

### Objectives vs. Goals

- `Objectives` have been renamed to `Goals` on the front-end but internally, the name `Objectives` is still used.

## License

GNU GPL v3.0. This project is a fork of [Cashew](https://github.com/jameskokoska/Cashew) by James Kokoska. See [LICENSE](LICENSE).
