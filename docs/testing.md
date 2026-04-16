# Testing

## Web

```bash
npm run web:build
npm run web:lint
```

Manual checks:

- Landing page renders.
- Register/login pages render.
- Demo mode can create categories, income, expenses, members, announcements, and prayer times.
- Firebase mode writes to Firestore with realtime dashboard updates.

## Flutter

```bash
cd apps/mobile
flutter pub get
flutter analyze
```

## Firebase

Use the Firebase emulator suite before production when rules are finalized.
