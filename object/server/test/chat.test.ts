import { strict as assert } from 'node:assert';
import { test } from 'node:test';
import { ForbiddenException, ServiceUnavailableException, UnauthorizedException } from '@nestjs/common';
import { ChatController } from '../src/care-agent/chat-controller';
import { ChatService } from '../src/care-agent/chat-service';
import { verifyAnswer } from '../src/care-agent/grounded-response';
import { ChatQueries } from '../src/care-api/chat-queries';

const result = { facts: [{ id: '42', date: '2026-10-21', level: 'high' }], citations: [{ kind: 'riskEvent' as const, id: '42', date: '2026-10-21', label: 'Risk event 42' }] };
const fake = (plan: any = [{ kind: 'events' }], answer: any = { paragraphs: ['On 2026-10-21 event 42 was high risk.'], citations: [{ kind: 'riskEvent', id: '42' }] }) => ({ plan: async () => plan, answer: async () => answer });
const setup = (model: any = fake()) => { let calls = 0; return { chat: new ChatService({ localToday: async () => '2026-10-21', run: async () => { calls++; return result; } } as any, model), calls: () => calls }; };
test('valid answer is grounded and all invented numbers and citations are rejected', async () => {
  assert.equal((await setup().chat.answer(1, 'What happened?', 'en', true)).outcome, 'answered');
  for (const answer of [
    { paragraphs: ['There were 99 events.'], citations: [{ kind: 'riskEvent', id: '42' }] },
    { paragraphs: ['There were two events.'], citations: [{ kind: 'riskEvent', id: '42' }] },
    { paragraphs: ['Event 42.'], citations: [{ kind: 'riskEvent', id: '999' }] },
    { paragraphs: ['Dementia was diagnosed.'], citations: [{ kind: 'riskEvent', id: '42' }] },
  ]) assert.equal((await setup(fake(undefined, answer)).chat.answer(1, 'What happened?', 'en', true)).outcome, 'unverified');
});
test('a citation cannot borrow numbers from another record', () => {
  const mixed = { facts: [{ id: '42', count: 1 }, { id: '99', count: 9 }], citations: [result.citations[0], { kind: 'riskEvent' as const, id: '99', label: '99' }] };
  assert.equal(verifyAnswer({ paragraphs: ['9 events.'], citations: [{ kind: 'riskEvent', id: '42' }] }, [mixed], 'en').outcome, 'unverified');
});
test('query limit, history setting and medical boundary precede access', async () => {
  let s = setup(fake(Array(4).fill({ kind: 'events' })));
  assert.equal((await s.chat.answer(1, 'What happened?', 'en', true)).outcome, 'unverified'); assert.equal(s.calls(), 0);
  s = setup(); assert.equal((await s.chat.answer(1, 'What happened?', 'en', false)).outcome, 'historyDisabled');
  assert.equal((await s.chat.answer(1, '是否患有痴呆？', 'zh', true)).outcome, 'medicalBoundary'); assert.equal(s.calls(), 0);
  assert.equal((await s.chat.answer(1, 'What happened near 31.2304, 121.4737?', 'en', true)).outcome, 'unverified');
  assert.equal(s.calls(), 0);
  assert.equal((await s.chat.answer(1, 'What happened on 2026-10-21?', 'en', true)).outcome, 'answered');
  assert.equal(s.calls(), 1);
});
test('controller enforces identity, validation and temporary failure', async () => {
  const auth = { require: async (token: string) => { if (!token) throw new UnauthorizedException(); if (token === 'elder') throw new ForbiddenException(); return { elderId: 1 }; } };
  const service = setup({ plan: async () => { throw new Error('timeout'); } }).chat;
  const controller = new ChatController(auth as any, service);
  await assert.rejects(controller.answer({ question: 'x', language: 'en', allowTripHistory: true }), UnauthorizedException);
  await assert.rejects(controller.answer({ question: 'x', language: 'en', allowTripHistory: true }, 'elder'), ForbiddenException);
  await assert.rejects(controller.answer({ question: 'x', language: 'en', allowTripHistory: true }, 'caregiver'), ServiceUnavailableException);
});
test('query filtering excludes false alarms and respects local dates', async () => {
  const data = { timezone: 'Asia/Shanghai', trips: [], risks: [
    { id: '1', openedAt: new Date('2026-10-20T18:00:00Z'), falseAlarm: true },
    { id: '42', openedAt: new Date('2026-10-20T18:00:00Z'), falseAlarm: false, escalatedAt: new Date('2026-10-20T19:00:00Z'), resolvedAt: null },
  ], observations: [], actions: [], calls: [] };
  const query = new ChatQueries({ data: async () => data } as any, { tracker: async () => ({ phase: 'home', processedThrough: new Date('2026-10-21T10:00:00Z'), historyReplay: true }) } as any);
  const got = await query.run(1, { kind: 'events' });
  assert.deepEqual(got.citations.map(c => [c.id, c.date]), [['42', '2026-10-21']]);
  assert.deepEqual((await query.run(1, { kind: 'events', level: 'high', to: '2026-10-20' })).citations, []);
  const current = await query.run(1, { kind: 'current' }, new Date('2026-10-21T11:00:00Z'));
  assert.deepEqual(current.evidence?.['statistic:current-2026-10-21'], {
    lastRecordedDate: '2026-10-21', phase: 'home', historyReplay: true,
    olderThanFiveMinutes: true, hasActiveRisk: true, hasActiveTrip: false,
  });
});
test('grouped records allow one citation without borrowing another record number', () => {
  const grouped = { facts: [{ id: '42', count: 1 }, { id: '99', count: 9 }], citations: [result.citations[0], { kind: 'riskEvent' as const, id: '99', label: '99' }], evidence: { 'riskEvent:42': { id: '42', count: 1 }, 'riskEvent:99': { id: '99', count: 9 } } };
  assert.equal(verifyAnswer({ paragraphs: ['1 event.'], citations: [{ kind: 'riskEvent', id: '42' }] }, [grouped], 'en').outcome, 'answered');
  assert.equal(verifyAnswer({ paragraphs: ['9 events.'], citations: [{ kind: 'riskEvent', id: '42' }] }, [grouped], 'en').outcome, 'unverified');
});
test('pattern fallback cannot exceed the three query budget', async () => {
  let count = 0;
  const service = new ChatService({ localToday: async () => '2026-10-21', run: async () => { count++; return result; } } as any,
    { plan: async () => Array(3).fill({ kind: 'events' }), answer: async () => { throw new Error('timeout'); } } as any);
  await assert.rejects(service.answer(1, 'What is the pattern?', 'en', true));
  assert.equal(count, 3);
});
