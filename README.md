# Jitu Unggul — Asset Management Application

A Flutter-based inventory and event-equipment asset management application developed as an independent software project for **Jitu Unggul**, a games and event equipment supplier.

> **Portfolio showcase:** The repository contains application source code. Real business data and deployment credentials are intentionally not included.

**Live application:** [jitu-unggul-asset-management.web.app](https://jitu-unggul-asset-management.web.app)  
**Developer:** [Aiman Azhad](https://github.com/aimanazhad25)  
**Status:** Deployed on Firebase Hosting. Access to application features may require an authorized account.

## Features

- **User sign-in:** Firebase Authentication and Firestore-backed user profiles.
- **Inventory:** Add, edit, list, and maintain records of equipment.
- **Event planning:** Manage event records and allocate items to events.
- **Asset movement:** Record item check-outs and returns with movement history.
- **Maintenance and exceptions:** Review damaged or missing equipment and track maintenance.
- **Bulk import:** Import inventory from supported spreadsheet or CSV files.
- **Reports:** Generate and review asset and movement information, with PDF/export-related dependencies.

## Tech stack

| Area | Technology |
| --- | --- |
| Application | Flutter, Dart |
| Authentication | Firebase Authentication |
| Database | Cloud Firestore |
| Hosting | Firebase Hosting |
| Data import/export | file_picker, excel, csv, pdf, printing |

## Project structure

```text
lib/
  main.dart               # App initialization, login and dashboard
  models/                 # Item, event, and movement data models
  screens/                # Inventory, events, movements, maintenance, reports
assets/                   # App branding
web/                      # Flutter web hosting entry point
android/, ios/, ...       # Flutter platform runner projects
firebase.json             # Hosting configuration
pubspec.yaml              # Flutter dependencies
```

## Run locally

1. Install the [Flutter SDK](https://docs.flutter.dev/get-started/install) and verify your environment with `flutter doctor`.
2. Run `flutter pub get` inside the project directory.
3. Configure **your own Firebase project**, including Authentication and Firestore, before running the app. The production Firebase client configuration is **not included** in this repository:
   - Install the FlutterFire CLI following [Firebase's Flutter setup guide](https://firebase.google.com/docs/flutter/setup).
   - Run `flutterfire configure` to create `lib/firebase_options.dart` and applicable platform Firebase configuration.
4. Create authorized test users and associated `users/{uid}` profiles as required by the application.
5. Start the app using `flutter run -d chrome` or another configured Flutter device.

> The live URL points to the original Firebase deployment. Building this repository locally does not connect to that production database automatically.

## Security and privacy

- No login credentials, signing passwords, private keys, browser profiles, customer records, or Firebase service-account credentials should be committed.
- `lib/firebase_options.dart`, `android/app/google-services.json`, and local deployment configuration are excluded from the public-source package to avoid publishing production configuration.
- **Important:** Firebase Authentication alone does not secure Cloud Firestore. Verify that deployed Firestore security rules enforce per-user access and appropriate permissions before granting anyone access.
- Do not add live inventory exports or screenshots that reveal business data.

## Notes

The project is presented as a software development portfolio example. The source is not supplied with an open-source license. Confirm appropriate permission from Jitu Unggul before making proprietary source code public.

## Contact

**Aiman Azhad** · [GitHub](https://github.com/aimanazhad25) · [Email](mailto:aimanazhad4@gmail.com)
