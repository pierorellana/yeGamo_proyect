import { WorkerService } from '../../src/worker/application/worker.service';

describe('workers', () => {
  it('stays disabled unless explicitly forced', async () => {
    const worker = new WorkerService(
      { get: () => 'false' } as never,
      {} as never,
      {} as never,
      {} as never,
      {} as never,
      {} as never,
    );
    await expect(worker.runAlerts(new Date('2026-10-12T08:00:00Z'))).resolves.toEqual({ worker: 'alerts', enabled: false, processed: 0, ranAt: '2026-10-12T08:00:00.000Z' });
    await expect(worker.runRetention(new Date('2026-10-12T08:00:00Z'))).resolves.toMatchObject({ worker: 'retention', enabled: false, processed: 0 });
  });
});
