import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { AppModule } from '../../src/app.module';

const PROJECT_ID = process.env.FIREBASE_PROJECT_ID ?? 'cartly-dev';

export async function createTestApp(): Promise<INestApplication> {
  const moduleRef = await Test.createTestingModule({
    imports: [AppModule],
  }).compile();

  const app = moduleRef.createNestApplication();

  // Must mirror main.ts, or e2e tests would exercise a different pipeline
  // than production and validation bugs would slip through.
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }),
  );

  await app.init();
  return app;
}

export async function clearFirestore(): Promise<void> {
  const host = process.env.FIRESTORE_EMULATOR_HOST;
  if (!host) {
    throw new Error(
      'FIRESTORE_EMULATOR_HOST is not set. Run tests via "npm run test:e2e".',
    );
  }

  const response = await fetch(
    `http://${host}/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`,
    { method: 'DELETE' },
  );

  if (!response.ok) {
    throw new Error(`Failed to clear emulator data: ${response.status}`);
  }
}
