import { strict as assert } from 'node:assert';
import { test } from 'node:test';
import { BadRequestException, ForbiddenException, ServiceUnavailableException, UnauthorizedException } from '@nestjs/common';
import { ChatController } from '../src/care-agent/chat-controller';
import { ChatService } from '../src/care-agent/chat-service';
import { verifyAnswer } from '../src/care-agent/grounded-response';
import { ChatQueries, ChatQuery } from '../src/care-api/chat-queries';
import october from '../src/care-api/october-records.json';

const result = { facts: [{ id: '42', date: '2026-10-21', level: 'high' }], citations: [{ kind: 'riskEvent' as const, id: '42', date: '2026-10-21', label: 'Risk event 42' }] };
const fake = (plan: any = [{ kind: 'events' }], answer: any = { paragraphs: ['On 2026-10-21 event 42 was high risk.'], citations: [{ kind: 'riskEvent', id: '42' }] }) => ({ plan: async () => plan, answer: async () => answer });
const setup = (model: any = fake()) => { let calls = 0; return { chat: new ChatService({ localToday: async () => '2026-10-21', run: async () => { calls++; return result; } } as any, model), calls: () => calls }; };

test('explicit October questions use the shared month, local dates, and existing iOS wire types', async () => {
  const empty = { timezone: 'Asia/Shanghai', trips: [], risks: [], observations: [], actions: [], calls: [] };
  const reads: number[] = [];
  const chat = new ChatService(new ChatQueries({ data: async (id: number) => { reads.push(id); return empty; } } as any, {} as any),
    { plan: async () => assert.fail('explicit October needs no model') } as any);
  const ask = (q: string, lang: 'zh' | 'en' = 'zh') => chat.answer(29, q, lang, true);
  const trained = october.trends;
  const overview = await ask('十月的情况怎么样？');
  assert.equal(overview.outcome, 'answered');
  assert.match(overview.paragraphs[0], new RegExp(`${trained.totals.tripCount.current} 次出行、${trained.totals.riskEventCount.current} 次风险事件、${trained.metrics.highRisk.current} 次高风险事件、${trained.deviations.current} 次路线偏离`));
  assert.deepEqual(overview.recordContext, [{ kind: 'compare', month: '2026-10' }]);
  assert.deepEqual(overview.citations.map(c => [c.kind, c.startDate, c.endDate]), [['statistic', '2026-10-01', '2026-10-31']]);
  const high = await ask('When were the high-risk events in October 2026?', 'en');
  assert.match(high.paragraphs.join(' '), /2 high-risk events.*2026-10-09, 2026-10-21/);
  const followup = await chat.answer(29, '其中哪些天有路线偏离？', 'zh', true, [], overview.recordContext);
  assert.match(followup.paragraphs.join(' '), /3 次路线偏离.*2026-10-05、2026-10-15、2026-10-28/);
  for (const q of ['十月九日的情况？', '10月9号的出行情况？', 'What happened on October 9th?', 'What happened on 2026-10-09?']) {
    const day = await ask(q);
    assert.equal(day.citations[0].startDate, '2026-10-09');
    assert.equal(day.citations[0].endDate, '2026-10-09');
    assert.equal(day.recordContext, undefined);
    assert.match(day.paragraphs[0], /1 次出行、1 次风险事件、1 次高风险事件、0 次路线偏离/);
  }
  assert.match((await ask('2026 年 10 月 4 日有出行吗？')).paragraphs[0], /0 次出行/);
  const before = reads.length;
  assert.equal((await chat.answer(29, 'How many trips in October?', 'en', false)).outcome, 'historyDisabled');
  assert.equal(reads.length, before);
  assert.ok(reads.every(id => id === 29));
});

