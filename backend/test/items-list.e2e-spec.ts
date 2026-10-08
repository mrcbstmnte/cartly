import { INestApplication } from '@nestjs/common';
import { Firestore, Timestamp } from 'firebase-admin/firestore';
import request from 'supertest';
import { FIRESTORE } from '../src/firebase/firestore.provider';
import { clearFirestore, createTestApp } from './utils/firestore-test-helpers';

describe('GET /items (US-1)', () => {
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

  async function seed(
    userId: string,
    items: { name: string; bought: boolean; createdAt: Date }[],
  ): Promise<void> {
    const ref = db.collection('users').doc(userId).collection('items');
    for (const item of items) {
      await ref.add({
        name: item.name,
        quantity: 1,
        bought: item.bought,
        createdAt: Timestamp.fromDate(item.createdAt),
        updatedAt: Timestamp.fromDate(item.createdAt),
      });
    }
  }

  it('returns an empty array for a user with no items', async () => {
    const response = await request(app.getHttpServer())
      .get('/items')
      .set('x-user-id', 'user-a');

    expect(response.status).toBe(200);
    expect(response.body).toEqual([]);
  });

  it('puts unbought items first, newest first within each group', async () => {
    await seed('user-a', [
      {
        name: 'old-unbought',
        bought: false,
        createdAt: new Date('2026-01-01'),
      },
      { name: 'new-bought', bought: true, createdAt: new Date('2026-03-01') },
      {
        name: 'new-unbought',
        bought: false,
        createdAt: new Date('2026-02-01'),
      },
      { name: 'old-bought', bought: true, createdAt: new Date('2026-01-15') },
    ]);

    const response = await request(app.getHttpServer())
      .get('/items')
      .set('x-user-id', 'user-a');

    expect(response.status).toBe(200);
    expect(response.body.map((item: { name: string }) => item.name)).toEqual([
      'new-unbought',
      'old-unbought',
      'new-bought',
      'old-bought',
    ]);
  });

  it('returns each item with name, quantity, bought and ISO timestamps', async () => {
    await seed('user-a', [
      { name: 'milk', bought: false, createdAt: new Date('2026-01-01') },
    ]);

    const response = await request(app.getHttpServer())
      .get('/items')
      .set('x-user-id', 'user-a');

    expect(response.body).toHaveLength(1);
    expect(response.body[0]).toEqual({
      id: expect.any(String),
      name: 'milk',
      quantity: 1,
      bought: false,
      createdAt: '2026-01-01T00:00:00.000Z',
      updatedAt: '2026-01-01T00:00:00.000Z',
    });
  });

  it("never returns another user's items", async () => {
    await seed('user-a', [
      { name: 'a-item', bought: false, createdAt: new Date('2026-01-01') },
    ]);
    await seed('user-b', [
      { name: 'b-item', bought: false, createdAt: new Date('2026-01-01') },
    ]);

    const response = await request(app.getHttpServer())
      .get('/items')
      .set('x-user-id', 'user-b');

    expect(response.body.map((item: { name: string }) => item.name)).toEqual([
      'b-item',
    ]);
  });
});
