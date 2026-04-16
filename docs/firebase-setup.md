# Firebase Setup

Enable these products in one Firebase project:

- Authentication with email/password provider.
- Cloud Firestore.
- Cloud Storage.
- Cloud Functions.
- App Check before production launch.

## Current Firebase Project

This workspace is connected to:

```txt
Firebase account: sujonhasan171@gmail.com
Project ID: masjidmanager-saas-sujon
Project name: Masjid Manager SaaS
Firestore database: (default), asia-south1
Web app: Masjid Manager Web
Android app: com.masjidmanager.masjid_manager_mobile
```

Firestore rules and indexes have been deployed. `apps/web/.env.local` is configured for local web development.

## Authentication Requirements

Enable **Email/Password** in Firebase Console > Authentication > Sign-in method.

The web app sends a Firebase email verification link during registration. Admin dashboard access is blocked until:

- Firebase Auth user exists.
- `emailVerified` is true.
- `users/{uid}` profile exists.
- `mosques/{mosqueId}/users/{uid}` membership exists and is active.

After deploying to Vercel, add the production domain to Firebase Console > Authentication > Settings > Authorized domains.

## Web Config

Local development is already configured in `apps/web/.env.local`. For Vercel, copy the same `NEXT_PUBLIC_FIREBASE_*` values from that file into Vercel Project Settings.

## Flutter Config

The Android app is already registered through FlutterFire and `apps/mobile/lib/firebase_options.dart` has been generated. Keep the Firestore path conventions aligned with the web app:

```txt
mosques/{mosqueId}/categories
mosques/{mosqueId}/transactions
mosques/{mosqueId}/members
mosques/{mosqueId}/documents
mosques/{mosqueId}/announcements
mosques/{mosqueId}/prayerTimes
```

## Storage Note

Firebase Storage rules are ready in `firebase/storage.rules`, but Storage is not initialized yet. New Firebase default buckets created after October 30, 2024 use the `{PROJECT_ID}.firebasestorage.app` format and require the pay-as-you-go Blaze plan, so enable Storage only after confirming billing.
