import { Type } from 'class-transformer';
import {
  IsDefined,
  IsNumber,
  IsString,
  Length,
  Max,
  Min,
  ValidateIf,
} from 'class-validator';

export class SearchPlacesQueryDto {
  @IsString()
  @Length(2, 160)
  q!: string;

  @ValidateIf((query: SearchPlacesQueryDto) => query.lon !== undefined)
  @Type(() => Number)
  @IsNumber({ allowInfinity: false, allowNaN: false })
  @Min(-90)
  @Max(90)
  lat?: number;

  @ValidateIf((query: SearchPlacesQueryDto) => query.lat !== undefined)
  @Type(() => Number)
  @IsNumber({ allowInfinity: false, allowNaN: false })
  @Min(-180)
  @Max(180)
  lon?: number;
}

export class ReversePlaceQueryDto {
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
}