test('the October merge deduplicates the old demo replay only for its reserved household', async () => {
  const start = new Date('2026-10-09T01:03:59Z'), end = new Date('2026-10-09T02:00:00Z');
  const extra = new Date('2026-10-09T08:00:00Z');
  const data = { timezone: 'Asia/Shanghai',
    trips: [{ id: '81', startedAt: start, endedAt: end }, { id: '82', startedAt: extra, endedAt: extra }],
    risks: [{ id: '201', tripId: '81', falseAlarm: false, openedAt: start, escalatedAt: end },
      { id: '202', tripId: '82', falseAlarm: true, openedAt: extra }],
    observations: [{ key: 'a', riskEventId: '201', kind: 'deviation', startedAt: start },
      { key: 'b', riskEventId: '202', kind: 'deviation', startedAt: extra }],
    actions: [], calls: [],
  };
  const access: number[] = [];
  const queries = new ChatQueries({ data: async (id: number) => { access.push(id); return data; } } as any, {} as any);
  const chat = new ChatService(queries, {} as any);
  const demo = await chat.answer(1, '10月概况', 'zh', true);
  assert.match(demo.paragraphs[0], /25 次出行、5 次风险事件、2 次高风险事件、3 次路线偏离/);
  const ordinary = await chat.answer(8, '10月概况', 'zh', true);
  assert.match(ordinary.paragraphs[0], /26 次出行、6 次风险事件、3 次高风险事件、4 次路线偏离/);
  assert.deepEqual(access, [1, 8]);
});

