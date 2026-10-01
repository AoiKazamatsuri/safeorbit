#!/usr/bin/env -S node --experimental-strip-types --disable-warning=ExperimentalWarning
// 独立运行版注记：本件自 envshell 仓 packs/diagram/render-diagrams-accept.mts@4a439c5 承接。改动两处——其一：
// 两组依赖层二声明的用例（RG5／RR2／RR3 与 OG／OR 六例）在 registry.json 尚未声明 design_doc 与两张 l2_diagrams 时
// 记为 SKIP 并逐条打印原因（上游记为 FAIL——envshell 始终有层二图，项目在声明正式架构图之前没有）。
// 声明之后这两组照常判红绿；SKIP 不计为通过。其二：新增 RG7／RR4 一对用例，守独立运行版的「承载文档只收具名代码块」规则。
// 其余用例与判据逐字未改。用语对照见 tool/diagram/AGENTS.md。
// 蓝本溯源：tool/render-diagrams-accept.mts@c192490（首实例仓）；档位：第一档机械；手术：合成图纸区路径由写死常量改为
// **夹具自行解析本包登记表 settings.arch_zone**（不从被验件读，自证纪律不变），剥治理记号与沿革注记。
// T21-D2（2026-09-06，出厂件固定性例外）：增 RG5／RR2／RR3 跨层判据两侧用例（嵌套分组·分组框族属·部署型记号）与 RG6 产物前缀旋钮。
//
// 图渲染器默认头与有效源哈希夹具——红绿六组：
//   RG1 无头图源注入默认头（前缀逐字等于 DEFAULT_HEADER）
//   RG2 显式完整头原样保留（显式优先，不注入、不改写）
//   RR1 残缺头（未闭合／不以 config: 开头）响亮失败，不当显式头
//   RG3 有效源哈希含默认头——无头图源的哈希＝sha256(DEFAULT_HEADER＋原文) 前 16 位（默认头一变即重渲的正本）
//   RG4 外系统视图发现——<名>/<名>-*.mmd 入列；<名>.mmd（层三形态）与他名文件不入
//   RG5 跨层判据 (x) 绿——合成承载文档（两围栏＋两表＋指针表含一行部署型）＋嵌套分组的层三图源＋部署图源：
//       层三组件嵌在分组框里仍算本容器成员（内部边不要锚）、成员皆本族的分组框作端点算本族（层二内部边不要锚）、
//       部署型行免跨层判且列入豁免清单；三处任一改回旧判法即红（夹具不得自证）
//   RR2 部署型记号缺席即红——同一合成实例只去掉「部署型」记号，部署视图被当组件图型判、找不到本容器子图
//   RR3 嵌套组件的边界边缺锚即红——上溯不得把边界边也判成内部边
//   RG6 产物前缀旋钮——settings.product_prefix 为字符串即逐字作前缀（空串＝无前缀），缺键沿用承载文档名
// 纪律：只 import 渲染器导出的纯函数（renderSource／effectiveHash／DEFAULT_HEADER／listExternalViewSources／collectDiagrams／L3_SVG_PREFIX）
// 与判据插件的 checks（只读判据，不写盘），不起渲染引擎、零网络（RG4～RG6 用临时目录合成实例根，不碰真实区）。
import { createHash } from 'node:crypto';
import { mkdtempSync, mkdirSync, writeFileSync, rmSync, readFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, basename, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { DEFAULT_HEADER, renderSource, effectiveHash, listExternalViewSources, collectDiagrams, L3_SVG_PREFIX } from './render-diagrams.mts';
import { checks } from './checks.mts';

// 夹具自持的登记表解析（独立实装，不从被验件读）：被验件改设置来源或改发现规则而不同批改这里，RG4～RG6 即红
const PACK_DIR = fileURLToPath(new URL('.', import.meta.url)).replace(/\/$/, '');
const SETTINGS: any = ((): any => {
  try { return JSON.parse(readFileSync(join(PACK_DIR, 'registry.json'), 'utf8'))?.settings ?? {}; }
  catch { return {}; }
})();
const ARCH_ZONE = ((): string => {
  const s = SETTINGS.arch_zone;
  if (typeof s === 'string' && s.trim()) return s.trim().replace(/^\/+|\/+$/g, '');
  return 'truth/architecture';
})();
const ARCH_SUBDIR = basename(ARCH_ZONE);
const DESIGN_DOC: string = typeof SETTINGS.design_doc === 'string' ? SETTINGS.design_doc.trim() : '';
const L2_NAMES: string[] = Array.isArray(SETTINGS.l2_diagrams) ? SETTINGS.l2_diagrams.filter((s: any) => typeof s === 'string' && s) : [];
const ANCHOR: string = typeof SETTINGS.container_table_anchor === 'string' && SETTINGS.container_table_anchor ? SETTINGS.container_table_anchor : 'C3 组件详图（L3）';
const PREFIX: string | undefined = typeof SETTINGS.product_prefix === 'string' ? SETTINGS.product_prefix.trim() : undefined;

const PASS: string[] = [], FAIL: string[] = [], SKIP: string[] = [];
function check(name: string, cond: boolean, detail = ''): void {
  (cond ? PASS : FAIL).push(name);
  console.log(`  ${cond ? 'PASS' : 'FAIL'}  ${name}` + (detail && !cond ? ` —— ${detail}` : ''));
}
// 独立运行版：前置设置未声明时的用例记 SKIP（不计通过），原因逐条打印
function skip(name: string, why: string): void {
  SKIP.push(name);
  console.log(`  SKIP  ${name} —— ${why}`);
}
const sha16 = (s: string): string => createHash('sha256').update(s).digest('hex').slice(0, 16);

console.log('render-diagrams 默认头与有效源哈希夹具验收（红绿六组）');

const headless = 'graph TB\n    %% name: 夹具图\n    A --> B\n';
const explicit = '---\nconfig:\n  htmlLabels: false\n  layout: elk\n  elk:\n    nodePlacementStrategy: LINEAR_SEGMENTS\n---\n' + headless;

// RG1 无头注入
const r1 = renderSource(headless);
check('RG1 无头图源注入默认头', r1 === DEFAULT_HEADER + headless && DEFAULT_HEADER.startsWith('---\nconfig:\n'), r1.slice(0, 80));

// RG2 显式头优先
check('RG2 显式完整头原样保留（显式优先）', renderSource(explicit) === explicit);

// RR1 残缺头响亮失败（两形态）
const throws = (s: string): boolean => { try { renderSource(s); return false; } catch { return true; } };
check('RR1 残缺头响亮失败（未闭合）', throws('---\nconfig:\n  layout: elk\n' + headless));
check('RR1b 残缺头响亮失败（不以 config: 开头）', throws('---\nlayout: elk\n---\n' + headless));

// RG3 有效源哈希含默认头
check('RG3 有效源哈希按注入后文本计（默认头一变即重渲）',
  effectiveHash(headless) === sha16(DEFAULT_HEADER + headless) && effectiveHash(headless) !== sha16(headless)
  && effectiveHash(explicit) === sha16(explicit));

// RG4 外系统视图发现：合成图纸区（址取本包 settings）——foo/foo-a.mmd 应入列；foo/foo.mmd（层三形态）与 foo/bar-x.mmd 不入
{
  const root = mkdtempSync(join(tmpdir(), 'render-accept-'));
  mkdirSync(join(root, ARCH_ZONE, 'foo'), { recursive: true });
  writeFileSync(join(root, ARCH_ZONE, 'foo/foo-a.mmd'), 'graph TB\n    A --> B\n');
  writeFileSync(join(root, ARCH_ZONE, 'foo/foo.mmd'), 'graph TB\n    A --> B\n');
  writeFileSync(join(root, ARCH_ZONE, 'foo/bar-x.mmd'), 'graph TB\n    A --> B\n');
  const found = listExternalViewSources(root);
  check('RG4 外系统视图发现（<名>-*.mmd 入列、层三同名与他名不入）',
    found.length === 1 && found[0] === `${ARCH_SUBDIR}/foo/foo-a.mmd`, JSON.stringify(found));
  rmSync(root, { recursive: true, force: true });
}

// RG5／RR2／RR3 跨层判据 (x)：合成实例根——承载文档住 settings.design_doc 所指路径，层二图名取 settings.l2_diagrams
// （语境图第一、容器图第二），指针表锚取 settings.container_table_anchor；图源与表皆最小形：
//   层一：User Agent → EnvShell；层二：EnvShell 框内嵌「界面」分组（成员 AGENTS.md 为本族）与「环境运行时」，
//   边 1 外沿（携 C1 锚）、边 2 环境运行时→界面（分组框成员皆本族→内部边，不要锚）；
//   层三 rt：容器「环境运行时」内嵌「入口」「出口」两分组各一组件，边 1 外沿携 L2 锚、边 2 两组件之间（嵌套成员→内部边）、边 3 出口→界面携 L2 锚；
//   部署 dp：一张与容器分解无关的落位图，指针表以「部署型」记号登记。
const synth = (opts: { deployMark: boolean; anchorBoundary: boolean }): { root: string; findings: { level: string; message: string }[] } => {
  const root = mkdtempSync(join(tmpdir(), 'render-accept-x-'));
  const arch = join(root, ARCH_ZONE);
  const [C1, C2] = L2_NAMES;
  mkdirSync(join(arch, 'rt'), { recursive: true });
  mkdirSync(join(arch, 'dp'), { recursive: true });
  mkdirSync(dirname(join(root, DESIGN_DOC)), { recursive: true });
  writeFileSync(join(root, DESIGN_DOC), [
    '# 合成承载文档（夹具）', '',
    '```mermaid',
    'graph TB',
    `    %% name: ${C1}`, `    %% home: ${C1}`,
    '    UA["User Agent"]',
    '    ES["EnvShell"]',
    '    UA -->|"命令"| ES',
    '    class ES shell',
    '```', '',
    '| # | 边 | 完整语义 |', '|---|---|---|',
    '| 1 | User Agent → EnvShell：命令 | 接口：命令树 |', '',
    '```mermaid',
    'graph TB',
    `    %% name: ${C2}`, `    %% home: ${C2}`,
    '    UA["User Agent"]',
    '    subgraph ES["EnvShell"]',
    '        subgraph UI["界面"]',
    '            AG["AGENTS.md"]',
    '        end',
    '        RT["环境运行时"]',
    '    end',
    '    UA -->|"命令"| RT',
    '    RT -->|"渲染投影"| UI',
    '    class AG,RT shell',
    '```', '',
    '| # | 边 | 完整语义 |', '|---|---|---|',
    '| 1 | User Agent → 环境运行时：命令 | 接口：命令树。C1 边 1 |',
    '| 2 | 环境运行时 → 界面：渲染投影 | 接口：render。分组框成员皆本族，内部边 |', '',
    `#### ${ANCHOR}`, '',
    '| 容器 | 详设文档 | 图源 |', '|---|---|---|',
    `| 环境运行时 | ${ARCH_SUBDIR}/rt/rt.md | ${ARCH_SUBDIR}/rt/rt.mmd |`,
    `| 部署视图 | ${ARCH_SUBDIR}/dp/dp.md | ${ARCH_SUBDIR}/dp/dp.mmd${opts.deployMark ? '（部署型，物理落位视图，非容器分解）' : ''} |`,
  ].join('\n') + '\n');
  writeFileSync(join(arch, 'rt/rt.mmd'), [
    'graph TB',
    '    %% name: rt', '    %% home: rt',
    '    UA["User Agent"]',
    '    UI["界面"]',
    '    subgraph RT["环境运行时"]',
    '        subgraph IN["入口"]',
    '            A["命令行入口"]',
    '        end',
    '        subgraph OUT["出口"]',
    '            B["投影渲染器"]',
    '        end',
    '    end',
    '    UA -->|"命令"| A',
    '    A -->|"渲染"| B',
    '    B -->|"写投影"| UI',
    '    class A,B,UI shell',
    '    class UA ext',
  ].join('\n') + '\n');
  writeFileSync(join(arch, 'rt/rt.md'), [
    '# rt', '',
    '| # | 边 | 完整语义 |', '|---|---|---|',
    '| 1 | User Agent → 命令行入口：命令 | 接口：命令树。L2 边 1 |',
    '| 2 | 命令行入口 → 投影渲染器：渲染 | 接口：render。嵌套分组成员，内部边 |',
    `| 3 | 投影渲染器 → 界面：写投影 | 接口：写投影。${opts.anchorBoundary ? 'L2 边 2' : '（无锚）'} |`,
  ].join('\n') + '\n');
  writeFileSync(join(arch, 'dp/dp.mmd'), [
    'graph TB',
    '    %% name: dp', '    %% home: dp',
    '    subgraph HOST["本机"]',
    '        RTB["运行时（全局安装）"]',
    '        REPO["项目仓"]',
    '    end',
    '    RTB -->|"读写"| REPO',
    '    class RTB,REPO shell',
  ].join('\n') + '\n');
  writeFileSync(join(arch, 'dp/dp.md'), [
    '# dp', '',
    '| # | 边 | 完整语义 |', '|---|---|---|',
    '| 1 | 运行时 → 项目仓：读写 | 落位 |',
  ].join('\n') + '\n');
  const x = checks.find(c => c.id === '(x)')!;
  const findings = x.run({ root, config: null, assembly: null, zones: null, layout: null, lib: null });
  return { root, findings };
};
if (!DESIGN_DOC || L2_NAMES.length < 2) {
  skip('RG5 跨层判据 (x) 绿（嵌套分组·分组框族属·部署型记号）',
    `本包登记表 settings 须声明 design_doc 与两张 l2_diagrams（现 design_doc「${DESIGN_DOC || '（空）'}」、l2_diagrams ${JSON.stringify(L2_NAMES)}）——合成实例无从对照`);
  skip('RR2 部署型记号缺席即红', '前置同上');
  skip('RR3 嵌套组件的边界边缺锚即红', '前置同上');
} else {
  const g = synth({ deployMark: true, anchorBoundary: true });
  const reds = g.findings.filter(f => f.level === 'red').map(f => f.message);
  const infos = g.findings.filter(f => f.level === 'info').map(f => f.message).join('\n');
  check('RG5 跨层判据 (x) 绿（嵌套分组·分组框族属·部署型记号）',
    reds.length === 0 && infos.includes('部署型') && infos.includes('边界 2 边锚齐／反向 2 边全覆盖'),
    reds.length ? reds.slice(0, 3).join('｜') : infos.slice(0, 200));
  rmSync(g.root, { recursive: true, force: true });

  const r2 = synth({ deployMark: false, anchorBoundary: true });
  const reds2 = r2.findings.filter(f => f.level === 'red').map(f => f.message);
  check('RR2 部署型记号缺席即红（部署视图被当组件图型判）',
    reds2.length > 0 && reds2.some(m => m.includes('部署视图')), reds2.slice(0, 2).join('｜') || '（零红）');
  rmSync(r2.root, { recursive: true, force: true });

  const r3 = synth({ deployMark: true, anchorBoundary: false });
  const reds3 = r3.findings.filter(f => f.level === 'red').map(f => f.message);
  check('RR3 嵌套组件的边界边缺锚即红（上溯不把边界边判成内部边）',
    reds3.length > 0 && reds3.some(m => m.includes('x3') && m.includes('边 3')), reds3.slice(0, 2).join('｜') || '（零红）');
  rmSync(r3.root, { recursive: true, force: true });
}

// RG6 产物前缀旋钮：合成承载文档一围栏，产物名＝<home>/<前缀->名.svg——前缀为 settings.product_prefix 逐字（空串即无），
// 缺键则层二取承载文档基名、层三取 settings.design_doc 基名（L3_SVG_PREFIX 为其导出值）
{
  const root = mkdtempSync(join(tmpdir(), 'render-accept-p-'));
  const docZone = dirname(ARCH_ZONE) === '.' ? '' : dirname(ARCH_ZONE);
  mkdirSync(join(root, docZone), { recursive: true });
  mkdirSync(join(root, ARCH_ZONE, 'zz'), { recursive: true });
  writeFileSync(join(root, docZone, '夹具承载.md'), '# 夹具\n\n```mermaid\ngraph TB\n    %% name: pfx\n    %% home: pfx\n    A["甲"]\n    B["乙"]\n    A -->|"边"| B\n```\n');
  writeFileSync(join(root, ARCH_ZONE, 'zz/zz.mmd'), 'graph TB\n    %% name: zz\n    %% home: zz\n    A["甲"]\n    B["乙"]\n    A -->|"边"| B\n');
  const items = collectDiagrams(root);
  const l2 = items.find((it: any) => it.home === 'pfx')?.svg;
  const l3 = items.find((it: any) => it.home === 'zz')?.svg;
  const expL2 = PREFIX !== undefined ? PREFIX : '夹具承载';
  const expL3 = PREFIX !== undefined ? PREFIX : (DESIGN_DOC ? basename(DESIGN_DOC).replace(/\.[^.]+$/, '') : '');
  const nameOf = (p: string, n: string): string => `${n}/${p ? `${p}-` : ''}${n}.svg`;
  check('RG6 产物前缀旋钮（product_prefix 逐字作前缀、空串＝无前缀、缺键沿用承载文档名；层二层三同规）',
    l2 === nameOf(expL2, 'pfx') && l3 === nameOf(expL3, 'zz') && L3_SVG_PREFIX === expL3,
    `层二 ${l2}（期 ${nameOf(expL2, 'pfx')}）｜层三 ${l3}（期 ${nameOf(expL3, 'zz')}）｜L3_SVG_PREFIX「${L3_SVG_PREFIX}」`);
  rmSync(root, { recursive: true, force: true });
}

// RG7／RR4 承载文档只收具名代码块（独立运行版规则）：合成承载文档含一个具名块与两个无名块（流程图、时序图）——
// 具名块须入列且产物名取自报名；无名块是文档说明图，不得入列（收全部代码块＝把说明图扫进图纸区，即红）
{
  const root = mkdtempSync(join(tmpdir(), 'render-accept-named-'));
  const docZone = dirname(ARCH_ZONE) === '.' ? '' : dirname(ARCH_ZONE);
  mkdirSync(join(root, ARCH_ZONE), { recursive: true });
  writeFileSync(join(root, docZone, '夹具承载.md'), [
    '# 夹具', '',
    '```mermaid', 'flowchart TB', '    A["说明甲"] --> B["说明乙"]', '```', '',
    '```mermaid', 'graph TB', '    %% name: named-one', '    %% home: named-one', '    A["甲"]', '    B["乙"]', '    A -->|"边"| B', '```', '',
    '```mermaid', 'sequenceDiagram', '    participant U as 用户', '    U->>U: 自言自语', '```', '',
  ].join('\n'));
  const items = collectDiagrams(root);
  const nameOf = (n: string): string => `${n}/${PREFIX !== undefined ? (PREFIX ? `${PREFIX}-` : '') : '夹具承载-'}${n}.svg`;
  check('RG7 承载文档的具名代码块入列（产物名取自报名、落归巢目录）',
    items.length >= 1 && items.some((it: any) => it.svg === nameOf('named-one')),
    `收到 ${JSON.stringify(items.map((it: any) => it.svg))}（期 ${nameOf('named-one')}）`);
  check('RR4 承载文档的无名代码块不入列（说明图不进图纸区）',
    items.length === 1, `收到 ${items.length} 块：${JSON.stringify(items.map((it: any) => it.svg))}`);
  rmSync(root, { recursive: true, force: true });
}

// ---------- (e)(w) 红绿两侧（T59 批四·摸底 M1／M2：此前本包只有 (x) 有用例，(e)(w) 改坏了无人知） ----------
// 合成一个最小图纸区：一张层三图（图源＋承载文档边表＋产物＋两份清单＋可移植投影），
// 跑真判据 checks 的 (e)／(w)。不起渲染引擎——产物用图源哈希合成，判据本来也只比哈希。
{
  const eW = checks.find(c => c.id === '(e)')!;
  const wW = checks.find(c => c.id === '(w)')!;
  const ctxOf = (root: string) => ({ root, config: null, assembly: null, zones: null, layout: null, lib: null });
  const redsOf = (fs: any[]): string[] => fs.filter(f => f.level === 'red').map(f => f.message);

  type Tweak = { staleSrc?: boolean; straySvg?: boolean; portableStyle?: boolean; dropRow?: boolean; extraRow?: boolean; wrongKind?: boolean };
  const synthEW = (t: Tweak = {}): string => {
    const root = mkdtempSync(join(tmpdir(), 'render-accept-ew-'));
    const arch = join(root, ARCH_ZONE);
    mkdirSync(join(arch, 'zz'), { recursive: true });
    const src = 'graph TB\n    %% name: zz\n    %% home: zz\n    A["甲"]\n    B["乙"]\n    C["丙"]\n'
      + '    A -->|"实边"| B\n    B -.->|"虚边"| C\n';
    writeFileSync(join(arch, 'zz/zz.mmd'), src);
    // 承载文档：编号边表——(w) 判它与图源逐边机械等价
    const rows = [
      '| 1 | 甲 → 乙：实边 | 接口：夹具｜归属：夹具｜同步｜耦合：无 |',
      '| 2 | 乙 ⇢ 丙：虚边 | 供给：夹具｜触发：夹具 |',
    ];
    if (t.dropRow) rows.pop();
    if (t.extraRow) rows.push('| 3 | 甲 → 丙：查无此边 | 接口：夹具｜归属：夹具｜同步｜耦合：无 |');
    if (t.wrongKind) rows[1] = '| 2 | 乙 → 丙：虚边 | 接口：夹具｜归属：夹具｜同步｜耦合：无 |';
    writeFileSync(join(arch, 'zz/zz.md'), ['# zz', '', '| # | 边 | 完整语义 |', '|---|---|---|', ...rows].join('\n') + '\n');
    // 设计文档：本包登记表登记了它，「登记即在位」——合成实例须有这份件（无围栏块即层二段如实跳过）
    const dd = SETTINGS.design_doc;
    if (typeof dd === 'string' && dd) {
      mkdirSync(dirname(join(root, dd)), { recursive: true });
      writeFileSync(join(root, dd), '# 夹具承载文档\n\n本件无图源围栏块：层二段如实跳过，本组只判层三成对。\n');
    }
    // 产物与两份清单：名与哈希取共用收集器现算（不在夹具里抄第二份命名规则）
    const it = collectDiagrams(root).find((d: any) => d.home === 'zz')!;
    const svgAbs = join(arch, it.svg);
    mkdirSync(dirname(svgAbs), { recursive: true });
    writeFileSync(svgAbs, '<svg xmlns="http://www.w3.org/2000/svg"><g/></svg>\n');
    writeFileSync(join(arch, 'manifest.json'), JSON.stringify({ [it.svg]: { hash: it.hash } }, null, 2));
    const pname = `${dirname(it.svg)}/portable/${basename(it.svg).replace(/\.svg$/, '-portable.svg')}`;
    mkdirSync(dirname(join(arch, pname)), { recursive: true });
    writeFileSync(join(arch, pname), t.portableStyle
      ? '<svg xmlns="http://www.w3.org/2000/svg"><style>a{}</style><g/></svg>\n'
      : '<svg xmlns="http://www.w3.org/2000/svg"><g/></svg>\n');
    const srcHash = createHash('sha256').update(readFileSync(svgAbs)).digest('hex').slice(0, 16);
    writeFileSync(join(arch, 'portable-manifest.json'), JSON.stringify({ [pname]: { source_hash: srcHash } }, null, 2));
    if (t.straySvg) writeFileSync(join(arch, 'zz/没人登记过.svg'), '<svg xmlns="http://www.w3.org/2000/svg"/>\n');
    // 陈旧例：清单按**旧**源的哈希落定之后再改图源——先改源会让收集器现算出新哈希、清单跟着新，永远对得上
    if (t.staleSrc) writeFileSync(join(arch, 'zz/zz.mmd'), src.replace('丙', '丁'));
    return root;
  };

  const runOn = (t: Tweak, w: boolean): { reds: string[]; infos: string } => {
    const root = synthEW(t);
    try {
      const fs2 = (w ? wW : eW).run(ctxOf(root) as any);
      return { reds: redsOf(fs2), infos: fs2.filter((f: any) => f.level === 'info').map((f: any) => f.message).join('\n') };
    } finally { rmSync(root, { recursive: true, force: true }); }
  };

  const g1 = runOn({}, false);
  check('EG1 (e) 绿：产物与源一致·可移植投影新鲜四项归零·图纸区零孤儿',
    g1.reds.length === 0 && g1.infos.includes('1 张渲染产物与源一致') && g1.infos.includes('零孤儿'),
    g1.reds.slice(0, 2).join('｜') || g1.infos.slice(0, 160));

  const r1 = runOn({ staleSrc: true }, false);
  check('ER1 (e) 红：图源改了而清单没改（产物陈旧）',
    r1.reds.some(m => m.includes('图陈旧或缺渲染')), r1.reds.slice(0, 2).join('｜') || '（零红）');

  const r2 = runOn({ portableStyle: true }, false);
  check('ER2 (e) 红：可移植投影残留样式表（矢量工具导入即走形）',
    r2.reds.some(m => m.includes('残留') && m.includes('样式表')), r2.reds.slice(0, 2).join('｜') || '（零红）');

  const r3 = runOn({ straySvg: true }, false);
  check('ER3 (e) 红：图纸区有未登记产物（改名遗留与旧版滞留即版本混淆之源）',
    r3.reds.some(m => m.includes('孤儿产物')), r3.reds.slice(0, 2).join('｜') || '（零红）');

  const g2 = runOn({}, true);
  check('WG1 (w) 绿：图源两条边与承载文档边表逐边机械等价（端点＋标签＋线型全合）',
    g2.reds.length === 0 && g2.infos.includes('逐边机械等价'),
    g2.reds.slice(0, 2).join('｜') || g2.infos.slice(0, 160));

  const w1 = runOn({ dropRow: true }, true);
  check('WR1 (w) 红：图有文无——图源改了而边表没跟上',
    w1.reds.some(m => m.includes('图有文无')), w1.reds.slice(0, 2).join('｜') || '（零红）');

  const w2 = runOn({ extraRow: true }, true);
  check('WR2 (w) 红：文有图无——结构不得起源于文档（无豁免记号即红）',
    w2.reds.some(m => m.includes('文有图无')), w2.reds.slice(0, 2).join('｜') || '（零红）');

  const w3 = runOn({ wrongKind: true }, true);
  check('WR3 (w) 红：线型不符——同一条边图源记虚线、边表记实线',
    w3.reds.some(m => m.includes('线型不符')), w3.reds.slice(0, 2).join('｜') || '（零红）');
}

// ---------- 叠画锚两侧（T83）：容器层边表取自外系统视图·「＋」复合锚 ----------
// 合成实例：设计文档**无内嵌图源**（只带容器指针表与机制视图表）；层二容器图为外系统视图布局
// （<目录>/<层二图名>.mmd 与 <目录>/<目录>.md 内的归属边表节）；一个容器 ct；一个叠画机制 mech，其叠画边表
// 第 1 行锚「C2 边 1」、第 2 行复合锚「ct 边 2＋C2 边 2」。跑真判据 (w)：绿侧两例、红侧四例（OR4 归属边表节多命中＝歧义，锚侧不得将就取第一节，T83 独立验收余项）。
{
  const wW = checks.find(c => c.id === '(w)')!;
  const ctxOf = (root: string) => ({ root, config: null, assembly: null, zones: null, layout: null, lib: null });
  const redsOf = (fs: any[]): string[] => fs.filter(f => f.level === 'red').map(f => f.message);
  const C2 = L2_NAMES[1] ?? '';
  type OTweak = { badPart?: boolean; noExtSection?: boolean; dangling?: boolean; twoExtSections?: boolean };
  const synthOverlay = (t: OTweak = {}): { reds: string[]; infos: string } => {
    const root = mkdtempSync(join(tmpdir(), 'render-accept-overlay-'));
    const arch = join(root, ARCH_ZONE);
    const extDir = C2.slice(0, C2.lastIndexOf('-')); // 外系统视图目录名＝层二图名去末段（<目录>/<目录>-*.mmd）
    mkdirSync(join(arch, extDir), { recursive: true });
    mkdirSync(join(arch, 'ct'), { recursive: true });
    mkdirSync(join(arch, 'mech'), { recursive: true });
    // 设计文档内容：指针表（容器 ct）＋机制视图表（mech，叠画图型，联合反查初值记号）——无围栏块
    const designParts = [
      '# 合成设计文档（夹具，无内嵌图源）', '',
      `#### ${ANCHOR}`, '',
      '| 容器 | 详设文档 | 图源 |', '|---|---|---|',
      `| ct | ${ARCH_SUBDIR}/ct/ct.md | ${ARCH_SUBDIR}/ct/ct.mmd |`, '',
      '**机制视图**', '',
      '| 机制 | 详设文档 | 图源 | 图型 | 定稿依据 | 联合反查 |', '|---|---|---|---|---|---|',
      `| mech | ${ARCH_SUBDIR}/mech/mech.md | ${ARCH_SUBDIR}/mech/mech.mmd | 叠画图型 | 夹具 | 候首查 |`, '',
    ];
    // 外系统视图详设：层二容器图的归属边表节（标题含「边表」与图名）
    const extParts = t.noExtSection ? [`# ${extDir}`, '', '（本例故意不带边表节）', ''] : [
      `# ${extDir}`, '',
      `## 1 C2 容器图（${C2} 边表）`, '',
      '| # | 边 | 完整语义 |', '|---|---|---|',
      '| 1 | User Agent → 环境运行时：命令 | 接口：命令树 |',
      '| 2 | 环境运行时 → 界面：渲染投影 | 接口：render |', '',
      ...(t.twoExtSections ? [
        `## 2 C2 容器图副本（${C2} 边表）`, '',
        '| # | 边 | 完整语义 |', '|---|---|---|',
        '| 1 | User Agent → 环境运行时：命令 | 接口：命令树 |',
        '| 2 | 环境运行时 → 界面：渲染投影 | 接口：render |', '',
      ] : []),
    ];
    const designAbs = join(root, DESIGN_DOC);
    const extDocAbs = join(arch, extDir, `${extDir}.md`);
    mkdirSync(dirname(designAbs), { recursive: true });
    if (designAbs === extDocAbs) writeFileSync(designAbs, [...designParts, ...extParts].join('\n') + '\n'); // 设计文档即外系统视图详设（agentshell 布局）
    else { writeFileSync(designAbs, designParts.join('\n') + '\n'); writeFileSync(extDocAbs, extParts.join('\n') + '\n'); }
    writeFileSync(join(arch, extDir, `${C2}.mmd`), [
      'graph TB',
      '    UA["User Agent"]', '    RT["环境运行时"]', '    UI["界面"]',
      '    UA -->|"命令"| RT', '    RT -->|"渲染投影"| UI',
    ].join('\n') + '\n');
    writeFileSync(join(arch, 'ct/ct.mmd'), [
      'graph TB', '    %% name: ct', '    %% home: ct',
      '    A["甲"]', '    B["乙"]', '    C["丙"]',
      '    A -->|"一"| B', '    B -->|"二"| C',
    ].join('\n') + '\n');
    writeFileSync(join(arch, 'ct/ct.md'), [
      '# ct', '',
      '| # | 边 | 完整语义 |', '|---|---|---|',
      '| 1 | 甲 → 乙：一 | 接口：夹具 |',
      '| 2 | 乙 → 丙：二 | 接口：夹具 |', '',
    ].join('\n') + '\n');
    writeFileSync(join(arch, 'mech/mech.mmd'), [
      'graph TB', '    %% name: mech', '    %% home: mech',
      '    A["甲"]', '    B["乙"]', '    C["丙"]',
      '    A -->|"一"| B', '    B -->|"二"| C',
    ].join('\n') + '\n');
    const row2Anchor = t.badPart ? 'ct 边 2＋C2 边 9' : 'ct 边 2＋C2 边 2';
    writeFileSync(join(arch, 'mech/mech.md'), [
      '# mech', '',
      '| # | 转移 | 图标签 |', '|---|---|---|',
      '| 1 | 甲→乙 | 一 |', '| 2 | 乙→丙 | 二 |', '',
      '| # | 边 | 锚 | 法典行 | 语义 |', '|---|---|---|---|---|',
      `| 1 | 甲 → 乙：一 | ${t.dangling ? 'C2 边 7' : 'C2 边 1'} | 1 | 夹具 |`,
      `| 2 | 乙 → 丙：二 | ${row2Anchor} | 2 | 夹具 |`, '',
    ].join('\n') + '\n');
    try {
      const fs2 = wW.run(ctxOf(root) as any);
      return { reds: redsOf(fs2), infos: fs2.filter((f: any) => f.level === 'info').map((f: any) => f.message).join('\n') };
    } finally { rmSync(root, { recursive: true, force: true }); }
  };
  if (!DESIGN_DOC || L2_NAMES.length < 2 || !C2.includes('-')) {
    skip('OG1 叠画锚：容器层边表取自外系统视图（设计文档无内嵌图源）',
      `本包登记表 settings 须声明 design_doc 与两张 l2_diagrams（第二张为 <目录>-<名> 形）——现 design_doc「${DESIGN_DOC || '（空）'}」、l2_diagrams ${JSON.stringify(L2_NAMES)}`);
    skip('OG2 叠画复合锚「ct 边 2＋C2 边 2」各段皆判即绿', '前置同上');
    skip('OR1 复合锚含坏段「C2 边 9」即红并点名该段', '前置同上');
    skip('OR2 单锚悬空「C2 边 7」即红', '前置同上');
    skip('OR3 外系统视图无归属边表节即报容器层边表缺席', '前置同上');
    skip('OR4 外系统视图归属边表节多命中即锚侧报容器层边表缺席', '前置同上');
  } else {
    const g = synthOverlay();
    check('OG1 叠画锚：容器层边表取自外系统视图（设计文档无内嵌图源）——「C2 边 1」解析绿',
      g.reds.length === 0 && g.infos.includes('锚 2/2'), g.reds.slice(0, 3).join('｜') || g.infos.slice(0, 200));
    check('OG2 叠画复合锚「ct 边 2＋C2 边 2」各段皆判即绿（同一实例第 2 行）',
      g.reds.length === 0 && g.infos.includes('叠画图 2 边'), g.reds.slice(0, 3).join('｜') || g.infos.slice(0, 200));
    const r1 = synthOverlay({ badPart: true });
    check('OR1 复合锚含坏段「C2 边 9」即红并点名该段',
      r1.reds.some(m => m.includes('C2 边 9') && m.includes('引用悬空')) && !r1.reds.some(m => m.includes('无法机械判定')),
      r1.reds.slice(0, 3).join('｜') || '（零红）');
    const r2 = synthOverlay({ dangling: true });
    check('OR2 单锚悬空「C2 边 7」即红（容器层边表来自外系统视图时同判）',
      r2.reds.some(m => m.includes('C2 边 7') && m.includes('引用悬空')), r2.reds.slice(0, 3).join('｜') || '（零红）');
    const r3 = synthOverlay({ noExtSection: true });
    check('OR3 外系统视图无归属边表节即报容器层边表缺席（不静默走绿路）',
      r3.reds.some(m => m.includes('容器层边表缺席')), r3.reds.slice(0, 3).join('｜') || '（零红）');
    const r4 = synthOverlay({ twoExtSections: true });
    check('OR4 外系统视图归属边表节多命中（歧义）即锚侧报容器层边表缺席（不将就取第一节；外系统视图块另报歧义）',
      r4.reds.some(m => m.includes('容器层边表缺席')), r4.reds.slice(0, 3).join('｜') || '（零红）');
  }
}

console.log(`\n结果：PASS ${PASS.length} · FAIL ${FAIL.length}${SKIP.length ? ` · SKIP ${SKIP.length}（前置设置未声明，不计通过）` : ''}`);
if (FAIL.length) { console.log('未过用例：' + FAIL.join('、')); process.exit(1); }
