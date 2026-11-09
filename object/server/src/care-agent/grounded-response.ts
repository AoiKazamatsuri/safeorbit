import { ChatQuery, Citation, QueryResult } from '../care-api/public';
import { hasPrivateText, LocalRequest, validParagraphs } from './chat-contract';
export type Language = 'zh' | 'en';
export type Outcome = 'answered' | 'general' | 'unverified' | 'medicalBoundary' | 'historyDisabled';
export interface ChatResponse {
  outcome: Outcome;
  paragraphs: string[];
  citations: Citation[];
  localRequests?: LocalRequest[];
  recordContext?: ChatQuery[];
  retryable?: true;
}
export function notice(outcome: Exclude<Outcome, 'answered' | 'general'>, language: Language): ChatResponse {
  const messages = {
    unverified: ['I could not verify an answer from the available records.', '现有记录不足以核实回答。'],
    medicalBoundary: ['I cannot diagnose or assess a medical condition. Please consult a qualified clinician.', '我不能诊断或评估病情，请咨询专业医护人员。'],
    historyDisabled: ['Access to care records and settings is turned off.', '照护记录和设置的访问权限已关闭。'],
  };
  return { outcome, paragraphs: [messages[outcome][language === 'zh' ? 1 : 0]], citations: [] };
}

export function localizeCitation(citation: Citation, language: Language): Citation {
  if (language === 'en') return citation.id === 'risk-count' ? { ...citation, label: 'Cumulative risk count' } : citation;
  let label: string;
  if (citation.kind === 'riskEvent') label = `风险事件 ${citation.id}`;
  else if (citation.kind === 'trip') label = `出行 ${citation.id}`;
  else if (citation.id === 'risk-count') label = '累计风险统计';
  else if (citation.id.startsWith('risk-count-')) label = '风险事件统计';
  else if (citation.id.startsWith('current-')) label = '最近记录的状态';
  else if (citation.id === 'safe-zones') label = '已设置的安全区';
  else label = `行为统计 ${citation.startDate} 至 ${citation.endDate}`;
  return { ...citation, label };
}

export function verifyAnswer(value: unknown, results: QueryResult[], language: Language): ChatResponse {
  if (!value || typeof value !== 'object') return notice('unverified', language);
  const answer = value as { paragraphs?: unknown; citations?: unknown };
  if (!validParagraphs(answer.paragraphs) || answer.paragraphs.some(hasPrivateText) ||
    !Array.isArray(answer.citations) || !answer.citations.length) return notice('unverified', language);
  const available = results.flatMap(r => r.citations);
  const citations: Citation[] = [];
  for (const item of answer.citations) {
    if (!item || typeof item !== 'object') return notice('unverified', language);
    const { kind, id } = item as Citation;
    const found = available.find(c => c.kind === kind && c.id === id);
    if (!found) return notice('unverified', language);
    if (!citations.includes(found)) citations.push(found);
  }
  // Check whole numeric tokens, including dates and identifiers, against the selected records.
  const chosen = results.filter(r => r.citations.some(c => citations.includes(c)));
  // Group evidence per citation; if a result has no grouping, require all its citations.
  if (chosen.some(r => !r.evidence && r.citations.some(c => !citations.includes(c)))) return notice('unverified', language);
  const source = JSON.stringify(chosen.map(r => r.evidence ? r.citations.filter(c => citations.includes(c)).map(c => ({ citation: c, facts: r.evidence![`${c.kind}:${c.id}`] })) : r));
  const numbers = new Set(source.match(/\d+(?:[.:-]\d+)*/g) ?? []);
  for (const p of answer.paragraphs) {
    // Reject written-out numbers: the numeric token verifier cannot compare these reliably.
    // In this phrase, 一 is part of the relative reference, not a reported count.
    const claims = p.replace(/(?:最近|上)一次(?=(?:高风险|风险)事件)/gu, '');
    if (/\b(zero|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|hundred|thousand)\b|[零〇一二三四五六七八九十百千万两]/i.test(claims)) return notice('unverified', language);
    if (/\b(diagnos\w*|dementia|alzheimer\w*|disease|treat\w*|medication)\b|诊断|痴呆|阿尔茨海默|疾病|治疗|用药/i.test(p)) return notice('unverified', language);
    for (const n of p.match(/\d+(?:[.:-]\d+)*/g) ?? []) if (!numbers.has(n)) return notice('unverified', language);
  }
  return { outcome: 'answered', paragraphs: answer.paragraphs, citations: citations.map(c => localizeCitation(c, language)) };
}
