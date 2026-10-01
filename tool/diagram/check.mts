#!/usr/bin/env -S node --experimental-strip-types --disable-warning=ExperimentalWarning
// 制图检查入口（独立运行版新写）：装载 checks.mts 导出的三项检查 (e)(w)(x) 并逐条报告，红即非零退出。
// 在 envshell 里这件事由机检器 tool/envcheck.mts 的「域包判据插件」装载完成；独立运行版没有机检器，由本件承担同一插件契约：
//   checks: Array<{ id, name, criterion, run(ctx) }>，ctx＝{ root, config, assembly, zones, layout, lib }（三项检查只读 ctx.root）。
//
// 用法（仓库根执行）：
//   node --experimental-strip-types --disable-warning=ExperimentalWarning tool/diagram/check.mts            检查工作区
//   node --experimental-strip-types --disable-warning=ExperimentalWarning tool/diagram/check.mts --staged   检查暂存区（提交钩子用）
//   ... check.mts --root <目录>   检查另一份仓库根（该根下须有 truth/）
// 退出码：0 无红；1 有红；2 检查本身无法运行（装载失败、git 失败等——一律当作不通过）。
//
// --staged：把索引里 truth/ 下的文件导出到临时目录再检查，所以判的是这次提交的内容，而不是工作区里还没暂存的改动。
// 设置（registry.json）读的是工作区版本；只改 registry.json 而不暂存时两者可能不一致，提交前请一并暂存。
import { execFileSync } from 'node:child_process';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { ROOT } from './lib.mts';

type Finding = { level: 'red' | 'warn' | 'info'; message: string };
type Check = { id: string; name: string; criterion?: string; run(ctx: any): Finding[] };

const argv = process.argv.slice(2);
if (argv.includes('--help')) {
  console.log([
    '制图检查入口——三项检查：(e) 图源与渲染产物一致 · (w) 架构图文对齐 · (x) 架构跨层对齐',
    '',
    '用法：node --experimental-strip-types --disable-warning=ExperimentalWarning tool/diagram/check.mts [--staged | --root <目录>] [--criteria]',
    '  --staged    检查暂存区中 truth/ 的内容（提交钩子用）',
    '  --root      检查另一份仓库根',
    '  --criteria  只打印三项检查各自判什么，不运行',
    '退出码：0 无红；1 有红；2 检查无法运行',
  ].join('\n'));
  process.exit(0);
}

let checks: Check[];
try {
  const mod: any = await import('./checks.mts');
  if (!Array.isArray(mod?.checks) || mod.checks.some((c: any) => !c || typeof c.id !== 'string' || typeof c.run !== 'function')) {
    throw new Error('checks.mts 未按插件契约导出 checks 数组（每项须带 id 与 run）');
  }
  checks = mod.checks;
} catch (e) {
  console.error(`制图检查无法装载：${(e as Error).message}`);
  process.exit(2);
}

if (argv.includes('--criteria')) {
  for (const c of checks) console.log(`${c.id} ${c.name}\n  ${c.criterion ?? '（无自述）'}\n`);
  process.exit(0);
}

let root = ROOT;
let cleanup = (): void => {};
const rootAt = argv.indexOf('--root');
if (rootAt >= 0) {
  if (!argv[rootAt + 1]) { console.error('--root 缺目录'); process.exit(2); }
  root = resolve(argv[rootAt + 1]);
} else if (argv.includes('--staged')) {
  // 从索引导出 truth/：继承环境变量，提交钩子里的 GIT_INDEX_FILE（部分提交时的临时索引）照样生效
  const tmp = mkdtempSync(join(tmpdir(), 'diagram-staged-'));
  cleanup = () => rmSync(tmp, { recursive: true, force: true });
  try {
    const list = execFileSync('git', ['ls-files', '-z', '--', 'truth'], { cwd: ROOT, encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
    if (list.length) {
      execFileSync('git', ['checkout-index', '-z', '--stdin', `--prefix=${tmp}/`], { cwd: ROOT, input: list, stdio: ['pipe', 'ignore', 'pipe'] });
    }
  } catch (e) {
    cleanup();
    console.error(`无法从暂存区导出 truth/：${(e as Error).message.split('\n')[0]}`);
    process.exit(2);
  }
  root = tmp;
}

const ctx = { root, config: null, assembly: null, zones: null, layout: null, lib: null };
let reds = 0;
try {
  console.log(`制图检查（${argv.includes('--staged') ? '暂存区' : root === ROOT ? '工作区' : root}）`);
  for (const c of checks) {
    let fs: Finding[];
    try { fs = c.run(ctx); } catch (e) { fs = [{ level: 'red', message: `${c.id} 运行时异常：${(e as Error).message}` }]; }
    for (const f of fs) {
      if (f.level === 'red') reds++;
      console.log(`${f.level === 'red' ? '  红' : f.level === 'warn' ? '  黄' : '  绿'} ${c.id} ${f.message}`);
    }
  }
} finally {
  cleanup();
}
if (reds) {
  console.log(`\n${reds} 项红。修法：图陈旧或缺渲染——在仓库根运行 render-diagrams.mts 与 export-portable-svg.mts（命令见 tool/diagram/AGENTS.md），再暂存 truth/architecture/；图文或跨层不对齐——按《架构设计与制图规范》先改图源、再改边表。`);
  process.exit(1);
}
console.log('\n无红。');
