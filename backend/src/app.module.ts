import { Module } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { UserIdGuard } from './common/guards/user-id.guard';
import { FirebaseModule } from './firebase/firebase.module';
import { ItemsModule } from './items/items.module';

@Module({
  imports: [FirebaseModule, ItemsModule],
  providers: [{ provide: APP_GUARD, useClass: UserIdGuard }],
})
export class AppModule {}