test('other months, years, mixed periods and general topics stay on the existing query paths', async () => {
  const calls: ChatQuery[] = [];
  const queries = { localToday: async () => '2026-11-18', run: async (_: number, q: ChatQuery) => { calls.push(q); return result; } };
  const chat = new ChatService(queries as any, fake() as any);
  for (const question of ['How many trips in October 2025?', '去年十月的高风险情况', 'Which trips in November?',
    'Compare risk in October and November', '今年十一月有几次风险？', 'Tell a joke about October']) {
    assert.equal((await chat.answer(8, question, 'en', true)).outcome, 'answered');
  }
  assert.equal(calls.length, 6);
  assert.ok(calls.every(query => query.kind === 'events'));
});
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
  assert.equal((await s.chat.answer(1, 'What happened on 2026-11-21?', 'en', true)).outcome, 'answered');
  assert.equal(s.calls(), 1);
});
test('controller enforces identity, validation and temporary failure', async () => {
  const auth = { require: async (token: string) => { if (!token) throw new UnauthorizedException(); if (token === 'elder') throw new ForbiddenException(); return { elderId: 1 }; } };
  const service = setup({ plan: async () => { throw new Error('timeout'); } }).chat;
  const controller = new ChatController(auth as any, service);
  await assert.rejects(controller.answer({ question: 'x', language: 'en', allowTripHistory: true }), UnauthorizedException);
  await assert.rejects(controller.answer({ question: 'x', language: 'en', allowTripHistory: true }, 'elder'), ForbiddenException);
  await assert.rejects(controller.answer({ question: 'x', language: 'en', allowTripHistory: true }, 'caregiver'), ServiceUnavailableException);
  const request = { question: 'x', language: 'en', allowTripHistory: true };
  for (const invalid of [
    { history: Array(9).fill({ role: 'user', text: 'x' }) },
    { history: [{ role: 'assistant', text: 'x'.repeat(4001) }] },
    { history: [{ role: 'system', text: 'x' }] },
    { history: [{ role: 'user', text: 'x', address: 'x' }] },
    { recordContext: Array(4).fill({ kind: 'current' }) },
    { recordContext: [{ kind: 'events', from: '2026-02-29' }] },
    { recordContext: [{ kind: 'activity', elderId: '7' }] },
    { recordContext: [{ kind: 'compare', metric: 'tripCount' }] },
    { recordContext: [{ kind: 'events', metric: 'riskEvents' }] },
  ]) await assert.rejects(controller.answer({ ...request, ...invalid }, 'caregiver'), BadRequestException);
  await assert.rejects(controller.answer({ ...request, recordContext: [{ kind: 'compare', metric: 'riskEvents' }] }, 'caregiver'), ServiceUnavailableException);
});
test('query filtering excludes false alarms and respects local dates', async () => {
  const data = { timezone: 'Asia/Shanghai', trips: [], risks: [
    { id: '1', openedAt: new Date('2026-10-20T18:00:00Z'), falseAlarm: true },
    { id: '42', openedAt: new Date('2026-10-20T18:00:00Z'), falseAlarm: false, escalatedAt: new Date('2026-10-20T19:00:00Z'), resolvedAt: null },
  ], observations: [], actions: [], calls: [] };
  const query = new ChatQueries({ data: async () => data } as any, {
    tracker: async () => ({ phase: 'home', processedThrough: new Date('2026-10-21T09:00:00Z') }),
    latestPoints: async () => [{ sampledAt: new Date('2026-10-21T10:00:00Z'), historyReplay: true, latitude: 31.2304, longitude: 121.4737 }],
  } as any);
  const got = await query.run(1, { kind: 'events' });
  assert.deepEqual(got.citations.map(c => [c.id, c.date]), [['42', '2026-10-21']]);
  assert.deepEqual((await query.run(1, { kind: 'events', level: 'high', to: '2026-10-20' })).citations, []);
  const current = await query.run(1, { kind: 'current' }, new Date('2026-10-21T11:00:00Z'));
  assert.deepEqual(current.evidence?.['statistic:current-2026-10-21'], {
    lastRecordedDate: '2026-10-21', lastRecordedTime: '18:00', phase: null, historyReplay: true,
    olderThanFiveMinutes: true, hasActiveRisk: true, hasActiveTrip: false,
  });
  assert.doesNotMatch(JSON.stringify(current), /latitude|longitude|31\.2304|121\.4737/);
});
test('latest risk date questions keep older history and only apply an explicitly requested risk level', async () => {
  const risk = (id: string, day: string, high = false, falseAlarm = false, tripId: string | null = null) => {
    const openedAt = new Date(day + 'T10:00:00Z');
    return { id, openedAt, escalatedAt: high ? openedAt : null, resolvedAt: null, falseAlarm, tripId };
  };
  const now = new Date('2026-11-18T10:00:00Z');
  const tripId = '17';
  const data = { timezone: 'Asia/Shanghai', risks: [
    risk('41', '2026-11-10', true), risk('42', '2026-11-12', false, false, tripId), risk('43', '2026-11-13', true, true),
  ], trips: [{ id: tripId, startedAt: new Date('2026-11-11T14:30:00Z') }], actions: [], observations: [] };
  const queries = new ChatQueries({ data: async () => data } as any,
    { household: async () => ({ elder: { timezone: data.timezone } }) } as any);
  const chat = new ChatService({
    run: (id: number, query: ChatQuery) => queries.run(id, query, now),
    localToday: (id: number) => queries.localToday(id, now),
  } as ChatQueries, {
    plan: async () => [{ kind: 'events', from: '2026-11-01', to: '2026-11-09', level: 'high' }],
    answer: async () => assert.fail('Latest risk date should be read from the matching record'),
  } as any);
  const recent = await chat.answer(1, '最近一次风险事件是什么时候', 'zh', true);
  assert.equal(recent.outcome, 'answered');
  assert.deepEqual(recent.paragraphs, ['最近一次风险事件发生在2026-11-12。']);
  assert.deepEqual(recent.citations.map(c => c.id), ['42']);
  assert.equal(verifyAnswer({
    paragraphs: ['最近一次风险事件发生在2026-10-21。同日还发生了两次事件。'],
    citations: [{ kind: 'riskEvent', id: '42' }],
  }, [result], 'zh').outcome, 'unverified');
  const high = await chat.answer(1, 'When was the last high-risk event?', 'en', true);
  assert.equal(high.outcome, 'answered');
  assert.deepEqual(high.paragraphs, ['The last high-risk event occurred on 2026-11-10.']);
  assert.deepEqual(high.citations.map(c => c.id), ['41']);
  const trip = await chat.answer(1, '最近一次风险出行是什么时候？', 'zh', true);
  assert.deepEqual(trip.paragraphs, ['最近一次风险出行开始于2026-11-11。']);
  assert.deepEqual(trip.citations.map(c => [c.kind, c.id]), [['trip', tripId]]);
  assert.equal((await chat.answer(1, '11月最近一次高风险事件是什么时候？', 'zh', true)).outcome, 'unverified');
});

