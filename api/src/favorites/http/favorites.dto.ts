import { Type } from 'class-transformer';
import { IsNotEmpty, IsString, MaxLength, ValidateNested } from 'class-validator';
import { IsUUID } from 'class-validator';
import { GeoPointDto } from '../../shared/http/geo.dto';

export class FavoritePlaceDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(120)
  label!: string;

  @ValidateNested()
  @Type(() => GeoPointDto)
  location!: GeoPointDto;
}

export class FavoritePlaceIdDto {
  @IsUUID('all')
  id!: string;
}
