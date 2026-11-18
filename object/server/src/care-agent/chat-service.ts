import { Injectable } from '@nestjs/common';
import { ChatQueries, ChatQuery, QueryResult } from '../care-api/public';
import { ChatTurn, hasPrivateText, LocalRequest, validLocalRequests, validParagraphs, validQueries } from './chat-contract';
import { ChatResponse, Language, localizeCitation, notice, verifyAnswer } from './grounded-response';
import { LanguageModel } from './language-model';

const medical = /\b(diagnos\w*|dementia|alzheimer\w*|disease|medic\w*|symptom\w*|treat\w*|prescri\w*|dosage|illness|prognosis)\b|诊断|病情|痴呆|阿尔茨海默|疾病|症状|治疗|用药|药量|药物|患病|病症|医疗|医生/iu;

interface Plan {
  intent: 'general' | 'care' | 'mixed';
  queries: ChatQuery[];
  localRequests: LocalRequest[];
  paragraphs: string[];
  generalQuestion?: string;
}

function parsePlan(value: unknown): Plan | undefined {
  if (Array.isArray(value)) return validQueries(value) ? { intent: 'care', queries: value, localRequests: [], paragraphs: [] } : undefined;
  if (!value || typeof value !== 'object') return undefined;
  const { intent, queries = [], localRequests = [], paragraphs = [], generalQuestion } = value as Record<string, unknown>;
  if (!Array.isArray(queries) || queries.length > 3 || !validLocalRequests(localRequests)) return undefined;
  const plannedQueries = [];
  const plannedLocal = [...localRequests];
  for (const item of queries) {
    if (typeof item === 'string') {
      if (validLocalRequests([item])) plannedLocal.push(item as LocalRequest);
      else plannedQueries.push({ kind: item });
    } else if (item && typeof item === 'object' && 'type' in item && !('kind' in item)) {
      const { type, ...fields } = item;
      plannedQueries.push({ ...fields, kind: type });
    } else plannedQueries.push(item);
  }
  if ((intent !== 'care' && intent !== 'mixed' && intent !== 'general') ||
    !validQueries(plannedQueries)) return undefined;
  if (intent === 'general' && (plannedQueries.length || plannedLocal.length || !validParagraphs(paragraphs))) return undefined;
  return {
    intent, queries: plannedQueries, localRequests: [...new Set(plannedLocal)],
    paragraphs: intent === 'general' && validParagraphs(paragraphs) && !paragraphs.some(p => hasPrivateText(p) || medical.test(p)) ? paragraphs : [],
    generalQuestion: intent === 'mixed' && typeof generalQuestion === 'string' ? generalQuestion.trim() : undefined,
  };
}

function latestRiskQuery(question: string): ChatQuery | undefined {
  const match = /^(?:请问[，,]?\s*)?(?:最近一次|上一次|上次)(高风险|风险)(事件|出行|行程)(?:是|在|发生在|发生于)?(?:什么时候|什么时间|哪天|哪一天)(?:发生的?)?[?？。]?$/u.exec(question)
    ?? /^when (?:was|did) the (?:last|most recent) (high[- ]risk|risk|risky) (event|trip|outing)(?: (?:happen|occur))?[?.]?$/i.exec(question);
  if (!match) return undefined;
  const kind = /^(?:事件|event)$/i.test(match[2]) ? 'latestRisk' : 'latestRiskTrip';
  return /^(?:高风险|high[- ]risk)$/i.test(match[1]) ? { kind, level: 'high' } : { kind };
}

function monthlyQuestion(question: string): { trip: boolean; risk: boolean; month?: string } | undefined {
  if (!/多少|几次|次数|\bhow many\b|\bcounts?\b/i.test(question) || /高风险|低风险|预警|high[- ]risk|warning|false alarms?\b|误报.*多少/i.test(question)) return undefined;
  const trip = /出行|\btrips?\b/i.test(question);
  const risk = /风险事件|\brisk events?\b/i.test(question);
  if (!trip && !risk) return undefined;
  if (/对比|相比|比较|上月|上个?月|\bcompare\b|\bversus\b|\bvs\.?\b/i.test(question)) return undefined;
  const months = [...question.matchAll(/\b([1-9]\d{3})\s*(?:年\s*|-)\s*(1[0-2]|0?[1-9])(?:月|(?!\d))/g)];
  if (months.length > 1) return undefined;
  const [match] = months;
  return { trip, risk, month: match ? `${match[1]}-${match[2].padStart(2, '0')}` : undefined };
}

