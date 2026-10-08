import { DocumentSnapshot, Timestamp } from 'firebase-admin/firestore';
import { ItemDto } from './dto/item.dto';

interface ItemDocument {
  name: string;
  quantity: number;
  bought: boolean;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

export function toItemDto(snapshot: DocumentSnapshot): ItemDto {
  const data = snapshot.data() as ItemDocument;

  return {
    id: snapshot.id,
    name: data.name,
    quantity: data.quantity,
    bought: data.bought,
    createdAt: data.createdAt.toDate().toISOString(),
    updatedAt: data.updatedAt.toDate().toISOString(),
  };
}
