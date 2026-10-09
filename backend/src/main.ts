// Must stay the first import: it loads backend/.env into process.env before the
// Firestore provider factory reads FIREBASE_PROJECT_ID at module load.
import 'dotenv/config';
import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  // The Flutter app may run in Chrome during review; without CORS the browser
  // blocks every request and the app looks broken for reasons unrelated to it.
  app.enableCors();

  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }),
  );

  await app.listen(process.env.PORT ?? 3000);
}

void bootstrap();
