# Money Master Mobile

Flutter version of the Money Master daily finance tracker.

## Current Status

- Flutter app scaffolded inside `mobile/`
- Supabase-ready app bootstrap
- Login/create-account screen
- Dashboard shell with account balances and recent activity
- Dart models matching the existing Supabase tables

## Run Preview

Flutter is installed at:

```powershell
C:\Users\bdCalling\development\flutter\bin\flutter.bat
```

Run without Supabase keys:

```powershell
cd C:\Sakib\daily_tracker\mobile
C:\Users\bdCalling\development\flutter\bin\flutter.bat run -d chrome
```

Run with Supabase:

```powershell
cd C:\Sakib\daily_tracker\mobile
.\tool\run_dev.ps1
```

Run without opening a new browser window:

```powershell
cd C:\Sakib\daily_tracker\mobile
.\tool\run_dev.ps1 -NoLaunch
```

Then open or refresh:

```text
http://127.0.0.1:52710
```

## Windows Setup Note

Before running `flutter pub get` or building the app, enable Windows Developer Mode:

```powershell
start ms-settings:developers
```

Turn on **Developer Mode**, then rerun:

```powershell
C:\Users\bdCalling\development\flutter\bin\flutter.bat pub get
```

Android emulator support still needs Android Studio and the Android SDK.

## Production Database Migration

The app runs against the existing schema and falls back safely when the
production RPCs are not installed. Before a production release, run this file
once in the Supabase SQL editor:

```text
scripts/003_performance_security.sql
```

It hardens RLS to authenticated, user-owned rows; removes anonymous table
access; adds composite indexes; enables cursor-paged Activity reads; adds
server-side dashboard summaries; and installs an atomic idempotent mutation RPC
for offline retry.

Do not place a Supabase service-role key in the Flutter app. The publishable
key is expected, and RLS remains the security boundary.

## Local Data Protection

Dashboard cache and offline mutation payloads are encrypted with AES-256-GCM.
The encryption key is stored through the platform secure-storage service.
Android backups are disabled so encrypted values cannot be restored without
their device key.
