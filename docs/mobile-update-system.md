# Mobile Update System

The Flutter app checks this live manifest on startup and when the app resumes:

```txt
https://masjidmanager-saas-sujon.web.app/app-update.json
```

If `latestBuildNumber` is higher than the installed app build number and `apkUrl` is not empty, the app shows a polished update dialog.

## Release Steps

1. Build a new APK:

```bash
cd apps/mobile
flutter build apk --release
```

2. Host the APK somewhere public:

- Vercel public file: `https://YOUR_DOMAIN/app-release.apk`
- GitHub Release asset URL
- Firebase Storage public URL after enabling Blaze

Firebase Hosting on the Spark plan cannot host APK files because executable files are blocked.

3. Update `apps/web/public/app-update.json`:

```json
{
  "enabled": true,
  "latestVersionName": "1.0.2",
  "latestBuildNumber": 3,
  "minimumBuildNumber": 2,
  "apkUrl": "https://YOUR_PUBLIC_APK_URL/app-release.apk",
  "title": "A fresh Masjid Manager update is ready",
  "body": "Install the latest version for smoother mosque records and better sync.",
  "releaseNotes": ["Short, human-readable update note"]
}
```

4. Deploy the manifest:

```bash
firebase deploy --only hosting
```

## Current State

The update-checker code is included from Android build `1.0.1+2`.

Installed APKs older than this build cannot show the popup because they do not contain the checker code. After users install `1.0.1+2`, future releases can show the popup automatically.
