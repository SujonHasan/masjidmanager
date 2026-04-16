# Masjid Manager SaaS

Masjid Manager is a Firebase-backed SaaS foundation for mosque administration. The monorepo contains a Next.js web dashboard, a Flutter mobile scaffold, Firebase rules, and Cloud Functions.

## Structure

```txt
apps/web          Next.js admin and SaaS web app
apps/mobile       Flutter app scaffold using the same Firestore paths
firebase          Firestore rules, Storage rules, indexes, functions
contracts         Data shape and permission notes
docs              Setup, deployment, and testing guides
scripts           Seed/demo helpers
```

## Web Development

```bash
npm install
npm run web:dev
```

Open `http://localhost:3000`.

This workspace is already connected to Firebase project `masjidmanager-saas-sujon` for local development through `apps/web/.env.local`. When Firebase is configured, registration sends an email verification link and the dashboard stays locked until the admin verifies the email.

## Vercel Deployment

Import the GitHub repo into Vercel and set:

```txt
Root Directory: apps/web
Framework: Next.js
Build Command: npm run build
```

Add the `NEXT_PUBLIC_FIREBASE_*` variables in Vercel Project Settings.

## Firebase

```bash
firebase deploy --only firestore:rules,firestore:indexes
firebase deploy --only functions
```

Add your Vercel production domain to Firebase Authentication authorized domains.

Storage rules are present, but Firebase Storage bucket creation is billing-gated for new projects. Enable Storage in Firebase Console after choosing whether to use the Blaze plan, then run:

```bash
firebase deploy --only storage
```
