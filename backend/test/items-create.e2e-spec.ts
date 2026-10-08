import { INestApplication } from '@nestjs/common';
import { Firestore } from 'firebase-admin/firestore';
import request from 'supertest';
import { FIRESTORE } from '../src/firebase/firestore.provider';
import { clearFirestore, createTestApp } from './utils/firestore-test-helpers';

describe('POST /items (US-2)', () => {
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

  function itemsOf(userId: string) {
    return db.collection('users').doc(userId).collection('items');
  }

  it('creates an item that starts as not bought', async () => {
    const response = await request(app.getHttpServer())
      .post('/items')
      .set('x-user-id', 'user-a')
      .send({ name: 'milk', quantity: 2 });

    expect(response.status).toBe(201);
    expect(response.body).toEqual({
      id: expect.any(String),
      name: 'milk',
      quantity: 2,
      bought: false,
      createdAt: expect.any(String),
      updatedAt: expect.any(String),
    });

    const snapshot = await itemsOf('user-a').get();
    expect(snapshot.size).toBe(1);
  });

  it('trims the name', async () => {
    const response = await request(app.getHttpServer())
      .post('/items')
      .set('x-user-id', 'user-a')
      .send({ name: '  milk  ', quantity: 1 });

    expect(response.status).toBe(201);
    expect(response.body.name).toBe('milk');
  });

  it.each([
    ['an empty name', { name: '', quantity: 1 }, 'name'],
    ['a whitespace-only name', { name: '   ', quantity: 1 }, 'name'],
    ['a missing name', { quantity: 1 }, 'name'],
    ['quantity below 1', { name: 'milk', quantity: 0 }, 'quantity'],
    ['a negative quantity', { name: 'milk', quantity: -3 }, 'quantity'],
    ['a fractional quantity', { name: 'milk', quantity: 1.5 }, 'quantity'],
    ['a missing quantity', { name: 'milk' }, 'quantity'],
  ])(
    'rejects %s with 400 and writes nothing',
    async (_label, body, expectedField) => {
      const response = await request(app.getHttpServer())
        .post('/items')
        .set('x-user-id', 'user-a')
        .send(body);

      expect(response.status).toBe(400);
      expect(JSON.stringify(response.body.message)).toContain(expectedField);

      // The point of US-2: nothing reached the database.
      const snapshot = await itemsOf('user-a').get();
      expect(snapshot.empty).toBe(true);
    },
  );

  it('rejects unknown fields rather than silently dropping them', async () => {
    const response = await request(app.getHttpServer())
      .post('/items')
      .set('x-user-id', 'user-a')
      .send({ name: 'milk', quantity: 1, bought: true });

    expect(response.status).toBe(400);

    const snapshot = await itemsOf('user-a').get();
    expect(snapshot.empty).toBe(true);
  });

  it('requires an x-user-id header', async () => {
    const response = await request(app.getHttpServer())
      .post('/items')
      .send({ name: 'milk', quantity: 1 });

    expect(response.status).toBe(401);
  });
});
