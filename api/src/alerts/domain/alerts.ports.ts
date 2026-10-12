export interface LeaveAlert {
  readonly id: string;
  readonly scheduledFor: string;
  readonly status: 'SCHEDULED' | 'TRIGGERED' | 'CANCELLED' | 'FAILED' | 'EXPIRED';
}

export interface LeaveAlertInput {
  readonly commuteProfileId?: string;
  readonly journeyPlanId?: string;
  readonly scheduledFor: string;
}

export interface LeaveAlertRepository {
  create(userId: string, input: LeaveAlertInput, idempotencyKey: string): Promise<LeaveAlert>;
  journeyPlanBelongsToUser(userId: string, id: string): Promise<boolean>;
  delete(userId: string, id: string): Promise<boolean>;
  due(now: Date): Promise<Array<LeaveAlert & { userId: string }>>;
  markTriggered(id: string): Promise<void>;
}

export const LEAVE_ALERT_REPOSITORY = Symbol('LEAVE_ALERT_REPOSITORY');
