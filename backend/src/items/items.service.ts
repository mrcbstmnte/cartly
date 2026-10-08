import { Inject, Injectable, NotFoundException } from '@nestjs/common';
import {
  CollectionReference,
  FieldValue,
  Firestore,
} from 'firebase-admin/firestore';
import { FIRESTORE } from '../firebase/firestore.provider';
import { CreateItemDto } from './dto/create-item.dto';
import { ItemDto } from './dto/item.dto';
import { toItemDto } from './item.mapper';

@Injectable()
export class ItemsService {
  constructor(@Inject(FIRESTORE) private readonly db: Firestore) {}

  // Every read and write goes through this. The user ID is part of the path,
  // so there is no query in this service that can reach another user's data.
  private itemsRef(userId: string): CollectionReference {
    return this.db.collection('users').doc(userId).collection('items');
  }

  async list(userId: string): Promise<ItemDto[]> {
    const snapshot = await this.itemsRef(userId)
      .orderBy('bought', 'asc')
      .orderBy('createdAt', 'desc')
      .get();

    return snapshot.docs.map(toItemDto);
  }

  async create(userId: string, dto: CreateItemDto): Promise<ItemDto> {
    const now = FieldValue.serverTimestamp();

    // bought is set here, not taken from the client: a new item always
    // starts unbought (US-2).
    const ref = await this.itemsRef(userId).add({
      name: dto.name,
      quantity: dto.quantity,
      bought: false,
      createdAt: now,
      updatedAt: now,
    });

    const snapshot = await ref.get();
    return toItemDto(snapshot);
  }

  async setBought(
    userId: string,
    id: string,
    bought: boolean,
  ): Promise<ItemDto> {
    const ref = this.itemsRef(userId).doc(id);
    const existing = await ref.get();

    // Because userId is in the path, this is also the ownership check:
    // another user's item simply is not here.
    if (!existing.exists) {
      throw new NotFoundException(`Item ${id} not found`);
    }

    await ref.update({ bought, updatedAt: FieldValue.serverTimestamp() });

    const updated = await ref.get();
    return toItemDto(updated);
  }
}