function questionPhrase(question: string): string {
  return question.normalize('NFKC').replace(/[.!?。]+$/u, '').trim();
}

function asksIdentity(question: string): boolean {
  const phrase = questionPhrase(question).replace(/^(?:请问[，, ]*|please\s+)/iu, '');
  return /^(?:你是谁|你是什么(?:助手|智能体)?|你能帮我做什么|(?:请)?介绍一下你自己|who are you|what are you|what can you (?:help me )?do|introduce yourself|tell me about yourself)$/iu.test(phrase);
}

const octoberSubjects = {
  trips: /出行|行程|出门|外出|\b(?:trips?|outings?|walks?)\b/i,
  risks: /风险|\brisks?\b/i,
  high: /高(?:等级)?风险|严重风险|\bhigh[- ]risks?\b/i,
  warnings: /低风险|预警|\b(?:low[- ]risk|warnings?)\b/i,
  deviations: /偏离|偏航|偏移|偏轨|偏路|\b(?:deviat\w*|off[- ]route|went off (?:the )?route)\b/i,
};
const octoberOverview = /概况|情况|总体|总结|小结|总览|概览|怎么样|如何|发生了什么|有[哪些什么]+记录|\b(?:summary|summari[sz]e|overview|what happened|how (?:was|did)|records?|tell me about)\b/i;

function octoberQuery(question: string): ChatQuery | undefined {
  const phrase = questionPhrase(question);
  const month = /(?<![\d一二三四五六七八九十])(?:10|十)\s*月份?|\boctober\b|(?<!\d)2026-10(?!\d)/i;
  if (!month.test(phrase)) return undefined;
  // Keep comparisons, other years/months and real-time requests on their original routes.
  const remaining = phrase.replace(month, '');
  if ([...phrase.matchAll(/\d{4}/g)].some(([year]) => year !== '2026') ||
      /(?:\d{1,2}|[一二三四五六七八九十]+)\s*月|\b(?:january|february|march|april|may|june|july|august|september|november|december)\b/i.test(remaining) ||
      /去年|明年|前年|上旬|中旬|下旬|上半月|下半月|第.{1,2}周|今天|现在|实时|比较|相比|对比|\b(?:last year|next year|today|now|current location|compar\w*|versus|weeks?|first half|second half)\b/i.test(phrase)) return undefined;
  if (!octoberOverview.test(phrase) && !Object.values(octoberSubjects).some(topic => topic.test(phrase)) &&
      !/^(?:2026\s*年\s*)?(?:10|十)\s*月份?$|^october(?: 2026)?$/i.test(phrase)) return undefined;
  const day = /(?:10|十)\s*月\s*(\d{1,2})(?:\s*[日号]|(?!\d))|\boctober\s+(\d{1,2})(?:st|nd|rd|th)?\b|\b(\d{1,2})(?:st|nd|rd|th)?\s+(?:of\s+)?october\b|2026-10-(\d{2})\b|(?:10|十)月([一二三四五六七八九十]{1,3})[日号]/i.exec(phrase);
  if (!day) return { kind: 'october' };
  const digits = '零一二三四五六七八九';
  const [tens, ones] = (day[5] ?? '').split('十');
  const number = day[5] ? (ones === undefined ? digits.indexOf(tens)
    : (tens ? digits.indexOf(tens) : 1) * 10 + digits.indexOf(ones)) : Number(day.slice(1).find(Boolean));
  if (number < 1 || number > 31 || /(?:至|到|–|through|until)\s*\d/i.test(phrase)) return undefined;
  const date = `2026-10-${String(number).padStart(2, '0')}`;
  return { kind: 'october', from: date, to: date };
}

