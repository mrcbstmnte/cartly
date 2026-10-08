import { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { clearFirestore, createTestApp } from './utils/firestore-test-helpers';

describe('DELETE /items/:id (US-4)', () => {
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

  it('deletes the item and removes it from the list', async () => {
    const milk = await addItem('user-a', 'milk');
    await addItem('user-a', 'bread');

    const response = await request(app.getHttpServer())
      .delete(`/items/${milk}`)
      .set('x-user-id', 'user-a');

    expect(response.status).toBe(200);
    expect(response.body).toEqual({ id: milk });

    const list = await request(app.getHttpServer())
      .get('/items')
      .set('x-user-id', 'user-a');
    expect(list.body.map((item: { name: string }) => item.name)).toEqual([
      'bread',
    ]);
  });

  it('returns 404 for an item that does not exist, not a crash', async () => {
    const response = await request(app.getHttpServer())
      .delete('/items/does-not-exist')
      .set('x-user-id', 'user-a');

    expect(response.status).toBe(404);
    expect(response.body.message).toContain('not found');
  });

  it('returns 404 when deleting twice', async () => {
    const id = await addItem('user-a', 'milk');

    await request(app.getHttpServer())
      .delete(`/items/${id}`)
      .set('x-user-id', 'user-a');

    const second = await request(app.getHttpServer())
      .delete(`/items/${id}`)
      .set('x-user-id', 'user-a');

    // Status alone would pass even with no route at all (Nest's own
    // router 404 for an unmatched path), so pin the message to the
    // handler's NotFoundException to prove the second delete actually
    // reached the existence check.
    expect(second.status).toBe(404);
    expect(second.body.message).toContain('not found');
  });

  it("will not delete another user's item (US-6)", async () => {
    const id = await addItem('user-a', 'milk');

    const response = await request(app.getHttpServer())
      .delete(`/items/${id}`)
      .set('x-user-id', 'user-b');

    expect(response.status).toBe(404);
    expect(response.body.message).toContain('not found');

    // Indistinguishability, asserted directly: a genuinely nonexistent
    // item produces the same status and a message that differs only by
    // the item ID.
    const genuinelyMissing = await request(app.getHttpServer())
      .delete('/items/does-not-exist')
      .set('x-user-id', 'user-b');

    expect(genuinelyMissing.status).toBe(response.status);
    expect(
      (genuinelyMissing.body.message as string).replace('does-not-exist', id),
    ).toBe(response.body.message);

    const list = await request(app.getHttpServer())
      .get('/items')
      .set('x-user-id', 'user-a');
    expect(list.body).toHaveLength(1);
  });

  it('requires an x-user-id header', async () => {
    const response = await request(app.getHttpServer()).delete('/items/any-id');

    expect(response.status).toBe(401);
  });
});