test('latest questions include the shared October records for a family without risk history', async () => {
  let reads = 0;
  const data = { timezone: 'Asia/Shanghai', trips: [], risks: [], observations: [], actions: [], calls: [] };
  const queries = new ChatQueries({ data: async () => { reads++; return data; } } as any, {} as any);
  const now = new Date('2026-11-18T10:00:00Z');
  const chat = new ChatService({
    run: (id: number, query: ChatQuery) => queries.run(id, query, now),
  } as ChatQueries, { plan: async () => assert.fail('Use the literal latest-risk question') } as any);
  const high = await chat.answer(29, 'When was the last high-risk event?', 'en', true);
  assert.deepEqual(high.paragraphs, ['The last high-risk event occurred on 2026-10-21.']);
  assert.deepEqual(high.recordContext, [{ kind: 'events', latest: true, level: 'high' }]);
  assert.deepEqual(high.citations.map(c => [c.kind, c.startDate, c.endDate]), [['statistic', '2026-10-21', '2026-10-21']]);
  const trip = await chat.answer(29, '最近一次风险出行是什么时候？', 'zh', true);
  assert.deepEqual(trip.paragraphs, ['最近一次风险出行开始于2026-10-28。']);
  assert.equal(trip.recordContext, undefined);
  assert.equal((await chat.answer(29, '最近一次风险出行是什么时候？', 'zh', false)).outcome, 'historyDisabled');
  assert.equal(reads, 2);
});

