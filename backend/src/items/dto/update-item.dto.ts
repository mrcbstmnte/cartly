import { IsBoolean } from 'class-validator';

export class UpdateItemDto {
  @IsBoolean({ message: 'bought must be a boolean' })
  bought!: boolean;
}
