// Push adapter port (architecture principle 6): the outreach gateway talks to this, never to APNs directly,
// so tests use a double and another provider only needs another adapter.
export interface PushMessage {
  payload: Record<string, unknown>;   // the JSON body, including "aps"
  timeSensitive: boolean;
  threadId?: string;
}
export interface PushResult {
  result: 'accepted' | 'rejected' | 'error';
  status?: number;                    // HTTP status from the provider
  reason?: string;                    // provider reason, e.g. "BadDeviceToken"; never key material
}
export interface PushSender {
  readonly configured: boolean;
  send(deviceToken: string, message: PushMessage): Promise<PushResult>;
  close(): void;
}
export const PUSH_SENDER = Symbol('PUSH_SENDER');
