import { Inject, Injectable, NotFoundException } from '@nestjs/common';
import {
  CollectionReference,
  FieldValue,
  Firestore,
  GrpcStatus,
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

    try {
      await ref.update({ bought, updatedAt: FieldValue.serverTimestamp() });
    } catch (error) {
      // TOCTOU: the item existed at the check above but may have been
      // deleted before this update reached Firestore. Unlike delete(),
      // update() is not idempotent on a missing document — it throws
      // NOT_FOUND — so without this catch, that race would surface as an
      // unhandled 500 instead of the same 404 the existence check gives.
      if (isNotFoundError(error)) {
        throw new NotFoundException(`Item ${id} not found`);
      }
      throw error;
    }

    const updated = await ref.get();
    return toItemDto(updated);
  }

  // Firestore has no server-side delete-by-query, so this is one query plus
  // one batched write. That is the point of US-5: a single commit instead of
  // N sequential round trips.
  async clearBought(userId: string): Promise<{ deleted: number }> {
    const ref = this.itemsRef(userId);
    const snapshot = await ref.where('bought', '==', true).get();

    if (snapshot.empty) {
      return { deleted: 0 };
    }

    // A Firestore batch caps at 500 writes. A shopping list will not reach
    // that, but chunking costs three lines and removes the cliff.
    const BATCH_LIMIT = 450;
    for (let i = 0; i < snapshot.docs.length; i += BATCH_LIMIT) {
      const batch = this.db.batch();
      for (const doc of snapshot.docs.slice(i, i + BATCH_LIMIT)) {
        batch.delete(doc.ref);
      }
      await batch.commit();
    }

    return { deleted: snapshot.size };
  }

  async remove(userId: string, id: string): Promise<{ id: string }> {
    const ref = this.itemsRef(userId).doc(id);
    const existing = await ref.get();

    // Firestore deletes are idempotent and succeed on a missing document,
    // so the existence check is what turns a no-op into the clear error
    // US-4 asks for.
    if (!existing.exists) {
      throw new NotFoundException(`Item ${id} not found`);
    }

    await ref.delete();
    return { id };
  }
}

// Matches on the Firestore gRPC error code (5 / NOT_FOUND), not the message,
// so unrelated failures are never mistaken for the race above and
// propagate untouched.
function isNotFoundError(error: unknown): boolean {
  return (
    typeof error === 'object' &&
    error !== null &&
    'code' in error &&
    (error as { code?: number }).code === GrpcStatus.NOT_FOUND
  );
}
