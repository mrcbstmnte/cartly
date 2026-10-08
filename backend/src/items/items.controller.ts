import { Controller, Get } from '@nestjs/common';
import { UserId } from '../common/decorators/user-id.decorator';
import { ItemsService } from './items.service';

@Controller('items')
export class ItemsController {
  constructor(private readonly items: ItemsService) {}

  @Get()
  list(@UserId() userId: string): Promise<unknown[]> {
    return this.items.list(userId);
  }
}
