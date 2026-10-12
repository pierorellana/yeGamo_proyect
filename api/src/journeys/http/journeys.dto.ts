import { Type } from 'class-transformer';
import {
  IsDefined,
  IsEnum,
  IsISO8601,
  IsInt,
  IsNumber,
  IsUUID,
  Max,
  Min,
  ValidateIf,
  ValidateNested,
} from 'class-validator';

export enum JourneyTimeMode {
  LEAVE_NOW = 'LEAVE_NOW',
  DEPART_AT = 'DEPART_AT',
  ARRIVE_BY = 'ARRIVE_BY',
}

export enum JourneyPreference {
  BALANCED = 'BALANCED',
  FASTEST = 'FASTEST',
  LESS_WALKING = 'LESS_WALKING',
  FEWER_TRANSFERS = 'FEWER_TRANSFERS',
  RELIABLE = 'RELIABLE',
}

export class JourneyGeoPointDto {
  @IsDefined()
  @IsNumber({ allowInfinity: false, allowNaN: false })
  @Min(-90)
  @Max(90)
  lat!: number;

  @IsDefined()
  @IsNumber({ allowInfinity: false, allowNaN: false })
  @Min(-180)
  @Max(180)
  lon!: number;
}

export class JourneyPlanRequestDto {
  @IsDefined()
  @ValidateNested()
  @Type(() => JourneyGeoPointDto)
  origin!: JourneyGeoPointDto;

  @IsDefined()
  @ValidateNested()
  @Type(() => JourneyGeoPointDto)
  destination!: JourneyGeoPointDto;

  @IsDefined()
  @IsEnum(JourneyTimeMode)
  timeMode!: JourneyTimeMode;

  @ValidateIf((request: JourneyPlanRequestDto) => request.timeMode !== JourneyTimeMode.LEAVE_NOW)
  @IsDefined()
  @IsISO8601({ strict: true })
  time?: string | null;

  @IsEnum(JourneyPreference)
  preference = JourneyPreference.BALANCED;

  @IsInt()
  @Min(1)
  @Max(60)
  maxWalkMin = 12;

  @IsInt()
  @Min(0)
  @Max(60)
  extraSafetyMarginMin = 0;
}

export class JourneyPlanParamDto {
  @IsUUID('all')
  planId!: string;
}
