import { INestApplication } from '@nestjs/common';
import { Firestore } from 'firebase-admin/firestore';
import { FIRESTORE } from '../src/firebase/firestore.provider';
import { clearFirestore, createTestApp } from './utils/firestore-test-helpers';

describe('Firestore harness', () => {
  let app: INestApplication;
  let db: Firestore;

  beforeAll(async () => {
    app = await createTestApp();
    db = app.get<Firestore>(FIRESTORE);
  });

  afterAll(async () => {
    await app.close();
  });

  beforeEach(async () => {
    await clearFirestore();
  });

  it('round-trips a document through the emulator', async () => {
    const ref = db.collection('users').doc('harness').collection('items').doc();
    await ref.set({ name: 'milk' });

    const snapshot = await ref.get();

    expect(snapshot.exists).toBe(true);
    expect(snapshot.data()).toEqual({ name: 'milk' });
  });

  it('clearFirestore empties the collection between tests', async () => {
    const items = db.collection('users').doc('harness').collection('items');
    await items.add({ name: 'bread' });

    await clearFirestore();

    const snapshot = await items.get();
    expect(snapshot.empty).toBe(true);
  });
});
