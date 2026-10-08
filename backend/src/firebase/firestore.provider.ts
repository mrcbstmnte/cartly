import { Provider } from '@nestjs/common';
import { applicationDefault, getApps, initializeApp } from 'firebase-admin/app';
import { Firestore, getFirestore } from 'firebase-admin/firestore';

export const FIRESTORE = 'FIRESTORE';

export const firestoreProvider: Provider = {
  provide: FIRESTORE,
  useFactory: (): Firestore => {
    const projectId = process.env.FIREBASE_PROJECT_ID;
    if (!projectId) {
      throw new Error(
        'FIREBASE_PROJECT_ID is not set. Copy .env.example to .env.',
      );
    }

    // When FIRESTORE_EMULATOR_HOST is set the Admin SDK routes to the emulator
    // and no credentials are required or wanted.
    const useEmulator = Boolean(process.env.FIRESTORE_EMULATOR_HOST);

    if (getApps().length === 0) {
      initializeApp(
        useEmulator
          ? { projectId }
          : { projectId, credential: applicationDefault() },
      );
    }

    return getFirestore();
  },
};
