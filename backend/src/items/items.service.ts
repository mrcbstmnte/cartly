import { Inject, Injectable } from '@nestjs/common';
import { CollectionReference, Firestore } from 'firebase-admin/firestore';
import { FIRESTORE } from '../firebase/firestore.provider';

@Injectable()
export class ItemsService {
  constructor(@Inject(FIRESTORE) private readonly db: Firestore) {}

  // Every read and write goes through this. The user ID is part of the path,
  // so there is no query in this service that can reach another user's data.
  private itemsRef(userId: string): CollectionReference {
    return this.db.collection('users').doc(userId).collection('items');
  }

  async list(_userId: string): Promise<unknown[]> {
    return Promise.resolve([]);
  }
}
