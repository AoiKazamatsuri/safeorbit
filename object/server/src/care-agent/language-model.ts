import { Injectable } from '@nestjs/common';
import { ChatQuery, QueryResult } from '../care-api/public';
import { Language } from './grounded-response';

// Injectable port: tests can provide a fake without network access.
@Injectable()
export class LanguageModel {
  get enabled(): boolean { return process.env.LLM_ENABLED === 'true' && !!process.env.LLM_API_KEY; }
  private async generate(prompt: string): Promise<string> {
    if (!this.enabled) throw new Error('Cloud model disabled');
    // Native dynamic imports are required because the SDK is ESM and the server compiles to CommonJS.
    const load = new Function('name', 'return import(name)') as (name: string) => Promise<any>;
    const [{ generateText }, { createOpenAICompatible }] = await Promise.all([load('ai'), load('@ai-sdk/openai-compatible')]);
    const model = process.env.LLM_MODEL || 'qwen3.7-flash';
    const provider = createOpenAICompatible({ name: 'qwen', apiKey: process.env.LLM_API_KEY,
      baseURL: process.env.LLM_BASE_URL || 'https://dashscope.aliyuncs.com/compatible-mode/v1' });
    // The two chat calls must both fit the App's request timeout. This model can produce the small JSON replies directly.
    const providerOptions = /^qwen3\.7-flash(?:-|$)/.test(model) ? { qwen: { enable_thinking: false } } : undefined;
    const response = await generateText({ model: provider(model), prompt, providerOptions,
      abortSignal: AbortSignal.timeout(6000), maxRetries: 0, maxOutputTokens: 600 });
    return response.text;
  }
  async plan(question: string, language: Language, today: string): Promise<ChatQuery[]> {
    const raw = await this.generate(`Choose up to three read-only queries for the question. Return only a JSON array of objects with kind current, events, trip or compare. Events can take optional level high or warning and from and to YYYY-MM-DD. For the last or most recent risk event, set latest to true. Use date bounds and a risk level only when the question specifies them. Trip can take an id. Compare takes an optional month YYYY-MM and returns monthly statistics for that month and the preceding month. For monthly trip or risk event counts, use compare with the requested month, even if only one month is requested. Never provide an elder ID. Today in the elder’s timezone is ${today}. Question (${language}): ${question}`);
    return JSON.parse(raw.replace(/^```(?:json)?\s*|\s*```$/g, ''));
  }
  async answer(question: string, language: Language, results: QueryResult[]): Promise<unknown> {
    const raw = await this.generate(`Answer in ${language} using only these facts. Do not infer medical conditions. Return only JSON: {"paragraphs":["..."],"citations":[{"kind":"...","id":"..."}]}. Cite only the records actually used. Use only supplied numbers and dates, and include explicit date ranges for comparisons. For monthly totals use tripCount for trips and riskEventCount for risk events (false alarms already excluded). Write months as YYYY-MM. If only one month is asked, report and cite only that month. For a question asking when a risk event occurred, give the ISO date (YYYY-MM-DD) directly without restating the question. If periods have different lengths, report their counts without inferring a trend. Write all numbers as Arabic digits, never as words. Question: ${question}\nFacts: ${JSON.stringify(results)}`);
    return JSON.parse(raw.replace(/^```(?:json)?\s*|\s*```$/g, ''));
  }
  async risk(facts: unknown): Promise<string> {
    const text = await this.generate(`Arrange these exact sentences without adding or changing words. Sentences: ${JSON.stringify(facts)}`);
    return text.trim();
  }
}
