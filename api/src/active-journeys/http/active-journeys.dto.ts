import { IsInt, IsISO8601, IsOptional, IsUUID, Min, ValidateNested } from 'class-validator';
import { Type } from 'class-transformer';
import { GeoPointDto } from '../../shared/http/geo.dto';

export class ActiveJourneyStartParamsDto {
  @IsUUID('all')
  planId!: string;

  @IsUUID('all')
  optionId!: string;
}

export class ActiveJourneyIdDto {
  @IsUUID('all')
  id!: string;
}

export class JourneyProgressDto {
  @IsOptional()
  @IsInt()
  @Min(0)
  currentLegIndex?: number;

  @IsOptional()
  @ValidateNested()
  @Type(() => GeoPointDto)
  location?: GeoPointDto;

  @IsOptional()
  @IsISO8601({ strict: true })
  occurredAt?: string;
}
