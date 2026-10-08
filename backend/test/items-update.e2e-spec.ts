import { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { clearFirestore, createTestApp } from './utils/firestore-test-helpers';

describe('PATCH /items/:id (US-3, US-6)', () => {
  let app: INestApplication;

  beforeAll(async () => {
    app = await createTestApp();
  });

  afterAll(async () => {
    await app.close();
  });

  beforeEach(async () => {
    await clearFirestore();
  });

  async function addItem(userId: string, name: string): Promise<string> {
    const response = await request(app.getHttpServer())
      .post('/items')
      .set('x-user-id', userId)
      .send({ name, quantity: 1 });

    return response.body.id as string;
  }

  it('marks an item as bought', async () => {
    const id = await addItem('user-a', 'milk');

    const response = await request(app.getHttpServer())
      .patch(`/items/${id}`)
      .set('x-user-id', 'user-a')
      .send({ bought: true });

    expect(response.status).toBe(200);
    expect(response.body.bought).toBe(true);
    expect(response.body.id).toBe(id);
  });

  it('marks an item as not bought again', async () => {
    const id = await addItem('user-a', 'milk');

    await request(app.getHttpServer())
      .patch(`/items/${id}`)
      .set('x-user-id', 'user-a')
      .send({ bought: true });

    const response = await request(app.getHttpServer())
      .patch(`/items/${id}`)
      .set('x-user-id', 'user-a')
      .send({ bought: false });

    expect(response.status).toBe(200);
    expect(response.body.bought).toBe(false);
  });

  it('moves the item into the right group in the list (US-3)', async () => {
    const milk = await addItem('user-a', 'milk');
    await addItem('user-a', 'bread');

    await request(app.getHttpServer())
      .patch(`/items/${milk}`)
      .set('x-user-id', 'user-a')
      .send({ bought: true });

    const list = await request(app.getHttpServer())
      .get('/items')
      .set('x-user-id', 'user-a');

    // bread is still unbought, so it sorts above the now-bought milk
    expect(list.body.map((item: { name: string }) => item.name)).toEqual([
      'bread',
      'milk',
    ]);
  });

  it('returns 404 for an item that does not exist, not a crash', async () => {
    const response = await request(app.getHttpServer())
      .patch('/items/does-not-exist')
      .set('x-user-id', 'user-a')
      .send({ bought: true });

    expect(response.status).toBe(404);
    expect(response.body.message).toContain('not found');
  });

  it('returns 404 when another user asks for an item (US-6)', async () => {
    const id = await addItem('user-a', 'milk');

    const response = await request(app.getHttpServer())
      .patch(`/items/${id}`)
      .set('x-user-id', 'user-b')
      .send({ bought: true });

    // Same 404 as a nonexistent item: user-b learns nothing, not even
    // that the item exists. Assert the message came from the handler's
    // NotFoundException, not a router-level 404 (which would mean the
    // route itself is unreachable, not that ownership was checked).
    expect(response.status).toBe(404);
    expect(response.body.message).toContain('not found');

    // Indistinguishability, asserted directly: a genuinely nonexistent
    // item produces the same status and a message that differs only by
    // the item ID.
    const genuinelyMissing = await request(app.getHttpServer())
      .patch('/items/does-not-exist')
      .set('x-user-id', 'user-b')
      .send({ bought: true });

    expect(genuinelyMissing.status).toBe(response.status);
    expect(
      (genuinelyMissing.body.message as string).replace('does-not-exist', id),
    ).toBe(response.body.message);

    const stillUnbought = await request(app.getHttpServer())
      .get('/items')
      .set('x-user-id', 'user-a');
    expect(stillUnbought.body[0].bought).toBe(false);
  });

  it('rejects a non-boolean bought value', async () => {
    const id = await addItem('user-a', 'milk');

    const response = await request(app.getHttpServer())
      .patch(`/items/${id}`)
      .set('x-user-id', 'user-a')
      .send({ bought: 'yes' });

    expect(response.status).toBe(400);
  });

  it('rejects an attempt to rename via PATCH', async () => {
    const id = await addItem('user-a', 'milk');

    const response = await request(app.getHttpServer())
      .patch(`/items/${id}`)
      .set('x-user-id', 'user-a')
      .send({ bought: true, name: 'something else' });

    expect(response.status).toBe(400);
  });

  it('requires an x-user-id header', async () => {
    const response = await request(app.getHttpServer())
      .patch('/items/any-id')
      .send({ bought: true });

    expect(response.status).toBe(401);
  });
});
