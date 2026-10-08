import { Global, Module } from '@nestjs/common';
import { FIRESTORE, firestoreProvider } from './firestore.provider';

@Global()
@Module({
  providers: [firestoreProvider],
  exports: [FIRESTORE],
})
export class FirebaseModule {}
