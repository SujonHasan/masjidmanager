# Deployment

## Vercel Web Deploy

1. Push the root repository to GitHub.
2. Create a Vercel project from that repository.
3. Set the Vercel root directory to `apps/web`.
4. Add all `NEXT_PUBLIC_FIREBASE_*` environment variables.
5. Deploy.

## Firebase Auth Domain

After the first Vercel deployment, add these domains in Firebase Console:

- `your-project.vercel.app`
- Any production custom domain.

Go to Firebase Console > Authentication > Settings > Authorized domains.

Also enable Email/Password sign-in. The app requires email verification before opening `/dashboard`.

## Firebase Backend

Deploy rules and indexes:

```bash
firebase deploy --only firestore:rules,firestore:indexes,storage
```

Deploy functions:

```bash
npm --workspace firebase/functions run build
firebase deploy --only functions
```