function octoberReply(query: ChatQuery, result: QueryResult, question: string, language: Language): string[] {
  type Subject = keyof typeof octoberSubjects;
  const dates = result.facts as Record<Subject, string[]>;
  const zh = language === 'zh';
  const interests = (Object.keys(octoberSubjects) as Subject[]).filter(key => octoberSubjects[key].test(question));
  if (interests.includes('high') || interests.includes('warnings')) {
    // In “high-risk events”, “risk” is part of the qualifier. Keep the total only when asked separately.
    const rest = question.replace(/高(?:等级)?风险|严重风险|低风险|(?:high|low)[- ]risk/gi, '');
    if (interests.includes('risks') && !octoberSubjects.risks.test(rest)) interests.splice(interests.indexOf('risks'), 1);
  }
  const overview = interests.length === 0 || (interests.length === 1 && interests[0] === 'trips' &&
    /概况|情况|总体|总结|总览|概览|summary|overview/i.test(question));
  const subjects: Subject[] = overview ? ['trips', 'risks', 'high', 'deviations'] : interests;
  const labels: Record<Subject, [string, string]> = {
    trips: ['出行', 'trip'], risks: ['风险事件', 'risk event'], high: ['高风险事件', 'high-risk event'],
    warnings: ['低风险事件', 'low-risk event'], deviations: ['路线偏离', 'route deviation'],
  };
  const counts = subjects.map(key => {
    const n = dates[key].length;
    return zh ? `${n} 次${labels[key][0]}` : `${n} ${labels[key][1]}${n === 1 ? '' : 's'}`;
  });
  const period = query.from ?? (zh ? '2026 年 10 月' : 'October 2026');
  const paragraphs = [zh ? `${period}记录了 ${counts.join('、')}。` : `Records for ${period} show ${new Intl.ListFormat('en').format(counts)}.`];
  const asksDates = /哪[一几些天]|哪日|几号|几日|日期|什么时候|何时|最近|最后|最早|首次|列出|\b(?:when|dates?|days?|last|first|latest|list)\b/i.test(question);
  if (!query.from && (overview || asksDates)) {
    for (const key of subjects) {
      if ((overview && key !== 'high') || !dates[key].length) continue;
      const first = /首次|最早|第一次|\b(?:first|earliest)\b/i.test(question);
      const last = /最近|最后|最晚|\b(?:last|latest|most recent)\b/i.test(question);
      const days = [...new Set(dates[key])];
      const selected = first ? days.slice(0, 1) : last ? days.slice(-1) : days;
      paragraphs.push(zh ? `${labels[key][0]}${first ? '首次记录于' : last ? '最后一次记录于' : '记录于'} ${selected.join('、')}。`
        : `${first ? 'First recorded' : last ? 'Last recorded' : 'Recorded'} ${labels[key][1]} date${selected.length === 1 ? '' : 's'}: ${selected.join(', ')}.`);
    }
  }
  return paragraphs;
}

function asksMonthlyRiskComparison(question: string): boolean {
  const phrase = questionPhrase(question).replace(/^(?:那(?:么)?|请问)[, ]*/u, '');
  return /^(?:这个月|本月)(?:的)?风险(?:事件(?:次数|数|数量)?)?(?:比|相比|相较于)上(?:个)?月(?:的风险(?:事件(?:次数|数|数量)?)?)?(?:更|要)?(?:高|低|多|少)(?:了)?(?:吗|么)?$/u.test(phrase)
    || /^(?:这个月|本月)(?:比|相较于)上(?:个)?月(?:的)?风险(?:事件(?:次数|数|数量)?)?(?:更|要)?(?:高|低|多|少)(?:了)?(?:吗|么)?$/u.test(phrase)
    || /^(?:和|比|相比)上(?:个)?月(?:比起来|相比)?[, ]*(?:这个月|本月)(?:的)?风险(?:事件(?:次数|数|数量)?)?(?:升高|下降|变高|变低|变多|变少|更高|更低|更多|更少)(?:了)?(?:吗|么)?$/u.test(phrase)
    || /^(?:so,? )?(?:(?:is|was) (?:the )?risk (?:higher|lower) this month|(?:are|were) there (?:more|fewer) risk events this month|has (?:the )?risk (?:gone up|gone down|increased|decreased) this month) (?:than|compared (?:with|to)) last month$/i.test(phrase);
}

