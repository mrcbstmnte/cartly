import { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { clearFirestore, createTestApp } from './utils/firestore-test-helpers';

describe('identity enforcement (US-6)', () => {
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

  it('rejects a request with no x-user-id header', async () => {
    const response = await request(app.getHttpServer()).get('/items');

    expect(response.status).toBe(401);
    expect(response.body.message).toContain('x-user-id');
  });

  it('rejects a blank x-user-id header', async () => {
    const response = await request(app.getHttpServer())
      .get('/items')
      .set('x-user-id', '   ');

    expect(response.status).toBe(401);
  });

  it('accepts a request with an x-user-id header', async () => {
    const response = await request(app.getHttpServer())
      .get('/items')
      .set('x-user-id', 'user-a');

    expect(response.status).toBe(200);
    expect(response.body).toEqual([]);
  });
});
