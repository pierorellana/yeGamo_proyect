import { IsInt, IsOptional, IsUUID, Max, Min } from 'class-validator';

export class NotificationQueryDto {
  @IsOptional()
  @IsInt()
  @Min(1)
  page = 1;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(100)
  pageSize = 20;
}

export class NotificationIdDto {
  @IsUUID('all')
  id!: string;
}
