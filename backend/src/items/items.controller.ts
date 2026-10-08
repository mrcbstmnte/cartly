import { Body, Controller, Get, Param, Patch, Post } from '@nestjs/common';
import { UserId } from '../common/decorators/user-id.decorator';
import { CreateItemDto } from './dto/create-item.dto';
import { ItemDto } from './dto/item.dto';
import { UpdateItemDto } from './dto/update-item.dto';
import { ItemsService } from './items.service';

@Controller('items')
export class ItemsController {
  constructor(private readonly items: ItemsService) {}

  @Get()
  list(@UserId() userId: string): Promise<ItemDto[]> {
    return this.items.list(userId);
  }

  @Post()
  create(
    @UserId() userId: string,
    @Body() dto: CreateItemDto,
  ): Promise<ItemDto> {
    return this.items.create(userId, dto);
  }

  @Patch(':id')
  setBought(
    @UserId() userId: string,
    @Param('id') id: string,
    @Body() dto: UpdateItemDto,
  ): Promise<ItemDto> {
    return this.items.setBought(userId, id, dto.bought);
  }
}
