export interface WorkerRunResult {
  readonly worker: string;
  readonly enabled: boolean;
  readonly processed: number;
  readonly ranAt: string;
}

export interface NotificationDeliveryPort {
  deliverPending(now: Date): Promise<number>;
}

export const NOTIFICATION_DELIVERY_PORT = Symbol('NOTIFICATION_DELIVERY_PORT');
