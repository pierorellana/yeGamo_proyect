import { Type } from 'class-transformer';
import {
  IsDefined,
  IsInt,
  IsNumber,
  IsUUID,
  Max,
  Min,
} from 'class-validator';

export class NearbyStopsQueryDto {
  @Type(() => Number)
  @IsDefined()
  @IsNumber({ allowInfinity: false, allowNaN: false })
  @Min(-90)
  @Max(90)
  lat!: number;

  @Type(() => Number)
  @IsDefined()
  @IsNumber({ allowInfinity: false, allowNaN: false })
  @Min(-180)
  @Max(180)
  lon!: number;

  @Type(() => Number)
  @IsInt()
  @Min(50)
  @Max(3000)
  radiusM = 800;
}

export class UuidParamDto {
  @IsUUID('all')
  id!: string;
}

export class StopIdParamDto {
  @IsUUID('all')
  stopId!: string;
}

export class RouteIdParamDto {
  @IsUUID('all')
  routeId!: string;
}
