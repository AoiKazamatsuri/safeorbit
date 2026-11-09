import { ChatQuery } from '../care-api/public';

export type ChatTurn = { role: 'user' | 'assistant'; text: string };
export const localRequests = [
  'seniorAge', 'seniorProfile', 'caregiverProfile', 'familyMembers', 'emergencyContacts',
  'settings', 'locationMap', 'safeZonesMap', 'tripRecords', 'riskRecords',
] as const;
export type LocalRequest = typeof localRequests[number];

const queryKeys: Record<ChatQuery['kind'], string[]> = {
  current: [], events: ['id', 'level', 'from', 'to', 'latest'], trip: ['id'],
  compare: ['month', 'metric'], riskCount: ['level', 'from', 'to'], safeZones: [],
  activity: ['id', 'level', 'from', 'to', 'latest'],
};

function validDate(value: unknown): value is string {
  if (typeof value !== 'string' || !/^[1-9]\d{3}-\d{2}-\d{2}$/.test(value)) return false;
  const parsed = new Date(value + 'T00:00:00Z');
  return Number.isFinite(+parsed) && parsed.toISOString().slice(0, 10) === value;
}

function validQuery(value: unknown): value is ChatQuery {
  if (!value || typeof value !== 'object') return false;
  const query = value as ChatQuery;
  return Object.hasOwn(queryKeys, query.kind)
    && Object.keys(query).every(key => key === 'kind' || queryKeys[query.kind].includes(key))
    && (query.level === undefined || query.level === 'high' || query.level === 'warning')
    && (query.latest === undefined || typeof query.latest === 'boolean')
    && (query.id === undefined || (typeof query.id === 'string' && /^\d{1,18}$/.test(query.id)))
    && (query.month === undefined || (typeof query.month === 'string' && /^[1-9]\d{3}-(0[1-9]|1[0-2])$/.test(query.month)))
    && (query.metric === undefined || query.metric === 'riskEvents')
    && (query.from === undefined || validDate(query.from)) && (query.to === undefined || validDate(query.to))
    && (!query.from || !query.to || query.from <= query.to);
}

export function validQueries(value: unknown): value is ChatQuery[] {
  return Array.isArray(value) && value.length <= 3 && value.every(validQuery);
}

export function validLocalRequests(value: unknown): value is LocalRequest[] {
  return Array.isArray(value) && value.length <= localRequests.length && value.every(key => localRequests.includes(key));
}

export function validHistory(value: unknown): value is ChatTurn[] {
  return Array.isArray(value) && value.length <= 8 && value.every(turn => turn && typeof turn === 'object'
    && Object.keys(turn).every(key => key === 'role' || key === 'text')
    && (turn.role === 'user' || turn.role === 'assistant') && typeof turn.text === 'string' && turn.text.trim().length > 0)
    && value.reduce((total, turn) => total + turn.text.length, 0) <= 4000;
}

export function validParagraphs(value: unknown): value is string[] {
  return Array.isArray(value) && value.length >= 1 && value.length <= 8 &&
    value.every(text => typeof text === 'string' && text.trim().length > 0 && text.length <= 1000);
}

const sensitiveText = /(?:https?:\/\/|www\.)\S|[\w.+-]+@[\w.-]+\.[a-z]{2,}|\b[a-z0-9-]+\.(?:com|cn|org|net|io|dev|edu|gov)\b|\b(?:sk|key|token|ghp|gho|xox[baprs])[-_][a-z0-9._-]{12,}|\bbearer\s+[a-z0-9._-]{8,}|(?:password|passwd|secret|api[_ -]?key|token|密钥|密码)\s*[:=：]\s*\S|-----BEGIN [A-Z ]*PRIVATE KEY-----|[+-]?\d{1,3}\.\d{2,}\s*[,，]\s*[+-]?\d{1,3}\.\d{2,}|(?:\b\d{1,6}\s+(?:[a-z]+\s+){1,4}(?:street|st|road|rd|avenue|ave|lane|ln|boulevard|blvd)\b|[\p{Script=Han}]{2,}(?:街|路|巷)\s*\d+\s*号)/iu;

export function hasPrivateText(text: string): boolean {
  const normalized = text.normalize('NFKC').replace(/[\u200b-\u200d\u2060\ufeff]/g, '');
  const withoutDates = normalized.replace(/\b\d{4}-\d{2}-\d{2}\b/g, '');
  return sensitiveText.test(normalized) ||
    (withoutDates.match(/\+?\d[\d ()-]*\d/g) ?? []).some(value => value.replace(/\D/g, '').length >= 9);
}