function asksForComparisonMeaning(question: string): boolean {
  const phrase = questionPhrase(question);
  return /^(?:(?:那|所以)[, ]*)?(?:这(?:个(?:结果)?|些(?:数字)?)?|这组(?:数字|数据))?(?:能?说明了?什么(?:问题)?|意味着什么|有什么含义)(?:吗)?$/u.test(phrase)
    || /^(?:so,? )?(?:what (?:does|do) (?:this|that|these numbers|these figures) (?:mean|suggest|tell us)|does (?:this|that) (?:mean anything|tell us anything)|what can we infer from (?:this|that))$/i.test(phrase);
}

function directPlan(question: string, recordContext: ChatQuery[]): Plan | undefined {
  const care = (queries: ChatQuery[], localRequests: LocalRequest[] = []): Plan =>
    ({ intent: 'care', queries, localRequests, paragraphs: [] });
  const october = octoberQuery(question);
  if (october) return care([october]);
  const latestRisk = latestRiskQuery(question);
  if (latestRisk) return care([latestRisk]);
  if (asksMonthlyRiskComparison(question)) return care([{ kind: 'compare', metric: 'riskEvents' }]);
  const [scope] = recordContext;
  if (recordContext.length === 1 && scope.kind === 'compare' && scope.month === '2026-10' && !scope.metric &&
      /^(?:那|其中|这些|这些记录中|what about|which|how many|when were)\s*/i.test(question) &&
      !/\d{4}|\d\s*月|[一二三四五六七八九十上本下]月|上个?月|本周|今天|昨天|最近|\b(?:month|year|week|today|yesterday|recent|last)\b/i.test(question)) {
    const followUp = octoberQuery(`October ${question}`);
    if (followUp) return care([followUp]);
  }
  if (recordContext.length === 1 && scope.kind === 'compare' && scope.metric === 'riskEvents' && asksForComparisonMeaning(question)) {
    return care([scope]);
  }
  const month = monthlyQuestion(question)?.month;
  if (month && /^(?:请问[，,]?\s*)?[1-9]\d{3}\s*(?:年\s*|-)(?:1[0-2]|0?[1-9])月?\s*(?:有|一共|总共|发生|记录|的|多少|几|次|出行|风险事件|和|、|，|？|。|\s|\?|,)+$/u.test(question)) {
    return care([{ kind: 'compare', month }]);
  }
  const age = /^(?:(?:老人|她|他)(?:的|今年)?(?:年龄(?:是多少|多大)?|多大|几岁|多少岁)了?|how old is (?:she|he|the elder))$/iu;
  const total = /^(?:(?:目前|截至目前|到目前为止|历史上)?(?:累计|总共|一共)(?:发生|出现|记录|有)?(?:过|了)?(?:多少|几)次风险事件|(?:how many|total number of) risk events? (?:in total|overall|so far)(?: (?:were recorded|have occurred))?)$/iu;
  const whereabouts = /^(?:(?:老人|她|他)(?:目前|现在)(?:的)?(?:具体)?(?:位置)?(?:在)?(?:哪里|哪儿)|where is (?:she|he|the elder) (?:now|right now))$/iu;
  const locationUpdate = /^(?:(?:这个)?位置(?:是)?(?:什么时候|几点)更新的?|(?:是)?(?:什么时候|几点)更新的?|when was (?:it|the location) (?:last )?updated)$/iu;
  const parts = question.replace(/^请问[，,]?\s*/u, '').split(/\s*(?:[？?，,、；;。]+|以及|还有|和|并且|\band\b)\s*/i)
    .map(part => part.trim().replace(/[.?!]$/u, '')).filter(Boolean);
  if (parts.length === 1 && age.test(parts[0])) return care([], ['seniorAge']);
  if (parts.length === 1 && total.test(parts[0])) return care([{ kind: 'riskCount' }]);
  if (parts.length === 2 && parts.some(part => age.test(part)) && parts.some(part => total.test(part))) {
    return care([{ kind: 'riskCount' }], ['seniorAge']);
  }
  if ((parts.length === 1 && whereabouts.test(parts[0]))
    || (parts.length === 2 && parts.some(part => whereabouts.test(part)) && parts.some(part => locationUpdate.test(part)))) {
    return care([{ kind: 'current' }], ['locationMap']);
  }
  const local = parts.map(part => {
    const topic = part.replace(/^(?:请|please\s+)?(?:查看|显示|列出|告诉我|show me\b|show\b|list\b)\s*/iu, '').replace(/’/gu, "'");
    if (/^(?:老人资料|老人的基本资料|(?:the )?senior(?:'s)? profile)$/iu.test(topic)) return 'seniorProfile';
    if (/^(?:家属资料|我的资料|my profile|caregiver profile)$/iu.test(topic)) return 'caregiverProfile';
    if (/^(?:(?:老人|她|他)(?:的)?)?(?:有哪些|有哪些已登记的)?(?:家人|家庭成员|亲属)(?:的)?(?:联系方式|电话(?:号码)?)?(?:有哪些|是什么|是多少)?$/u.test(topic)
      || /^(?:(?:what (?:are|is) )?(?:(?:the )?(?:elder|senior)'s |her |his |the )?family (?:members(?:' (?:contact (?:information|details)|phone numbers?))?|contacts)|what contact (?:information|details) (?:is|are) saved for (?:the (?:elder|senior)'s|her|his) family members)$/i.test(topic)) return 'familyMembers';
    if (/^(?:(?:老人|她|他)(?:的)?)?(?:有哪些)?紧急联系人(?:的)?(?:联系方式|电话(?:号码)?)?(?:有哪些|是什么|是多少)?$/u.test(topic)
      || /^(?:(?:who|what) (?:are|is) )?(?:(?:the )?(?:elder|senior)'s |her |his |the )?emergency contacts(?:' (?:contact (?:information|details)|phone numbers?))?$/i.test(topic)) return 'emergencyContacts';
    if (/^(?:(?:当前的?)?(?:照护|AI)?设置|(?:current )?(?:care |AI )?settings)$/iu.test(topic)) return 'settings';
  });
  if (local.length && local.every(field => field !== undefined)) return care([], local);
}

function everydayClause(question: string): string | undefined {
  const clauses = question.split(/[，,；;。？?]|\band then\b/i).map(clause => clause.trim());
  if (clauses.filter(Boolean).length < 2) return undefined;
  return clauses.find(clause => /^(?:请|帮我)?(?:写|起草|改写|讲个笑话)|^(?:please\s+)?(?:write|draft|rewrite|tell me a joke)\b/iu.test(clause));
}

function patternReply(result: QueryResult, language: Language): string | undefined {
  const { pattern } = result.facts as { pattern?: unknown } ?? {};
  if (typeof pattern !== 'string') return undefined;
  if (language === 'en') return pattern;
  const match = /^Based on (\d+) recorded trips this month, (\d+) started in the (morning|afternoon|evening)\.$/.exec(pattern);
  const periods: Record<string, string> = { morning: '上午', afternoon: '下午', evening: '晚上' };
  return match ? `本月记录了 ${match[1]} 次出行，其中 ${match[2]} 次在${periods[match[3]]}开始。` : '本月尚无出行记录。';
}

interface MonthlyPeriod {
  month: string;
  startDate: string;
  endDate: string;
  tripCount: number;
  riskEventCount: number;
}

function monthlyRiskReply(previous: MonthlyPeriod, current: MonthlyPeriod, explain: boolean, language: Language): string[] {
  const days = (period: MonthlyPeriod) => (Date.parse(period.endDate) - Date.parse(period.startDate)) / 86_400_000 + 1;
  const previousDays = days(previous);
  const currentDays = days(current);
  const countChange = Math.sign(current.riskEventCount - previous.riskEventCount);
  const sameLength = previousDays === currentDays;
  const comparisonDays = Math.min(previousDays, currentDays);
  const includeYear = current.month.slice(0, 4) !== previous.month.slice(0, 4);
  if (language === 'zh') {
    const monthName = (month: string) => `${includeYear ? month.slice(0, 4) + ' 年 ' : ''}${Number(month.slice(5))} 月`;
    const through = `${monthName(current.month)} ${Number(current.endDate.slice(8))} 日`;
    const latest = current.riskEventCount === 0 ? '还没有记录到风险事件' : `记录了 ${current.riskEventCount} 次风险事件`;
    const counts = `截至 ${through}，${monthName(current.month)}${latest}，${monthName(previous.month)}整月有 ${previous.riskEventCount} 次（均已排除误报）。`;
    const lead = sameLength ? (countChange === 0 ? '两个月记录的风险事件次数相同。' : `这个时段记录的风险事件比上个时段${countChange > 0 ? '多' : '少'}。`)
      : '目前还看不出风险有没有升高，因为两个统计时段长短不同。';
    if (!explain) return [lead + counts];
    const meaning = sameLength ? lead + '继续比较时，可以用相同长度的时段，再结合出行和事件详情看。'
      : `这组数字说明了各时段记录了几次风险事件。要看记录次数有没有变化，可以比较两个月各自的前 ${comparisonDays} 天。`;
    return [meaning, counts];
  }
  const monthName = new Intl.DateTimeFormat('en', { month: 'long', timeZone: 'UTC', ...(includeYear ? { year: 'numeric' } : {}) });
  const dateName = new Intl.DateTimeFormat('en', { month: 'long', day: 'numeric', timeZone: 'UTC', ...(includeYear ? { year: 'numeric' } : {}) });
  const currentCount = current.riskEventCount === 0 ? 'no risk events' : `${current.riskEventCount} risk event${current.riskEventCount === 1 ? '' : 's'}`;
  const counts = `The records show ${currentCount} through ${dateName.format(new Date(current.endDate))} and ${previous.riskEventCount} in all of ${monthName.format(new Date(previous.startDate))}, excluding false alarms.`;
  const lead = sameLength ? (countChange === 0 ? 'Both periods had the same number of recorded risk events.'
    : `The latest period had ${countChange > 0 ? 'more' : 'fewer'} recorded risk events.`)
    : 'It’s too early to tell whether risk has increased because the periods cover different numbers of days.';
  if (!explain) return [`${lead} ${counts}`];
  const meaning = sameLength ? `${lead} Keep the periods the same length in future comparisons and look at the trips and event details for context.`
    : `These figures show how many risk events were recorded in each period. To see how the counts differ over the same length of time, compare the first ${comparisonDays} days of both months.`;
  return [meaning, counts];
}

function directAnswer(query: ChatQuery, result: QueryResult, question: string, language: Language): { paragraphs: string[]; citations: QueryResult['citations'] } | undefined {
  const { facts, citations } = result;
  const zh = language === 'zh';
  if (query.kind === 'current' && !facts) {
    return { paragraphs: [zh ? '目前还没有位置记录。' : 'No location has been reported yet.'], citations };
  }
  if (!facts || !citations.length) return undefined;
  if (query.kind === 'october') return { paragraphs: octoberReply(query, result, question, language), citations };
  if (query.kind === 'riskCount') {
    const { count, level } = facts as { count: number; level: ChatQuery['level'] };
    const risk = level === 'high' ? (zh ? '高风险' : 'high-risk') : level === 'warning' ? (zh ? '低风险' : 'low-risk') : (zh ? '风险' : 'risk');
    const [{ startDate, endDate }] = citations;
    const prefix = query.from || query.to ? (zh ? `${startDate} 至 ${endDate}共` : `From ${startDate} to ${endDate}, there `) : (zh ? '累计' : 'There ');
    return { paragraphs: [zh ? `${prefix}记录 ${count} 次${risk}事件（已排除误报）。`
      : `${prefix}${count === 1 ? 'was' : 'were'} ${count} recorded ${risk} event${count === 1 ? '' : 's'}, excluding false alarms.`], citations };
  }
  if (query.kind === 'current') {
    const { status } = facts as { status: { lastRecordedDate: string; lastRecordedTime: string; phase: string | null; olderThanFiveMinutes: boolean; historyReplay: boolean; hasActiveRisk: boolean; hasActiveTrip: boolean } };
    const stale = status.historyReplay ? (zh ? '这条位置来自历史回放。' : ' This location is from a historical replay.')
      : status.olderThanFiveMinutes ? (zh ? '这条位置记录已过期。' : ' This location record is stale.') : '';
    const state = status.phase === 'home' ? (zh ? '在家' : 'at home')
      : status.phase && status.hasActiveTrip ? (zh ? '在出行中' : 'on a trip') : undefined;
    const risk = status.hasActiveRisk ? (zh ? '记录中有尚未解除的风险事件。' : 'The record shows an unresolved risk event.') : '';
    const when = `${status.lastRecordedDate} ${status.lastRecordedTime}`;
    const paragraph = zh ? `位置最近更新于 ${when}${state ? `，当时${state}` : ''}。${stale}${risk}`
      : `Location was last updated at ${when}${state ? `, when the elder was ${state}` : ''}.${stale}${risk ? ' ' + risk : ''}`;
    return { paragraphs: [paragraph], citations };
  }
  if (query.kind === 'safeZones') {
    const { count, hasHome } = facts as { count: number; hasHome: boolean };
    return { paragraphs: [zh ? `已设置 ${count} 个安全区。${hasHome ? '其中包括家。' : ''}`
      : `${count} safe zone${count === 1 ? ' is' : 's are'} configured.${hasHome ? ' Home is among them.' : ''}`], citations };
  }
  if (query.kind === 'latestRisk' || query.kind === 'latestRiskTrip') {
    const { date } = facts as { date: string };
    const trip = query.kind === 'latestRiskTrip';
    if (zh) {
      const risk = query.level === 'high' ? '高风险' : '风险';
      return { paragraphs: [`最近一次${risk}${trip ? '出行开始于' : '事件发生在'}${date}。`], citations };
    }
    const risk = query.level === 'high' ? 'high-risk' : trip ? 'risky' : 'risk';
    return { paragraphs: [`The last ${risk} ${trip ? 'trip began' : 'event occurred'} on ${date}.`], citations };
  }
  if (query.kind === 'compare') {
    const { periods } = facts as { periods?: MonthlyPeriod[] };
    if (query.metric === 'riskEvents' && periods?.length === 2 && citations.length === 2) {
      return { paragraphs: monthlyRiskReply(periods[0], periods[1], asksForComparisonMeaning(question), language), citations };
    }
    if (/pattern|routine|规律|习惯/i.test(question)) {
      const pattern = patternReply(result, language);
      if (pattern) return { paragraphs: [pattern], citations: citations.slice(-1) };
    }
    const counts = monthlyQuestion(question);
    const period = periods?.at(-1);
    if (counts && period && (!counts.month || counts.month === period.month)) {
      const values = [
        counts.trip && (zh ? `${period.tripCount} 次出行` : `${period.tripCount} recorded trip${period.tripCount === 1 ? '' : 's'}`),
        counts.risk && (zh ? `${period.riskEventCount} 次风险事件（已排除误报）` : `${period.riskEventCount} risk event${period.riskEventCount === 1 ? '' : 's'}, excluding false alarms`),
      ].filter(Boolean);
      return { paragraphs: [zh ? `${period.month} 记录了 ${values.join('、')}。` : `For ${period.month}, the records show ${values.join(' and ')}.`], citations: citations.slice(-1) };
    }
  }
}

@Injectable()
export class ChatService {
  constructor(private readonly queries: ChatQueries, private readonly model: LanguageModel) {}

  async answer(elderId: number, question: string, language: Language, allowTripHistory: boolean,
    history: ChatTurn[] = [], recordContext: ChatQuery[] = []): Promise<ChatResponse> {
    if (hasPrivateText(question)) return notice('unverified', language);
    if (medical.test(question)) return notice('medicalBoundary', language);
    if (asksIdentity(question)) {
      const introduction = language === 'zh'
        ? '我是 SafeOrbit 的照护助手。我可以帮你查看已授权的出行和风险记录，了解近期照护情况。'
        : 'I’m SafeOrbit’s care assistant. I can help you review the trip and risk records you have access to and understand recent changes.';
      return { outcome: 'general', paragraphs: [introduction], citations: [] };
    }

    const safeHistory = history.some(turn => hasPrivateText(turn.text)) ? [] : history;
    let plan = directPlan(question, recordContext);
    if (!plan) {
      const today = allowTripHistory ? await this.queries.localToday(elderId).catch(() => undefined) : undefined;
      try {
        plan = parsePlan(await this.model.plan(question, language, today, safeHistory, allowTripHistory ? recordContext : [], allowTripHistory));
        // Only an explicit risk-count comparison or its follow-up may choose the risk-only renderer.
        if (plan) plan.queries = plan.queries.map(({ metric: _metric, ...query }) => query);
      } catch (error) {
        if (!(error instanceof SyntaxError)) throw error;
      }
    }
    if (!plan) return notice('unverified', language);
    if (plan.intent === 'general') return plan.paragraphs.length
      ? { outcome: 'general', paragraphs: plan.paragraphs, citations: [] } : notice('unverified', language);
    const general = plan.generalQuestion || everydayClause(question);
    // An independent everyday clause can be answered without the household scope or any query results.
    const generalReply = general && general !== question && question.includes(general) && !hasPrivateText(general) && !medical.test(general)
      ? this.model.plan(general, language, undefined, safeHistory, [], false).then(value => {
        const answer = parsePlan(value);
        return { paragraphs: answer?.intent === 'general' ? answer.paragraphs : [] };
      }).catch((error: unknown) => ({ paragraphs: [], error }))
      : Promise.resolve({ paragraphs: [] });
    if (!allowTripHistory) {
      const blocked = notice('historyDisabled', language);
      const answer = await generalReply;
      return { ...blocked, paragraphs: [...answer.paragraphs, ...blocked.paragraphs],
        ...('error' in answer ? { retryable: true as const } : {}) };
    }

    if (plan.queries.length < 3 && /pattern|routine|规律|习惯/i.test(question) && !plan.queries.some(query => query.kind === 'compare' || query.kind === 'october')) {
      plan.queries = [...plan.queries, { kind: 'compare' }];
    }
    const results = await Promise.allSettled(plan.queries.map(async query => ({ query, result: await this.queries.run(elderId, query) })));
    const response: ChatResponse = { outcome: 'answered', paragraphs: [], citations: [] };
    const covered: ChatQuery[] = [];
    const pending: { query: ChatQuery; result: QueryResult }[] = [];
    let missing = false;
    let failure: unknown;
    const append = (answer: Pick<ChatResponse, 'paragraphs' | 'citations'>) => {
      response.paragraphs.push(...answer.paragraphs);
      response.citations.push(...answer.citations.filter(citation => !response.citations.some(c => c.id === citation.id && c.kind === citation.kind))
        .map(citation => localizeCitation(citation, language)));
    };

    for (const entry of results) {
      if (entry.status === 'rejected') {
        failure = entry.reason ?? new Error('Query failed');
        continue;
      }
      const { query, result } = entry.value;
      const answer = directAnswer(query, result, question, language);
      if (answer) {
        append(answer);
        if (answer.citations.length) covered.push(query);
      } else if (result.citations.length) pending.push(entry.value);
      else missing = true;
    }

    if (pending.length) {
      try {
        const facts = pending.map(item => item.result);
        const reply = verifyAnswer(await this.model.answer(question, language, facts), facts, language);
        if (reply.outcome === 'answered') {
          append(reply);
          for (const { query, result } of pending) {
            if (result.citations.some(c => reply.citations.some(r => r.id === c.id && r.kind === c.kind))) covered.push(query);
            else missing = true;
          }
        } else missing = true;
      } catch (error) {
        if (error instanceof SyntaxError) missing = true;
        else failure = error ?? new Error('Answer failed');
      }
    }

    const everyday = await generalReply;
    response.paragraphs.unshift(...everyday.paragraphs);
    if ('error' in everyday) failure ??= everyday.error;
    if (!response.paragraphs.length && !plan.localRequests.length) {
      if (failure) throw failure;
      return notice('unverified', language);
    }
    if (plan.localRequests.length) response.localRequests = plan.localRequests;
    // The installed app decodes a fixed set of query kinds. Reuse its month scope for
    // follow-ups, and leave day-specific October replies scoped to their citation.
    const context = covered.flatMap((query): ChatQuery[] => {
      if (query.kind === 'october') return query.from ? [] : [{ kind: 'compare', month: '2026-10' }];
      if (query.kind === 'latestRisk') return [{ kind: 'events', latest: true, ...(query.level ? { level: query.level } : {}) }];
      return query.kind === 'latestRiskTrip' ? [] : [query];
    });
    if (context.length) response.recordContext = context;
    if (failure) {
      response.retryable = true;
      response.paragraphs.push(language === 'zh' ? '部分资料暂时无法获取，可以重试。' : 'Some information is temporarily unavailable. You can retry.');
    }
    if (missing) response.paragraphs.push(language === 'zh' ? '其余照护问题没有找到可核实的回答。' : 'I could not verify an answer to the remaining care questions.');
    return response;
  }
}
