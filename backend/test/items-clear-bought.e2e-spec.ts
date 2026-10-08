import { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { clearFirestore, createTestApp } from './utils/firestore-test-helpers';

describe('DELETE /items/bought (US-5)', () => {
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

  async function addItem(
    userId: string,
    name: string,
    bought = false,
  ): Promise<string> {
    const created = await request(app.getHttpServer())
      .post('/items')
      .set('x-user-id', userId)
      .send({ name, quantity: 1 });

    const id = created.body.id as string;

    if (bought) {
      await request(app.getHttpServer())
        .patch(`/items/${id}`)
        .set('x-user-id', userId)
        .send({ bought: true });
    }

    return id;
  }

  it('removes every bought item and leaves unbought ones untouched', async () => {
    await addItem('user-a', 'milk', true);
    await addItem('user-a', 'bread', false);
    await addItem('user-a', 'eggs', true);
    await addItem('user-a', 'rice', false);

    const response = await request(app.getHttpServer())
      .delete('/items/bought')
      .set('x-user-id', 'user-a');

    expect(response.status).toBe(200);
    expect(response.body).toEqual({ deleted: 2 });

    const list = await request(app.getHttpServer())
      .get('/items')
      .set('x-user-id', 'user-a');
    expect(list.body.map((item: { name: string }) => item.name).sort()).toEqual(
      ['bread', 'rice'],
    );
  });

  it('does nothing and reports no error when nothing is bought', async () => {
    await addItem('user-a', 'bread', false);

    const response = await request(app.getHttpServer())
      .delete('/items/bought')
      .set('x-user-id', 'user-a');

    expect(response.status).toBe(200);
    expect(response.body).toEqual({ deleted: 0 });

    const list = await request(app.getHttpServer())
      .get('/items')
      .set('x-user-id', 'user-a');
    expect(list.body).toHaveLength(1);
  });

  it('does nothing when the list is completely empty', async () => {
    const response = await request(app.getHttpServer())
      .delete('/items/bought')
      .set('x-user-id', 'user-a');

    expect(response.status).toBe(200);
    expect(response.body).toEqual({ deleted: 0 });
  });

  it('is routed as the bought endpoint, not as an item with id "bought"', async () => {
    await addItem('user-a', 'milk', true);

    const response = await request(app.getHttpServer())
      .delete('/items/bought')
      .set('x-user-id', 'user-a');

    // If DELETE /items/:id were declared first, this would be a 404 for an
    // item whose id is the literal string "bought".
    expect(response.status).toBe(200);
    expect(response.body).toEqual({ deleted: 1 });
  });

  it("does not touch another user's bought items (US-6)", async () => {
    await addItem('user-a', 'milk', true);
    await addItem('user-b', 'beer', true);

    const response = await request(app.getHttpServer())
      .delete('/items/bought')
      .set('x-user-id', 'user-a');

    expect(response.body).toEqual({ deleted: 1 });

    const otherList = await request(app.getHttpServer())
      .get('/items')
      .set('x-user-id', 'user-b');
    expect(otherList.body).toHaveLength(1);
  });

  it('requires an x-user-id header', async () => {
    const response = await request(app.getHttpServer()).delete('/items/bought');

    expect(response.status).toBe(401);
  });
});
