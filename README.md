# Jitu Unggul — Asset Management Application

A Flutter-based inventory and event-equipment asset management application developed by **Aiman Azhad** for **Jitu Unggul**, a game and event equipment supplier.

> **Private project repository.** The application is live on Firebase Hosting. Source code must be uploaded only from the sanitized, GitHub-ready project package. Business data and deployment credentials are not included in that package.

**Live application:** https://jitu-unggul-asset-management.web.app  
**Developer:** https://github.com/aimanazhad25  
**Tech:** Flutter, Dart, Firebase Authentication, Cloud Firestore, Firebase Hosting

## Features

- Firebase Authentication and user access
- Manage inventory records and equipment details
- Track event allocations, check-outs, and returned items
- Maintenance, damaged-item and missing-item records
- Inventory import, movement history and reports

## Project layout

- `lib/` — Flutter/Dart application and models
- `assets/` — App branding
- `web/` — Flutter web assets
- `android/`, `ios/`, `macos/`, `windows/`, `linux/` — Platform runner projects
- `pubspec.yaml` — Dependencies
- `firebase.json` — Firebase Hosting configuration

## Local setup

1. Install Flutter and run `flutter doctor`.
2. Run `flutter pub get` from the project directory.
3. Set up an authorized Firebase project using `flutterfire configure`; do not commit production secrets or private credentials.
4. Use `flutter run -d chrome` for web development.

The live Firebase deployment is separate from this source repository.

## Privacy and security

- Do not commit `android/key.properties`, keystores, local browser data, export backups, service-account keys or live customer/inventory records.
- `lib/firebase_options.dart` and platform Firebase configuration are omitted from the GitHub-ready package; regenerate for your own Firebase project.
- Confirm company permission before considering public access to source code.
- Review Firestore security rules separately — Firebase Authentication by itself is not sufficient to protect the database.

## Developer

Aiman Azhad — [GitHub](https://github.com/aimanazhad25) — [Email](mailto:aimanazhad4@gmail.com)
