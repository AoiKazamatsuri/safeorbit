import { Injectable } from '@nestjs/common';
import { ChatQueries, ChatQuery, QueryResult } from '../care-api/public';
import { ChatResponse, Language, notice, verifyAnswer } from './grounded-response';
import { LanguageModel } from './language-model';

const medical = /\b(diagnos\w*|dementia|alzheimer\w*|disease|medic\w*|symptom\w*|treat\w*|prescri\w*|dosage|illness|prognosis)\b|诊断|病情|痴呆|阿尔茨海默|疾病|症状|治疗|用药|药量|药物|患病|病症|医疗|医生/iu;
const sensitiveText = /https?:\/\/|[\w.+-]+@[\w.-]+\.[a-z]{2,}|\b(?:sk|key|token)[-_][a-z0-9._-]{12,}|[+-]?\d{1,3}\.\d{4,}\s*[,，]\s*[+-]?\d{1,3}\.\d{4,}/i;

function hasPrivateText(question: string): boolean {
  const withoutDates = question.replace(/\b\d{4}-\d{2}-\d{2}\b/g, '');
  return sensitiveText.test(question) ||
    (withoutDates.match(/\+?\d[\d ()-]*\d/g) ?? []).some(value => value.replace(/\D/g, '').length >= 9);
}

function validDate(date: unknown): date is string {
  if (typeof date !== 'string' || !/^[1-9]\d{3}-\d{2}-\d{2}$/.test(date)) return false;
  const parsed = new Date(date + 'T00:00:00Z');
  return Number.isFinite(+parsed) && parsed.toISOString().slice(0, 10) === date;
}

function validQuery(query: ChatQuery): boolean {
  if (!query || typeof query !== 'object') return false;
  switch (query.kind) {
    case 'current': return true;
    case 'events':
      return (query.level === undefined || query.level === 'high' || query.level === 'warning')
        && (query.latest === undefined || typeof query.latest === 'boolean')
        && (query.from === undefined || validDate(query.from)) && (query.to === undefined || validDate(query.to))
        && (!query.from || !query.to || query.from <= query.to);
    case 'trip': return query.id === undefined || (typeof query.id === 'string' && /^\d{1,18}$/.test(query.id));
    case 'compare': return query.month === undefined || (typeof query.month === 'string' && /^[1-9]\d{3}-(0[1-9]|1[0-2])$/.test(query.month));
    default: return false;
  }
}

function latestRiskQuery(question: string): ChatQuery | undefined {
  const match = /^(?:请问[，,]?\s*)?(?:最近一次|上一次|上次)(高风险|风险)事件(?:是|在|发生在|发生于)?(?:什么时候|什么时间|哪天|哪一天)(?:发生的?)?[?？。]?$/u.exec(question)
    ?? /^when (?:was|did) the (?:last|most recent) (high[- ]risk|risk) event(?: (?:happen|occur))?[?.]?$/i.exec(question);
  if (!match) return undefined;
  const level = /^(?:高风险|high[- ]risk)$/i.test(match[1]) ? 'high' : undefined;
  return { kind: 'events', latest: true, level };
}

function patternText(result: QueryResult): string | undefined {
  const facts = result.facts as { pattern?: unknown } | null;
  return typeof facts?.pattern === 'string' ? facts.pattern : undefined;
}

function patternReply(result: QueryResult, pattern: string, language: Language): ChatResponse {
  const citations = result.citations.slice(-1);
  if (language === 'en') return { outcome: 'answered', paragraphs: [pattern], citations };
  const match = /^Based on (\d+) recorded trips this month, (\d+) started in the (morning|afternoon|evening)\.$/.exec(pattern);
  const periods: Record<string, string> = { morning: '上午', afternoon: '下午', evening: '晚上' };
  const paragraph = match ? `本月记录了 ${match[1]} 次出行，其中 ${match[2]} 次在${periods[match[3]]}开始。` : '本月尚无出行记录。';
  return { outcome: 'answered', paragraphs: [paragraph], citations: citations.map(c => ({ ...c, label: '出行规律统计' })) };
}

@Injectable()
export class ChatService {
  constructor(private readonly queries: ChatQueries, private readonly model: LanguageModel) {}

  async answer(elderId: number, question: string, language: Language, allowTripHistory: boolean): Promise<ChatResponse> {
    if (!allowTripHistory) return notice('historyDisabled', language);
    if (hasPrivateText(question)) return notice('unverified', language);
    if (medical.test(question)) return notice('medicalBoundary', language);
    const wantsPattern = /pattern|routine|规律|习惯/i.test(question);
    const results: QueryResult[] = [];
    let attempts = 0;
    const query = (request: ChatQuery) => {
      attempts++;
      return this.queries.run(elderId, request);
    };
    let failure: unknown;
    try {
      const today = await this.queries.localToday(elderId);
      const proposed = await this.model.plan(question, language, today);
      const latestRisk = latestRiskQuery(question);
      const plan = latestRisk ? [latestRisk] : proposed;
      if (Array.isArray(plan) && plan.length >= 1 && plan.length <= 3 && plan.every(validQuery)) {
        for (const request of plan) results.push(await query(request));
        if (results.some(result => result.citations.length)) {
          const reply = verifyAnswer(await this.model.answer(question, language, results), results, language);
          if (reply.outcome === 'answered') return reply;
        }
      }
    } catch (error) {
      if (!(error instanceof SyntaxError)) failure = error;
    }
    if (wantsPattern) {
      const stats = results.find(result => patternText(result) !== undefined)
        ?? (attempts < 3 ? await query({ kind: 'compare' }) : undefined);
      const pattern = stats && patternText(stats);
      if (stats && pattern !== undefined) return patternReply(stats, pattern, language);
    }
    if (failure) throw failure;
    return notice('unverified', language);
  }
}
