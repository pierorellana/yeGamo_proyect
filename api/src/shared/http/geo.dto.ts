import { IsDefined, IsNumber, Max, Min } from 'class-validator';

export class GeoPointDto {
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
