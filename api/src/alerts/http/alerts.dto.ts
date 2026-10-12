import { IsISO8601, IsOptional, IsUUID } from 'class-validator';

export class LeaveAlertDto {
  @IsOptional()
  @IsUUID('all')
  commuteProfileId?: string;

  @IsOptional()
  @IsUUID('all')
  journeyPlanId?: string;

  @IsISO8601({ strict: true })
  scheduledFor!: string;
}

export class LeaveAlertIdDto {
  @IsUUID('all')
  id!: string;
}
