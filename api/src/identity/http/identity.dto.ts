import { Type } from 'class-transformer';
import {
  IsArray,
  IsBoolean,
  IsEmail,
  IsEnum,
  IsInt,
  IsISO8601,
  IsNotEmpty,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';

export class PreferencesDto {
  @IsOptional()
  @IsString()
  @MaxLength(2)
  language?: string;

  @IsOptional()
  @IsEnum(['BALANCED', 'FASTEST', 'LESS_WALKING', 'FEWER_TRANSFERS', 'RELIABLE'])
  defaultPreference?: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(60)
  maxWalkMin?: number;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(60)
  extraSafetyMarginMin?: number;

  @IsOptional()
  @IsBoolean()
  locationConsent?: boolean;
}

export class DeviceInstallationDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(160)
  installationId!: string;

  @IsEnum(['IOS', 'ANDROID'])
  platform!: 'IOS' | 'ANDROID';

  @IsString()
  @IsNotEmpty()
  pushToken!: string;

  @IsOptional()
  @IsString()
  @MaxLength(40)
  appVersion?: string;
}

export class GuestMigrationDto {
  @IsString()
  @IsNotEmpty()
  clientDataVersion!: string;

  @IsArray()
  items!: readonly Record<string, unknown>[];
}

export class DeviceIdDto {
  @IsUUID('all')
  id!: string;
}