test('the assistant introduces its care role in both languages without querying records', async () => {
  const chat = new ChatService({ run: async () => assert.fail('Identity needs no records') } as any,
    { plan: async () => assert.fail('Identity needs no model') } as any);
  const zh = await chat.answer(29, '你是谁？', 'zh', false);
  assert.equal(zh.outcome, 'general');
  assert.match(zh.paragraphs[0], /^我是 SafeOrbit 的照护助手/);
  assert.deepEqual(zh.citations, []);
  const en = await chat.answer(29, 'Who are you?', 'en', true);
  assert.match(en.paragraphs[0], /^I’m SafeOrbit’s care assistant/);
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

test('general chat uses only the supplied conversation and is available with records switched off', async () => {
  const calls: unknown[][] = [];
  const service = new ChatService({
    localToday: async () => { throw new Error('Care database unavailable'); },
    run: async () => assert.fail('General chat must not read care records'),
  } as any, {
    plan: async (...args: unknown[]) => {
      calls.push(args);
      const [question, language, , history] = args;
      const paragraphs = language === 'zh'
        ? (question === '短一点' ? ((history as unknown[]).length ? ['谢谢你！'] : ['想缩短哪一段？']) : ['谢谢你今天来帮忙。'])
        : ['Thank you for your help.'];
      return { intent: 'general', paragraphs };
    },
  } as any);
  const first = await service.answer(1, '写一条感谢短信', 'zh', false);
  assert.equal(first.outcome, 'general');
  const history = [{ role: 'user' as const, text: '写一条感谢短信' }, { role: 'assistant' as const, text: first.paragraphs[0] }];
  const revised = await service.answer(1, '短一点', 'zh', false, history, [{ kind: 'riskCount' }]);
  assert.deepEqual(revised, { outcome: 'general', paragraphs: ['谢谢你！'], citations: [] });
  assert.deepEqual(calls[1], ['短一点', 'zh', undefined, history, [], false]);
  assert.deepEqual((await service.answer(1, '短一点', 'zh', false)).paragraphs, ['想缩短哪一段？']);
  assert.deepEqual((await service.answer(1, 'Write a thank-you text', 'en', true)).paragraphs, ['Thank you for your help.']);
});

test('question and history screening runs before sending text to the cloud planner', async () => {
  let plannerCalls = 0;
  const service = new ChatService({} as any, {
    plan: async (_question: string, _language: string, _today: unknown, history: unknown) => {
      plannerCalls++;
      assert.deepEqual(history, []);
      return { intent: 'general', paragraphs: ['Hello.'] };
    },
  } as any);
  for (const text of ['See https://example.com/path', 'token = example-private', 'Contact me at (212) 555-0100',
    'The position is 31.2304，121.4737', 'Mail me at resident@example.com', '住在桂花路25号']) {
    assert.equal((await service.answer(1, text, 'en', false)).outcome, 'unverified');
  }
  assert.equal(plannerCalls, 0);
  const response = await service.answer(1, 'Please say hello', 'en', false, [
    { role: 'user', text: 'Contact me at １３８００００００００' },
    { role: 'assistant', text: 'I can use your number.' },
  ]);
  assert.equal(response.outcome, 'general');
  assert.equal(plannerCalls, 1);
});

test('cumulative risk count covers all matching events, excludes false alarms, and combines with local age', async () => {
  const data = { timezone: 'Asia/Shanghai', trips: [], risks: Array.from({ length: 26 }, (_, index) => ({
    id: String(index + 1), openedAt: new Date('2026-10-01T01:00:00Z'), falseAlarm: index === 25,
  })), observations: [], actions: [], calls: [] };
  const queries = new ChatQueries({ data: async () => data } as any, {} as any);
  const now = new Date('2026-11-09T11:00:00Z');
  const calls: ChatQuery[] = [];
  const service = new ChatService({
    run: async (elderId: number, query: ChatQuery) => {
      calls.push(query);
      return queries.run(elderId, query, now);
    },
  } as any, {
    plan: async () => assert.fail('The direct count and local age request need no model'),
    answer: async () => assert.fail('Direct counts use the complete read model'),
  } as any);
  assert.equal((await queries.run(1, { kind: 'events' }, now)).citations.length, 20);
  const question = '老人多少岁了？目前总共出现过多少次风险事件？';
  const response = await service.answer(1, question, 'zh', true);
  assert.deepEqual(response, {
    outcome: 'answered',
    paragraphs: ['累计记录 25 次风险事件（已排除误报）。'],
    citations: [{ kind: 'statistic', id: 'risk-count', label: '累计风险统计', startDate: '2026-10-01', endDate: '2026-11-09' }],
    localRequests: ['seniorAge'], recordContext: [{ kind: 'riskCount' }],
  });
  assert.equal((await service.answer(1, question, 'zh', false)).outcome, 'historyDisabled');
  assert.deepEqual(calls, [{ kind: 'riskCount' }]);
  const month = await service.answer(1, '2026年10月有多少次出行、多少次风险事件？', 'zh', true);
  assert.deepEqual(month.citations.map(c => c.id), ['month-2026-10']);
  assert.match(month.paragraphs[0], /24 次出行、30 次风险事件/);
  const november = await service.answer(1, '2026年11月有多少次出行、多少次风险事件？', 'zh', true);
  assert.deepEqual(november.citations.map(c => c.id), ['month-2026-11']);
  assert.match(november.paragraphs[0], /0 次出行、0 次风险事件/);
});

test('current whereabouts shows sanitized latest update, marks stale fixes, and gives the map shortcut', async () => {
  const data = { timezone: 'Asia/Shanghai', trips: [], risks: [] };
  let latestPoints = [{ sampledAt: new Date('2026-10-21T10:00:00Z'), latitude: 31.2304, longitude: 121.4737 }];
  const queries = new ChatQueries({ data: async () => data } as any, {
    tracker: async () => null, latestPoints: async () => latestPoints,
  } as any);
  const service = new ChatService({
    run: (elderId: number, query: ChatQuery) => queries.run(elderId, query, new Date('2026-10-21T10:05:01Z')),
  } as any, { plan: async () => assert.fail('Exact current whereabouts is local') } as any);
  const question = '老人现在的具体位置在哪里，什么时候更新的？';
  const current = await service.answer(1, question, 'zh', true);
  assert.deepEqual(current.localRequests, ['locationMap']);
  assert.match(current.paragraphs[0], /2026-10-21 18:00.*已过期/);
  assert.doesNotMatch(JSON.stringify(current), /31\.2304|121\.4737/);
  assert.deepEqual(current.recordContext, [{ kind: 'current' }]);
  latestPoints = [];
  const missing = await service.answer(1, question, 'zh', true);
  assert.deepEqual(missing.paragraphs, ['目前还没有位置记录。']);
  assert.equal(missing.recordContext, undefined);
  assert.deepEqual(missing.citations, []);
  assert.deepEqual(missing.localRequests, ['locationMap']);
});

test('partially failing tools keep verified facts and local requests and discard unverified planner claims', async () => {
  const { citations } = result;
  const service = new ChatService({
    localToday: async () => '2026-10-21',
    run: async (_elderId: number, { kind }: ChatQuery) => {
      if (kind === 'trip') throw new Error('timeout');
      return result;
    },
  } as any, {
    plan: async () => ({
      intent: 'mixed', queries: [{ kind: 'events' }, { kind: 'trip' }], localRequests: ['seniorAge'],
      paragraphs: ['The elder is 85.'],
    }),
    answer: async () => ({ paragraphs: ['On 2026-10-21 event 42 was high risk.'], citations }),
  } as any);
  const response = await service.answer(1, 'What happened on the trip? How old is she?', 'en', true);
  assert.equal(response.retryable, true);
  assert.equal(response.outcome, 'answered');
  assert.deepEqual(response.paragraphs, ['On 2026-10-21 event 42 was high risk.', 'Some information is temporarily unavailable. You can retry.']);
  assert.deepEqual(response.citations, citations);
  assert.deepEqual(response.recordContext, [{ kind: 'events' }]);
  assert.deepEqual(response.localRequests, ['seniorAge']);
});

test('follow-up queries use only a valid prior scope and re-read current authorised records', async () => {
  const scope: ChatQuery[] = [{ kind: 'events', id: '42' }];
  const calls: [number, ChatQuery][] = [];
  const service = new ChatService({
    localToday: async () => '2026-10-21',
    run: async (elderId: number, query: ChatQuery) => { calls.push([elderId, query]); return result; },
  } as any, {
    plan: async (_q: string, _lang: string, _today: string, _history: unknown, prior: ChatQuery[]) => {
      assert.deepEqual(prior, scope);
      return { intent: 'care', queries: prior };
    },
    answer: async () => ({ paragraphs: ['On 2026-10-21 event 42 was high risk.'], citations: result.citations }),
  } as any);
  const response = await service.answer(9, 'What about that event?', 'en', true, [], scope);
  assert.deepEqual(calls, [[9, scope[0]]]);
  assert.deepEqual(response.recordContext, scope);
});

test('local profile and settings requests need no cloud call', async () => {
  const service = new ChatService({} as any, { plan: () => assert.fail('local settings must stay on device') } as any);
  assert.deepEqual(await service.answer(1, '请查看老人资料和当前的照护设置。', 'zh', true), {
    outcome: 'answered', paragraphs: [], citations: [], localRequests: ['seniorProfile', 'settings'],
  });
  assert.equal((await service.answer(1, 'Show me emergency contacts', 'en', false)).outcome, 'historyDisabled');
});

test('mixed everyday text is answered separately without exposing the household scope', async () => {
  const general = '写一句早安问候';
  const question = `${general}，再告诉我累计风险次数。`;
  const citation = { kind: 'statistic', id: 'risk-count', label: 'Risk event count', startDate: '2026-10-01', endDate: '2026-11-09' };
  let includeGeneralQuestion = true;
  const service = new ChatService({
    localToday: async () => '2026-11-09',
    run: async () => ({ facts: { count: 4 }, citations: [citation] }),
  } as any, {
    plan: async (q: string, _language: string, today: string | undefined, _history: unknown, scope: ChatQuery[], allowed: boolean) => {
      if (q === question) return { intent: 'mixed', queries: [{ type: 'riskCount' }],
        ...(includeGeneralQuestion ? { generalQuestion: general } : {}), paragraphs: ['累计 99 次。'] };
      assert.equal(q, general);
      assert.equal(today, undefined);
      assert.deepEqual(scope, []);
      assert.equal(allowed, false);
      return { intent: 'general', paragraphs: ['早安，祝你今天一切顺利！'] };
    },
  } as any);
  const reply = await service.answer(1, question, 'zh', true, [], [{ kind: 'current' }]);
  assert.deepEqual(reply.paragraphs, ['早安，祝你今天一切顺利！', '累计记录 4 次风险事件（已排除误报）。']);
  assert.deepEqual(reply.citations.map(c => c.id), ['risk-count']);
  includeGeneralQuestion = false;
  assert.deepEqual((await service.answer(1, question, 'zh', true)).paragraphs, reply.paragraphs);
  const blocked = await service.answer(1, question, 'zh', false);
  assert.equal(blocked.outcome, 'historyDisabled');
  assert.equal(blocked.paragraphs[0], '早安，祝你今天一切顺利！');
  assert.deepEqual(blocked.citations, []);
});

test('monthly risk comparison answers the question first and its follow-up re-reads both cited periods', async () => {
  const data = {
    timezone: 'Asia/Shanghai', trips: [], observations: [], actions: [], calls: [],
    risks: [1, 2, 3, 4, 5].map(id => ({
      id: String(id), openedAt: new Date('2026-10-01T01:00:00Z'), falseAlarm: id === 5,
    })),
  };
  const queries = new ChatQueries({ data: async () => data } as any, {} as any);
  const calls: [number, ChatQuery][] = [];
  const service = new ChatService({
    run: (elderId: number, query: ChatQuery) => {
      calls.push([elderId, query]);
      return queries.run(elderId, query, new Date('2026-11-08T18:00:00Z'));
    },
  } as any, { plan: () => assert.fail('A clear risk comparison needs no model') } as any);
  const first = await service.answer(9, '那这个月风险比上个月高？', 'zh', true);
  assert.equal(first.outcome, 'answered');
  assert.match(first.paragraphs[0], /^目前还看不出风险有没有升高，因为两个统计时段长短不同。/);
  assert.match(first.paragraphs[0], /11 月 9 日，11 月还没有记录到风险事件，10 月整月有 4 次（均已排除误报）/);
  assert.deepEqual(first.citations.map(c => [c.id, c.startDate, c.endDate]), [
    ['month-2026-10', '2026-10-01', '2026-10-31'],
    ['month-2026-11', '2026-11-01', '2026-11-09'],
  ]);
  assert.deepEqual(first.recordContext, [{ kind: 'compare', metric: 'riskEvents' }]);

  data.risks.push({ id: '6', openedAt: new Date('2026-10-31T16:10:00Z'), falseAlarm: false });
  const followUp = await service.answer(9, '这个说明了什么吗', 'zh', true, [], first.recordContext);
  assert.equal(followUp.outcome, 'answered');
  assert.match(followUp.paragraphs[0], /^这组数字说明了各时段记录了几次风险事件。.*各自的前 9 天/);
  assert.match(followUp.paragraphs[1], /11 月记录了 1 次风险事件/);
  assert.deepEqual(followUp.citations, first.citations);
  assert.deepEqual(followUp.recordContext, first.recordContext);
  assert.deepEqual(calls, [[9, first.recordContext![0]], [9, first.recordContext![0]]]);

  const english = await service.answer(9, 'Was risk higher this month than last month?', 'en', true);
  assert.match(english.paragraphs[0], /^It’s too early to tell.*1 risk event through November 9 and 4 in all of October/);
  const englishFollowUp = await service.answer(9, 'What does this mean?', 'en', true, [], english.recordContext);
  assert.match(englishFollowUp.paragraphs[0], /first 9 days of both months/);
  assert.deepEqual(englishFollowUp.citations, english.citations);
  assert.equal((await service.answer(9, '那这个月风险比上个月高？', 'zh', false)).outcome, 'historyDisabled');
  assert.equal((await service.answer(9, '这个说明了什么吗', 'zh', false, [], first.recordContext)).outcome, 'historyDisabled');
  assert.equal(calls.length, 4);
});

test('equal-length periods report only a change in recorded counts', async () => {
  const data = {
    timezone: 'Asia/Shanghai', trips: [], observations: [], actions: [], calls: [],
    risks: [{ id: '1', openedAt: new Date('2026-08-01T01:00:00Z'), falseAlarm: false }],
  };
  const queries = new ChatQueries({ data: async () => data } as any, {} as any);
  const service = new ChatService({
    run: (elderId: number, query: ChatQuery) => queries.run(elderId, query, new Date('2026-09-02T01:00:00Z')),
  } as any, {} as any);
  const scope: ChatQuery[] = [{ kind: 'compare', month: '2026-08', metric: 'riskEvents' }];
  const explain = () => service.answer(1, '这个说明了什么吗', 'zh', true, [], scope);
  assert.match((await explain()).paragraphs[0], /^这个时段记录的风险事件比上个时段多。/);
  data.risks.push({ id: '2', openedAt: new Date('2026-07-01T01:00:00Z'), falseAlarm: false });
  assert.match((await explain()).paragraphs[0], /^两个月记录的风险事件次数相同。/);
  data.risks[0].falseAlarm = true;
  assert.match((await explain()).paragraphs[0], /^这个时段记录的风险事件比上个时段少。/);
  const january = await service.answer(1, '这个说明了什么吗', 'zh', true, [], [{ kind: 'compare', month: '2026-01', metric: 'riskEvents' }]);
  assert.match(january.paragraphs[1], /2026 年 1 月 31 日.*2025 年 12 月/);
});

test('legacy compare context, risk subsets and mixed comparisons keep the regular answer path', async () => {
  const queriesRun: ChatQuery[] = [];
  const service = new ChatService({
    localToday: async () => '2026-11-09',
    run: async (_elderId: number, query: ChatQuery) => {
      queriesRun.push(query);
      return result;
    },
  } as any, {
    plan: async () => ({ intent: 'care', queries: [{ kind: 'compare', metric: 'riskEvents' }] }),
    answer: async () => ({ paragraphs: ['On 2026-10-21 event 42 was high risk.'], citations: result.citations }),
  } as any);
  for (const question of ['这个说明了什么吗', '这个月高风险事件比上个月多吗？', '这个月的风险和出行比上个月多吗？']) {
    const response = await service.answer(1, question, 'zh', true, [], [{ kind: 'compare' }]);
    assert.equal(response.outcome, 'answered');
    assert.deepEqual(response.recordContext, [{ kind: 'compare' }]);
  }
  assert.deepEqual(queriesRun, Array(3).fill({ kind: 'compare' }));
});

test('contact questions request only the corresponding fields from this phone', async () => {
  const service = new ChatService({} as any, { plan: () => assert.fail('Phone contacts must remain local') } as any);
  for (const [question, language, field] of [
    ['老人有哪些家人的联系方式？', 'zh', 'familyMembers'],
    ['What are her family members’ phone numbers?', 'en', 'familyMembers'],
    ['Show me the senior’s family contacts.', 'en', 'familyMembers'],
    ['她的紧急联系人有哪些？', 'zh', 'emergencyContacts'],
    ['Who are her emergency contacts?', 'en', 'emergencyContacts'],
  ] as const) {
    assert.deepEqual(await service.answer(1, question, language, true), {
      outcome: 'answered', paragraphs: [], citations: [], localRequests: [field],
    });
    const blocked = await service.answer(1, question, language, false);
    assert.equal(blocked.outcome, 'historyDisabled');
    assert.equal(blocked.localRequests, undefined);
  }
});
