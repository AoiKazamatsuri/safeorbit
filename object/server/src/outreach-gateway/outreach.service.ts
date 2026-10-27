import { Inject, Injectable, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { CareEvents, CareStore, PushJob, RiskRecords } from '../care-api/public';
import { riskPush } from './push-payload';
import { PUSH_SENDER, PushSender } from './push-sender';

// Outreach gateway (C2 edges 10, 11, 13): on "state changed" it sends the caregiver notifications the care
// agent decided and writes each delivery result back through the care API. It decides nothing itself.
@Injectable()
export class OutreachService implements OnModuleInit, OnModuleDestroy {
  private queue: Promise<void> = Promise.resolve();

  constructor(private readonly risks: RiskRecords, private readonly store: CareStore, private readonly events: CareEvents,
    @Inject(PUSH_SENDER) private readonly sender: PushSender) {}

  onModuleInit(): void {
    this.events.onStateChanged(async ({ elderId, type }) => {
      if (type === 'risk') void this.enqueue(() => this.deliver(elderId));
    });
  }

  onModuleDestroy(): void {
    this.sender.close();
  }

  enqueue(work: () => Promise<void>): Promise<void> {
    const run = this.queue.then(work);
    this.queue = run.catch(error => console.error('Outreach failed:', (error as Error).message));
    return run;
  }

  async deliver(elderId: number): Promise<void> {
    const jobs = await this.risks.claimPushJobs(elderId);
    if (!jobs.length) return;
    const recipients = this.sender.configured ? await this.risks.pushRecipients(elderId) : [];
    const { elder } = await this.store.household(elderId);
    for (const job of jobs) await this.send(elderId, job, recipients, elder.callName);
  }

  private async send(elderId: number, job: PushJob, recipients: Array<{ deviceId: string; pushToken: string }>, callName: string): Promise<void> {
    if (!this.sender.configured) {
      return this.risks.recordPushOutcome(elderId, job.id, 'notConfigured', [{ deviceId: null, result: 'notConfigured', detail: 'APNs key not configured' }]);
    }
    if (!recipients.length) {
      return this.risks.recordPushOutcome(elderId, job.id, 'noRecipient',
        [{ deviceId: null, result: 'noRecipient', detail: 'No family phone has registered a push token' }]);
    }
    const message = riskPush(job.kind, job.details, job.riskEventId, callName);
    const deliveries = [];
    for (const r of recipients) {
      const sent = await this.sender.send(r.pushToken, message);
      deliveries.push({ deviceId: r.deviceId, result: sent.result,
        detail: [sent.status, sent.reason].filter(v => v !== undefined).join(' ') || null });
    }
    await this.risks.recordPushOutcome(elderId, job.id, deliveries.some(d => d.result === 'accepted') ? 'sent' : 'failed', deliveries);
  }
}
