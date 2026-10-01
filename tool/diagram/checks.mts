// 独立运行版注记：本件自 envshell 仓 packs/diagram/checks.mts@4a439c5 逐字承接，只改开头这段注记（判据代码零改动）。
// 下文沿用上游用语：「本包」＝tool/diagram/，「本包登记表」＝tool/diagram/registry.json，「机检器」＝tool/diagram/check.mts，
// 「提交闸」＝tool/diagram/pre-commit.sh；「域包／元工具／三池」是 envshell 的装卸机制，独立运行版不设（见 tool/diagram/AGENTS.md）。
// 蓝本溯源：tool/envcheck-es.mts@c192490（首实例仓）；档位：第一档机械；手术：自机检器抽出图族三判据改为域包判据插件，图纸区与设计文档、层二图名、端点别名一律读本包登记表 settings，注记去实例沿革。
// T21-D2（2026-09-06，出厂件固定性例外）：(x) ①容器成员判定沿子图链上溯（嵌套分组算本容器成员）；②成员皆本族的带标签子图视为本族
//   （每图一算 family，不折叠、算内部边）；③容器指针表图源列带「部署型」记号者免跨层判但计入覆盖声明（记号闭集扩一项）。
// T83（2026-09-26，出厂件修正）：叠画图型两处——①容器层边表来源：设计文档无内嵌容器图源时，取 settings.l2_diagrams 第二张所指的
//   外系统视图图源，在其同目录详设内按外系统视图规则找归属边表节（标题含「边表」且含图名余名），行号供「C2 边 N」解析；
//   ②锚列接受全角「＋」连写的复合锚，每段各按三型判、任一段坏即红并点名该段。出厂默认布局（设计文档内嵌层二图源）行为零变化。
//
// 制图域包判据插件（三项）：
//   (e) 图源与渲染产物一致  (w) 架构图文对齐  (x) 架构跨层对齐
// 插件契约（由机检器装载）：export const checks: Array<{ id; name; run(ctx): Finding[] }>；
//   ctx＝{ root, config, assembly, zones, layout, lib }；Finding＝{ level: 'red'|'warn'|'info', message }。
//   红与通用判据同权——判据住哪儿是组织问题，不是效力问题。
// 本包的实例差异全部经**本包登记表顶层 settings** 进入，源码零实例常量：
//   arch_zone（图纸区住址，必填——缺即整族如实跳过）· design_doc（承载层二图与声明表的设计文档，可为 null）·
//   l2_diagrams（层二图名清单，缺即层二段跳过）· node_aliases（同层端点别名，登记即受审）·
//   cross_layer_aliases（跨层同实体异名对）· mechanism_pending_marker（机制视图联合反查列的合法初值记号）。
import { existsSync, readFileSync, readdirSync, statSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { basename, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { collectDiagrams, extractMermaidBlocksWithSpan, listExternalViewSources, listL3Sources } from './render-diagrams.mts';

type Finding = { level: 'red' | 'warn' | 'info'; message: string };
type CheckContext = { root: string; config: any; assembly: any; zones: any; layout: any; lib: any };

const PACK_DIR = fileURLToPath(new URL('.', import.meta.url)).replace(/\/$/, '');
const SETTINGS: any = (() => {
  try { return JSON.parse(readFileSync(join(PACK_DIR, 'registry.json'), 'utf8'))?.settings ?? {}; }
  catch { return {}; }
})();
const esc = (s: string): string => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

// ---------- 共用形态（图源解析·边表解析·端点解析·比对）----------
// 线型三型：图源写法 ↔ 边表记号 ↔ 人话（读图法正本在本包区契约的图样式语义段）
const W_KIND_MARK: Record<string, string> = { solid: '→', bidi: '↔', dashed: '⇢' };
const W_KIND_NAME: Record<string, string> = { solid: '实线', bidi: '双向实线', dashed: '虚线' };
const W_ARROW_KIND: Record<string, string> = { '-->': 'solid', '<-->': 'bidi', '-.->': 'dashed' };
// 未知边语法绊线：凡含边连接符而不匹配受支持三型的非声明行响亮报红——
// 静默忽略是 fail-open（漏掉的边会以「文有图无」的错误诊断现身，或整条关系凭空消失）。
const W_EDGE_HINT = /-{2,}|-\.|\.-|={2,}|~{3,}|<-|->/;
// 豁免记号闭集（扩集须裁决）：全角定界、精确 token 匹配，故否定散文不被误判为豁免
const X_NOTIN = '〔不入图〕';
const X_SUB_L2 = '〔低于 L2 分辨率〕';
const X_SUB_C1 = '〔低于 C1 分辨率〕';
const X_PENDING = '〔L3 落点候定〕';
const X_PENDING_ONE = /〔L3 落点候定：[^〔〕]*〕/;
const X_PENDING_ALL = /〔L3 落点候定：[^〔〕]*〕/g;
const X_MARKS = [X_NOTIN, X_SUB_L2, X_SUB_C1];
// 叠画边表的记号闭集
const O_NONTRANS = '〔非转移流〕'; // 结构服务流（本机制穿行但不构成法典转移的边）
const O_ALLROWS = '全部行';        // 全表引用（该边承载法典表每一行）

type WNode = { id: string; short: string; full: string; sub: string | null };
type WEdge = { from: string; to: string; label: string; kind: string; num?: string; fromId?: string; toId?: string };
type WGraph = {
  displays: string[]; edges: WEdge[]; issues: string[];
  nodes: Map<string, WNode>; byName: Map<string, WNode>; subs: Map<string, WNode>; shell: Set<string>;
  family: Set<string>; // 本系统一族＝shell ∪ 成员皆本族的带标签子图（每图一算，见 wFamily）
};
type WRow = WEdge & { line: string; marks: string[] };

// 节点显示名规整：取换行标记前段（盒子首行即名称），再截去首个全角括号及其后
// ——边表按体例写短名；全显示名保留全部行，供跨层类别判定的「互含」用。
const wClean = (s: string): string => s.replace(/\*\*/g, '').trim();
const wDisplay = (raw: string): string => wClean(raw.split('<br/>')[0].split('（')[0]);
const wFull = (raw: string): string => wClean(raw.split('<br/>').map(s => s.trim()).join(' '));

/**
 * 图源解析：节点定义、带标签子图（登记为合法端点，显示名取标签串，并保留成员的子图归属）与边行三型；
 * 注释行、图头、样式声明、围栏配置头一概不入；class 行只取本系统一族（用于跨层判外沿边）。
 */
function wParseGraph(src: string): WGraph {
  const nodes = new Map<string, WNode>();
  const subs = new Map<string, WNode>();
  const shell = new Set<string>();
  const edges: WEdge[] = [];
  const issues: string[] = [];
  const stack: string[] = [];
  let body = src;
  // 围栏配置头整段跳过：其行不是图语法，若参与「未知边语法」判定会假红
  const fmBlock = body.match(/^\s*---\n[\s\S]*?\n---\n/);
  if (fmBlock) body = body.slice(fmBlock[0].length);
  for (const raw of body.split('\n')) {
    const line = raw.trim();
    if (!line || line.startsWith('%%')) continue;
    if (/^(graph|flowchart|classDef|style|linkStyle|direction)\b/.test(line)) continue;
    if (/^class\b/.test(line)) {
      const c = line.match(/^class\s+(\S+)\s+([A-Za-z_][\w-]*)\s*$/);
      if (c && c[2] === 'shell') c[1].split(',').map(s => s.trim()).filter(Boolean).forEach(id => shell.add(id));
      continue;
    }
    if (line === 'end') { stack.pop(); continue; }
    const sg = line.match(/^subgraph\s+([A-Za-z_][\w-]*)\["([^"]*)"\]$/);
    if (sg) {
      const node: WNode = { id: sg[1], short: wDisplay(sg[2]), full: wFull(sg[2]), sub: stack[stack.length - 1] ?? null };
      nodes.set(sg[1], node); subs.set(sg[1], node); stack.push(sg[1]);
      continue;
    }
    const sgBare = line.match(/^subgraph\s+(\S+)\s*$/);
    if (sgBare) { stack.push(sgBare[1]); continue; } // 无标签子图：只作用域不作端点
    const n = line.match(/^([A-Za-z_][\w-]*)\["([^"]*)"\]$/);
    if (n) {
      nodes.set(n[1], { id: n[1], short: wDisplay(n[2]), full: wFull(n[2]), sub: stack[stack.length - 1] ?? null });
      continue;
    }
    const e = line.match(/^([A-Za-z_][\w-]*)\s*(<-->|-\.->|-->)\|"([^"]*)"\|\s*([A-Za-z_][\w-]*)$/);
    if (e) { edges.push({ from: e[1], to: e[4], label: wClean(e[3]), kind: W_ARROW_KIND[e[2]] }); continue; }
    if (W_EDGE_HINT.test(line)) {
      issues.push(`未支持的边语法：「${line.slice(0, 60)}」（受支持三型：--> ／ -.-> ／ <-->，且带标签管道——不静默忽略）`);
    }
  }
  // 端点 id 换显示名；未定义 id 即图源自身缺陷，响亮报出（不静默拿 id 冒充名字）
  for (const e of edges) {
    e.fromId = e.from; e.toId = e.to;
    for (const side of ['from', 'to'] as const) {
      const id = e[side];
      if (!nodes.has(id)) { issues.push(`图源边端点「${id}」无节点定义`); continue; }
      e[side] = nodes.get(id)!.short;
    }
  }
  const byName = new Map<string, WNode>();
  for (const nd of nodes.values()) if (!byName.has(nd.short)) byName.set(nd.short, nd);
  return { displays: [...new Set([...nodes.values()].map(n => n.short))], edges, issues, nodes, byName, subs, shell, family: wFamily(nodes, subs, shell) };
}

/**
 * 本系统一族（每图一算）：`class … shell` 声明的节点 ∪「成员非空且（递归）全在族内」的带标签子图。
 * 分组框是布局约定（制图规范第 7 节）：其成员皆本族时它自己就是本族——作端点时不折叠为外部子图、两端皆族内者算内部边。
 * 无成员的子图不入族（空框不代表任何本系统件）；无标签子图不是端点，不参与。
 */
function wFamily(nodes: Map<string, WNode>, subs: Map<string, WNode>, shell: Set<string>): Set<string> {
  const family = new Set(shell);
  const members = new Map<string, string[]>();
  for (const nd of nodes.values()) {
    if (!nd.sub) continue;
    if (!members.has(nd.sub)) members.set(nd.sub, []);
    members.get(nd.sub)!.push(nd.id);
  }
  const inFamily = (id: string): boolean => {
    if (family.has(id)) return true;
    if (!subs.has(id)) return false;
    const kids = members.get(id) ?? [];
    if (!kids.length || !kids.every(inFamily)) return false;
    family.add(id);
    return true;
  };
  for (const id of subs.keys()) inFamily(id);
  return family;
}

const wRowMarks = (line: string): string[] => {
  const m = X_MARKS.filter(x => line.includes(x));
  if (X_PENDING_ONE.test(line)) m.push(X_PENDING);
  return m;
};
/**
 * 边表行解析：首列为行号、次列为「X → Y：label」——label 取分隔号后至单元格尾并剥去尾随括注
 * （治理批注按体例入括注，不属图源标签）。首列非数字的表自然落选；
 * 携不入图记号者为显式豁免行，不要求图源有边（记号在行内任一列均生效）。
 */
function wParseRows(text: string): { rows: WRow[]; exemptRows: WRow[]; unparsable: string[] } {
  const rows: WRow[] = [];
  const exemptRows: WRow[] = [];
  const unparsable: string[] = [];
  for (const raw of text.split('\n')) {
    const line = raw.trim();
    if (!line.startsWith('|') || !line.endsWith('|')) continue;
    const cells = line.slice(1, -1).split('|').map(c => c.trim());
    if (cells.length < 2 || !/^\d+$/.test(cells[0])) continue;
    const spec = cells[1];
    const marks = wRowMarks(line);
    if (marks.includes(X_NOTIN)) {
      exemptRows.push({ from: '', to: '', label: '', kind: '', num: cells[0], line, marks });
      continue;
    }
    const hit = Object.entries(W_KIND_MARK).map(([kind, mark]) => ({ kind, at: spec.indexOf(mark) }))
      .filter(x => x.at >= 0).sort((a, b) => a.at - b.at)[0];
    if (!hit) { unparsable.push(`第 ${cells[0]} 行无线型记号（→ ↔ ⇢ 之一）：${spec}`); continue; }
    const rest = spec.slice(hit.at + 1);
    const at = rest.indexOf('：');
    if (at < 0) { unparsable.push(`第 ${cells[0]} 行缺分隔号后的边标签：${spec}`); continue; }
    rows.push({
      from: wClean(spec.slice(0, hit.at)),
      to: wClean(rest.slice(0, at)),
      label: wClean(rest.slice(at + 1)).replace(/（[^（）]*）\s*$/, '').trim(),
      kind: hit.kind,
      num: cells[0],
      line,
      marks,
    });
  }
  return { rows, exemptRows, unparsable };
}

const wKey = (e: WEdge): string => `${e.from} ${W_KIND_MARK[e.kind]} ${e.to}：${e.label}`;

// ---------- 一次解析三判据共用（同一数据根只算一次） ----------
type Computed = { e: Finding[]; w: Finding[]; x: Finding[] };
const CACHE = new Map<string, Computed>();
const red = (m: string): Finding => ({ level: 'red', message: m });
const info = (m: string): Finding => ({ level: 'info', message: m });

function computeAll(ctx: CheckContext): Computed {
  const root = ctx.root;
  const out: Computed = { e: [], w: [], x: [] };
  const ARCH = typeof SETTINGS.arch_zone === 'string' && SETTINGS.arch_zone.trim()
    ? SETTINGS.arch_zone.trim().replace(/\/$/, '') : '';
  if (!ARCH) {
    const m = info('图纸区未在本包登记表 settings.arch_zone 声明——本族三判据如实跳过（登记了才判，不猜路径）');
    out.e.push(m); out.w.push(m); out.x.push(m);
    return out;
  }
  const ARCH_ABS = join(root, ARCH);
  const ARCH_BASE = basename(ARCH);
  const ARCH_PARENT = ARCH.includes('/') ? ARCH.slice(0, ARCH.lastIndexOf('/')) : '';
  /** 收集器与声明表给出的路径可能相对图纸区容器、也可能相对实例根——两种体例都认，归一为仓库相对。 */
  const toRootRel = (rel: string): string => {
    if (!rel || rel.startsWith(`${ARCH}/`) || !ARCH_PARENT) return rel;
    return rel.startsWith(`${ARCH_BASE}/`) ? `${ARCH_PARENT}/${rel}` : rel;
  };
  const absOf = (rel: string): string => join(root, toRootRel(rel));
  const DESIGN = typeof SETTINGS.design_doc === 'string' && SETTINGS.design_doc.trim() ? SETTINGS.design_doc.trim() : '';
  const L2_NAMES: string[] = Array.isArray(SETTINGS.l2_diagrams) ? SETTINGS.l2_diagrams.filter((s: any) => typeof s === 'string' && s) : [];
  // 端点别名（登记即受审，表外短写一律红）：不可由显示名机械派生的等价指称登记于此；
  // 长名的唯一前缀短写由前缀规则覆盖，不入表。
  const W_ALIAS: Record<string, string> = SETTINGS.node_aliases && typeof SETTINGS.node_aliases === 'object' && !Array.isArray(SETTINGS.node_aliases)
    ? SETTINGS.node_aliases : {};
  // 跨层别名（层间同实体异名）：只收「互含规则」不及者——登记即受审
  const X_CROSS_ALIAS: [string, string][] = Array.isArray(SETTINGS.cross_layer_aliases)
    ? SETTINGS.cross_layer_aliases.filter((p: any) => Array.isArray(p) && p.length === 2) : [];
  const PENDING_MARK = typeof SETTINGS.mechanism_pending_marker === 'string' && SETTINGS.mechanism_pending_marker
    ? SETTINGS.mechanism_pending_marker : '候首查';

  // ---------- (e) 图源与渲染产物一致 ----------
  let diagrams: any[] = [];
  {
    const eIss: string[] = [];
    const eOk: string[] = [];
    let collectErr = '';
    try { diagrams = collectDiagrams(root) ?? []; }
    catch (err) { collectErr = String((err as Error)?.message ?? err).split('\n')[0]; }
    if (collectErr) eIss.push(`图源收集失败：${collectErr}（残缺围栏头或不可读图源——收集器不静默跳过）`);
    // 收集器失址绊线：图纸区在盘上有图源、而收集器一张也没收到，只有一个解释——两者不在同一个址上。
    // 这种「闸还在、覆盖归零」的形态必须响亮，不许静默走「无图块，跳过」的绿路。
    let archMmd = 0;
    try {
      for (const d of readdirSync(ARCH_ABS)) {
        try { if (statSync(join(ARCH_ABS, d)).isDirectory()) archMmd += readdirSync(join(ARCH_ABS, d)).filter(f => f.endsWith('.mmd')).length; } catch { /* 跳过 */ }
      }
    } catch { /* 无图纸区：archMmd 保持 0 */ }
    const MANIFEST = join(ARCH_ABS, 'manifest.json');
    if (!collectErr && diagrams.length === 0 && archMmd > 0) {
      eIss.push(`图源收集器覆盖归零：图纸区 ${ARCH} 下有 ${archMmd} 份图源件，而共用收集器一份未收——`
        + '收集器的图纸区与本包登记表 settings.arch_zone 走散了，三判据在架构面同时失明；闸存在不等于闸覆盖，不静默走绿路');
    } else if (!collectErr && diagrams.length === 0) {
      eOk.push('无图块，跳过');
    } else if (!collectErr && !existsSync(MANIFEST)) {
      eIss.push(`有 ${diagrams.length} 张图但无渲染清单 ${ARCH}/manifest.json（跑本包渲染器）`);
    } else if (!collectErr) {
      const manifest = JSON.parse(readFileSync(MANIFEST, 'utf8'));
      let bad = 0;
      for (const it of diagrams) {
        const rec = manifest[it.svg];
        if (!rec || rec.hash !== it.hash || !existsSync(join(ARCH_ABS, it.svg))) {
          bad++;
          eIss.push(`图陈旧或缺渲染：${it.svg}（源 ${it.doc}）`);
        }
      }
      if (bad === 0) eOk.push(`${diagrams.length} 张渲染产物与源一致`);
    }
    // 可移植投影：第二投影须在位、新鲜、四项归零（矢量工具导入用：样式全内联／实体箭头／零样式表零类引用零标记）
    if (diagrams.length > 0) {
      const PORTABLE = join(ARCH_ABS, 'portable-manifest.json');
      if (!existsSync(PORTABLE)) {
        eIss.push(`缺可移植投影清单 ${ARCH}/portable-manifest.json（跑本包导出器）`);
      } else {
        const pm = JSON.parse(readFileSync(PORTABLE, 'utf8')) as Record<string, { source_hash?: string }>;
        let pBad = 0;
        for (const it of diagrams) {
          const home = it.svg.includes('/') ? it.svg.slice(0, it.svg.lastIndexOf('/')) : '';
          const base = it.svg.slice(it.svg.lastIndexOf('/') + 1);
          const pname = `${home ? home + '/' : ''}portable/${base.replace(/\.svg$/, '-portable.svg')}`;
          const ppath = join(ARCH_ABS, pname);
          if (!existsSync(ppath) || !pm[pname]) { pBad++; eIss.push(`缺可移植投影：${pname}（跑导出器）`); continue; }
          const cur = createHash('sha256').update(readFileSync(join(ARCH_ABS, it.svg))).digest('hex').slice(0, 16);
          if (pm[pname].source_hash !== cur) { pBad++; eIss.push(`可移植投影陈旧（源已变）：${pname}（重跑导出器）`); continue; }
          const body = readFileSync(ppath, 'utf8');
          const residue: string[] = [];
          if (body.includes('<foreignObject')) residue.push('嵌套文字');
          if (body.includes('<style')) residue.push('样式表');
          if (/\sclass="/.test(body)) residue.push('类引用');
          if (body.includes('<marker')) residue.push('箭头标记');
          if (residue.length) { pBad++; eIss.push(`可移植投影不合格（残留：${residue.join('、')}）：${pname}`); }
        }
        if (pBad === 0) eOk.push(`可移植投影 ${diagrams.length} 张在位、新鲜、四项归零`);
      }
    }
    // 孤儿检查：区内任何未登记于两份清单的产物即残留（改名遗留、手工混入、旧版滞留皆版本混淆之源）
    if (existsSync(ARCH_ABS)) {
      const allowed = new Set<string>();
      try { for (const k of Object.keys(JSON.parse(readFileSync(join(ARCH_ABS, 'manifest.json'), 'utf8')))) allowed.add(k); } catch { /* 缺清单已在上文报红 */ }
      try { for (const k of Object.keys(JSON.parse(readFileSync(join(ARCH_ABS, 'portable-manifest.json'), 'utf8')))) allowed.add(k); } catch { /* 同上 */ }
      const stray: string[] = [];
      const walkSvg = (dir: string): void => {
        let entries: string[] = [];
        try { entries = readdirSync(join(ARCH_ABS, dir || '.')); } catch { return; }
        for (const e of entries) {
          const rel = dir ? `${dir}/${e}` : e;
          let st; try { st = statSync(join(ARCH_ABS, rel)); } catch { continue; }
          if (st.isDirectory()) walkSvg(rel);
          else if (e.endsWith('.svg') && !allowed.has(rel)) stray.push(rel);
        }
      };
      walkSvg('');
      if (stray.length) eIss.push(`图纸区孤儿产物（未登记于任何清单——清理或重渲）：${stray.join('、')}`);
      else eOk.push('图纸区零孤儿：全部产物均在清单登记');
    }
    eIss.forEach(m => out.e.push(red(`图源与渲染一致：${m}`)));
    if (!eIss.length) out.e.push(info(`图源与渲染一致：${eOk.join('；')} ✓`));
  }

  // ---------- (w)／(x) 共用解析 ----------
  // 端点名解析：同名优先 → 别名表 → 长名的唯一前缀；歧义与无解皆红（闸不猜）
  const wResolve = (s: string, displays: string[]): { name?: string; err?: string } => {
    if (displays.includes(s)) return { name: s };
    if (W_ALIAS[s] && displays.includes(W_ALIAS[s])) return { name: W_ALIAS[s] };
    const pre = displays.filter(d => d.startsWith(s));
    if (pre.length === 1) return { name: pre[0] };
    if (pre.length > 1) return { err: `端点「${s}」指称歧义（图上「${pre.join('」「')}」皆以此开头）` };
    return { err: `端点「${s}」在图源找不到同名节点（别名须登记于本包 settings.node_aliases）` };
  };
  // 逐对比对：边集多重集等价（多重边按条数配平），线型不符单独诊断
  const wCompare = (pair: string, src: string, docRel: string, docText: string): { issues: string[]; count: number; exempt: number } => {
    const issues: string[] = [];
    const g = wParseGraph(src);
    g.issues.forEach(x => issues.push(`${pair}：${x}`));
    const { rows, exemptRows, unparsable } = wParseRows(docText);
    const exempt = exemptRows.length;
    unparsable.forEach(x => issues.push(`${pair}：边表行无法机械判定——${x}（归位格式或列进汇报由人定夺，闸不猜）`));
    const tList: WEdge[] = [];
    for (const r of rows) {
      const f = wResolve(r.from, g.displays), t = wResolve(r.to, g.displays);
      if (f.err || t.err) { issues.push(`${pair}：${docRel} 边表第 ${r.num} 行端点解析失败——${f.err ?? t.err}`); continue; }
      tList.push({ ...r, from: f.name!, to: t.name! });
    }
    const gRemain = [...g.edges];
    const tRemain: WEdge[] = [];
    for (const t of tList) {
      const i = gRemain.findIndex(x => wKey(x) === wKey(t));
      if (i >= 0) gRemain.splice(i, 1); else tRemain.push(t);
    }
    for (const t of [...tRemain]) { // 端点与标签相合、只线型不同：报一条精确诊断，两侧各消一条
      const i = gRemain.findIndex(x => x.from === t.from && x.to === t.to && x.label === t.label);
      if (i < 0) continue;
      const g0 = gRemain[i];
      issues.push(`${pair}：线型不符——${docRel} 边表第 ${t.num} 行记「${W_KIND_MARK[t.kind]}」（${W_KIND_NAME[t.kind]}），图源为「${W_KIND_MARK[g0.kind]}」（${W_KIND_NAME[g0.kind]}）：${g0.from}／${g0.to}：${g0.label}`);
      gRemain.splice(i, 1);
      tRemain.splice(tRemain.indexOf(t), 1);
    }
    gRemain.forEach(g0 => issues.push(`${pair}：图有文无——图源边「${wKey(g0)}」在 ${docRel} 边表无对应行（图源变动，文档须同步更新）`));
    tRemain.forEach(t => issues.push(`${pair}：文有图无——${docRel} 边表第 ${t.num} 行「${wKey(t)}」在图源无对应边（结构不得起源于文档；表有图无须携不入图豁免记号）`));
    return { issues, count: rows.length, exempt };
  };

  // 设计文档与其内层二图源区间（两判据共用一次读取与一次围栏解析）
  const dAbs = DESIGN ? join(root, DESIGN) : '';
  const dText = dAbs && existsSync(dAbs) ? readFileSync(dAbs, 'utf8') : '';
  const spans = dText ? extractMermaidBlocksWithSpan(dText) : [];
  const l2Region = (name: string): { src: string; region: string } | null => {
    const i = spans.findIndex((b: any) => new RegExp(`%%\\s*name[:：]\\s*${esc(name)}`).test(b.src));
    if (i < 0) return null;
    return { src: spans[i].src, region: dText.slice(spans[i].end, spans[i + 1]?.start ?? dText.length) };
  };
  // 层二视图的图源＋边表（端点已解析为图源显示名；解析失败的行由 (w) 报，(x) 不叠报）
  const xView = (name: string): { g: WGraph; rows: WRow[]; exemptRows: WRow[] } | null => {
    const v = l2Region(name);
    if (!v) return null;
    const g = wParseGraph(v.src);
    const p = wParseRows(v.region);
    const rows: WRow[] = [];
    for (const r of p.rows) {
      const f = wResolve(r.from, g.displays), t = wResolve(r.to, g.displays);
      if (f.err || t.err) continue;
      rows.push({ ...r, from: f.name!, to: t.name! });
    }
    return { g, rows, exemptRows: p.exemptRows };
  };
  const L2_CONTAINER = L2_NAMES[1] ?? L2_NAMES[0] ?? ''; // 容器层图＝声明清单第二张（第一张为系统语境图）
  const L2_CONTEXT = L2_NAMES[0] ?? '';

  // ---------- 叠画图型判定器：底图纪律（叠画不得发明结构，锚须可解析） ----------
  const O_NUMS = '(\\d+(?:／\\d+)*)';
  const O_A_C2 = new RegExp(`^C2\\s*边\\s*${O_NUMS}$`);
  const O_A_LAW = new RegExp(`^法典行\\s*${O_NUMS}$`);
  const O_A_L3 = new RegExp(`^([A-Za-z0-9_-]+)\\s*边\\s*${O_NUMS}$`);
  const O_ROWNUMS = new RegExp(`^${O_NUMS}$`);
  const oNums = (s: string): number[] => s.split('／').map(Number);
  type OTable = { header: string[]; rows: { num: string; cells: string[] }[]; region: string };
  // 表定位器：按表头列名找到那张表，返回表头、编号行与原文区间（供边表解析判边集）。
  // 区间止于首个非表行——同文档内的另一张表不会被卷进来。
  const oFindTable = (text: string, mustHave: string[]): OTable | null => {
    const lines = text.split('\n');
    for (let i = 0; i < lines.length; i++) {
      const h = lines[i].trim();
      if (!h.startsWith('|') || !h.endsWith('|')) continue;
      const header = h.slice(1, -1).split('|').map(c => wClean(c));
      if (!mustHave.every(k => header.includes(k))) continue;
      const raw: string[] = [];
      const rows: { num: string; cells: string[] }[] = [];
      for (let j = i; j < lines.length; j++) {
        const l = lines[j].trim();
        if (!l.startsWith('|') || !l.endsWith('|')) break;
        raw.push(lines[j]);
        const cells = l.slice(1, -1).split('|').map(c => wClean(c));
        if (/^\d+$/.test(cells[0])) rows.push({ num: cells[0], cells });
      }
      return { header, rows, region: raw.join('\n') };
    }
    return null;
  };
  // 外系统视图的归属边表节：二级标题含「边表」，区间到下一个二级标题；图名余名＝图源自报名去首段（无自报名取件名）。
  // 一处实现，两处调用（下方外系统视图块与叠画锚的容器层边表回退，T83）——不各写一份规则。
  const wNorm = (s: string): string => s.replace(/[\s　]+/g, '');
  const extSections = (docText: string): { title: string; region: string }[] => {
    const dLines = docText.split('\n');
    const secs: { title: string; region: string }[] = [];
    for (let i = 0; i < dLines.length; i++) {
      const m = dLines[i].match(/^##\s+(.+)$/);
      if (!m) continue;
      let j = i + 1;
      while (j < dLines.length && !/^##\s/.test(dLines[j])) j++;
      if (m[1].includes('边表')) secs.push({ title: wClean(m[1]), region: dLines.slice(i, j).join('\n') });
      i = j - 1;
    }
    return secs;
  };
  const extFigureOf = (src: string, rel: string): { figure: string; stem: string } => {
    const named = src.match(/%%\s*name[:：]\s*([^\s%]+)/);
    const figure = named ? named[1] : basename(rel, '.mmd');
    const stem = figure.includes('-') ? figure.slice(figure.indexOf('-') + 1) : figure;
    return { figure, stem };
  };
  /**
   * 容器层边表的回退来源（T83）：设计文档内无内嵌容器图源时，取层二图名清单第二张所指的外系统视图图源，
   * 在其同目录详设内找唯一归属边表节，解析行号。零命中或歧义由外系统视图块上报，此处返 null（锚即报「容器层边表缺席」）。
   */
  const extC2Rows = (): { rows: WRow[]; exemptRows: WRow[] } | null => {
    if (!L2_CONTAINER) return null;
    const rel = listExternalViewSources(root).find(r => basename(r, '.mmd') === L2_CONTAINER);
    if (!rel) return null;
    const parts = toRootRel(rel).split('/');
    const dir = parts[parts.length - 2];
    const docRel = `${ARCH}/${dir}/${dir}.md`;
    if (!existsSync(join(root, docRel))) return null;
    const { stem } = extFigureOf(readFileSync(absOf(rel), 'utf8'), rel);
    const hits = extSections(readFileSync(join(root, docRel), 'utf8')).filter(s => wNorm(s.title).includes(wNorm(stem)));
    if (hits.length !== 1) return null;
    const p = wParseRows(hits[0].region);
    return { rows: p.rows, exemptRows: p.exemptRows };
  };
  let oC2Cache: Set<number> | null | undefined;
  const oC2Nums = (): Set<number> | null => {
    if (oC2Cache !== undefined) return oC2Cache;
    // 与 (x) 段同一解析函数（单一源），此处只取行号；设计文档无内嵌容器图源即回退外系统视图（T83）
    const v = L2_CONTAINER ? (xView(L2_CONTAINER) ?? extC2Rows()) : null;
    oC2Cache = v ? new Set([...v.rows, ...v.exemptRows].map(r => Number(r.num))) : null;
    return oC2Cache;
  };
  const oL3Cache = new Map<string, Set<number> | null>();
  const oCompare = (pair: string, src: string, docRel: string, docText: string, ptrList: XContainer[]): { issues: string[]; count: number; anchored: number; rows: number; redE: number; redB: number } => {
    const issues: string[] = [];
    const oL3Nums = (short: string): Set<number> | null => {
      if (oL3Cache.has(short)) return oL3Cache.get(short)!;
      const c = ptrList.find(x => x.from === 'container' && basename(x.docRel, '.md') === short);
      let nums: Set<number> | null = null;
      const a = c ? absOf(c.docRel) : '';
      if (a && existsSync(a)) {
        const p = wParseRows(readFileSync(a, 'utf8')); // 边表解析复用，不复写
        nums = new Set([...p.rows, ...p.exemptRows].map(r => Number(r.num)));
      }
      oL3Cache.set(short, nums);
      return nums;
    };
    const tbl = oFindTable(docText, ['边', '锚', '法典行']);
    if (!tbl) {
      issues.push(`${pair}：${docRel} 内找不到叠画边表（表头须含「边」「锚」「法典行」三列）——叠画图型的图源与叠画边表须俱在`);
      return { issues, count: 0, anchored: 0, rows: 0, redE: 0, redB: 0 };
    }
    // 边集等价：组件图判定器原样复用（零新逻辑），只把区间喂给它
    const r = wCompare(pair, src, docRel, tbl.region);
    issues.push(...r.issues);
    const law = oFindTable(docText, ['转移', '图标签']);
    const lawNums = law ? new Set(law.rows.map(x => Number(x.num))) : null;
    const iA = tbl.header.indexOf('锚');
    const iL = tbl.header.indexOf('法典行');
    const lawCheck = (nums: number[], col: string, num: string): void => {
      if (!lawNums) {
        issues.push(`${pair}：${docRel} 内找不到法典表（表头须含「转移」与「图标签」两列）——${col}的法典行引用无从解析`);
        return;
      }
      nums.filter(n => !lawNums.has(n))
        .forEach(n => issues.push(`${pair}：叠画边表第 ${num} 行${col}「法典行 ${n}」不存在于本文档法典表——引用悬空（底图纪律：叠画不得发明结构）`));
    };
    // 单个锚按三型判（C2 边 N ／ <容器> 边 N ／ 法典行 N）；复合锚（T83）＝全角「＋」连写的多段，每段各按三型判、任一段坏即红并点名该段
    const judgeAnchor = (a: string, rowNum: string, whole: string): void => {
      const where = whole === a ? `锚「${a}」` : `锚「${whole}」的段「${a}」`;
      let m: RegExpMatchArray | null;
      if ((m = a.match(O_A_C2))) {
        const c2 = oC2Nums();
        if (!c2) issues.push(`${pair}：叠画边表第 ${rowNum} 行${where}不可解析——容器层边表缺席（锚出处失去基线：设计文档无内嵌容器图源，层二图名所指外系统视图亦无唯一归属边表节）`);
        else oNums(m[1]).filter(n => !c2.has(n))
          .forEach(n => issues.push(`${pair}：叠画边表第 ${rowNum} 行锚「C2 边 ${n}」不存在于容器层边表——引用悬空（底图纪律）`));
      } else if ((m = a.match(O_A_LAW))) {
        lawCheck(oNums(m[1]), '锚列', rowNum);
      } else if ((m = a.match(O_A_L3))) {
        const nums = oL3Nums(m[1]);
        if (!nums) issues.push(`${pair}：叠画边表第 ${rowNum} 行${where}不可解析——「${m[1]}」未在容器指针表登记或其详设文档不在位`);
        else oNums(m[2]).filter(n => !nums.has(n))
          .forEach(n => issues.push(`${pair}：叠画边表第 ${rowNum} 行锚「${m![1]} 边 ${n}」不存在于该容器边表——引用悬空（底图纪律）`));
      } else {
        issues.push(`${pair}：叠画边表第 ${rowNum} 行锚列无法机械判定：${a || '（空）'}${whole === a ? '' : `（复合锚「${whole}」之一段）`}（受支持三型：C2 边 N ／ <容器> 边 N ／ 法典行 N，多段以全角「＋」连写——闸不猜）`);
      }
    };
    let anchored = 0;
    for (const row of tbl.rows) {
      const before = issues.length;
      const a = row.cells[iA] ?? '';
      const l = row.cells[iL] ?? '';
      const parts = a.includes('＋') ? a.split('＋').map(s => s.trim()) : [a];
      for (const part of parts) judgeAnchor(part, row.num, a);
      if (l === O_NONTRANS) { /* 记号闭集成员：结构服务流不落法典行——等值判，混杂值落入下方响亮红 */ }
      else if (l === O_ALLROWS) {
        if (!lawNums?.size) issues.push(`${pair}：叠画边表第 ${row.num} 行法典行列记「${O_ALLROWS}」而本文档法典表缺席或零行——引用悬空`);
      } else if (O_ROWNUMS.test(l)) lawCheck(oNums(l), '法典行列', row.num);
      else {
        issues.push(`${pair}：叠画边表第 ${row.num} 行法典行列无法机械判定：${l || '（空）'}（受支持：行号序列 ／ 记号 ${O_NONTRANS} ／ ${O_ALLROWS}——记号闭集扩集须裁决）`);
      }
      if (issues.length === before) anchored++;
    }
    // 染色一致：图源侧红集＝染红线型序号的边 ＋ 染红本体；文档侧红集＝红集表（表头含「件」「类」，类闭集＝边／本体）。
    // 两侧多重集相等才绿：红只在一侧、序号越界（位置编码漂移的典型形态）、类值不可判皆红。
    // 反事实理由的真假机器不判（判断题归评审）——本判据只守成员资格不漂移；无红无表＝合法。
    const gr = wParseGraph(src);
    const redIdx: number[] = [];
    const exclIds: string[] = [];
    for (const raw of src.split('\n')) {
      const line = raw.trim();
      let m2: RegExpMatchArray | null;
      if ((m2 = line.match(/^linkStyle\s+(\d+)\s+(.+)$/)) && /#ff0000/i.test(m2[2])) redIdx.push(Number(m2[1]));
      else if ((m2 = line.match(/^class\s+(\S+)\s+excl\s*$/))) m2[1].split(',').map(s => s.trim()).filter(Boolean).forEach(id => exclIds.push(id));
    }
    const mmdRedKeys: string[] = [];
    for (const i of redIdx) {
      const e = gr.edges[i];
      if (!e) issues.push(`${pair}：图源线型 ${i} 染红但边序号越界（图仅 ${gr.edges.length} 条边）——位置编码漂移即红`);
      else mmdRedKeys.push(wKey(e));
    }
    const mmdRedBodies: string[] = [];
    for (const id of exclIds) {
      const nd = gr.nodes.get(id);
      if (!nd) issues.push(`${pair}：图源染红本体 ${id} 无节点定义`);
      else mmdRedBodies.push(nd.short);
    }
    const redTbl = oFindTable(docText, ['件', '类']);
    let redE = 0; let redB = 0;
    if (!redTbl && (mmdRedKeys.length || mmdRedBodies.length)) {
      issues.push(`${pair}：图源有染红件而 ${docRel} 内找不到红集表（表头须含「件」「类」两列）——红集登记义务`);
    } else if (redTbl) {
      const docRedKeys: string[] = [];
      const docRedBodies: string[] = [];
      for (const row of redTbl.rows) {
        const item = row.cells[1] ?? '';
        const cls = row.cells[2] ?? '';
        if (cls === '边') {
          const p = wParseRows(`| ${row.num} | ${item} | 占位 |`);
          if (!p.rows.length) { issues.push(`${pair}：红集表第 ${row.num} 行「件」列无法按边语法解析：${item}（体例同叠画边表「边」列）`); continue; }
          const e = p.rows[0];
          const rf = wResolve(e.from, gr.displays);
          const rt = wResolve(e.to, gr.displays);
          if (rf.err || rt.err) { issues.push(`${pair}：红集表第 ${row.num} 行——${rf.err ?? rt.err}`); continue; }
          docRedKeys.push(`${rf.name} ${W_KIND_MARK[e.kind]} ${rt.name}：${e.label}`);
        } else if (cls === '本体') {
          docRedBodies.push(wDisplay(item));
        } else {
          issues.push(`${pair}：红集表第 ${row.num} 行「类」列无法机械判定：${cls || '（空）'}（闭集：边／本体——扩集须裁决）`);
        }
      }
      const oDiff = (a: string[], b: string[]): string[] => {
        const rest = [...b];
        return a.filter(x => { const i = rest.indexOf(x); if (i >= 0) { rest.splice(i, 1); return false; } return true; });
      };
      oDiff(mmdRedKeys, docRedKeys).forEach(k => issues.push(`${pair}：图源染红边「${k}」未登记于红集表——红有图无即漂移`));
      oDiff(docRedKeys, mmdRedKeys).forEach(k => issues.push(`${pair}：红集表登记边「${k}」图源未染红——红有文无即漂移`));
      oDiff(mmdRedBodies, docRedBodies).forEach(k => issues.push(`${pair}：图源染红本体「${k}」未登记于红集表——红有图无即漂移`));
      oDiff(docRedBodies, mmdRedBodies).forEach(k => issues.push(`${pair}：红集表登记本体「${k}」图源未染红——红有文无即漂移`));
      redE = docRedKeys.length; redB = docRedBodies.length;
    }
    return { issues, count: r.count, anchored, rows: tbl.rows.length, redE, redB };
  };

  // ---------- 覆盖对象与图种的正向声明（免检身份一律由声明取得，不由文件缺席推导） ----------
  const CONTAINER_ANCHOR = typeof SETTINGS.container_table_anchor === 'string' && SETTINGS.container_table_anchor
    ? SETTINGS.container_table_anchor : 'C3 组件详图（L3）';
  const MECHANISM_ANCHOR = typeof SETTINGS.mechanism_table_anchor === 'string' && SETTINGS.mechanism_table_anchor
    ? SETTINGS.mechanism_table_anchor : '**机制视图**';
  const X_MD_RE = new RegExp(`${esc(ARCH_BASE)}\\/[A-Za-z0-9_-]+\\/[A-Za-z0-9_-]+\\.md`);
  const X_MMD_RE = new RegExp(`${esc(ARCH_BASE)}\\/[A-Za-z0-9_-]+\\/[A-Za-z0-9_-]+\\.mmd`);
  // 表区扫描：自锚点起吃紧随其后的那张表（表开始后首个非表行即止）；锚点不在文内返 null
  // （与「表在但零行」区分——前者是基线失踪，后者是空表）。
  const xTableRows = (text: string, anchor: string): string[][] | null => {
    const at = text.indexOf(anchor);
    if (at < 0) return null;
    const rows: string[][] = [];
    let started = false;
    for (const raw of text.slice(at).split('\n')) {
      const line = raw.trim();
      if (!line.startsWith('|')) { if (started) break; else continue; }
      if (!line.endsWith('|')) continue;
      started = true;
      rows.push(line.slice(1, -1).split('|').map(c => c.trim()));
    }
    return rows;
  };
  const xPointerTable = (text: string): { list: XContainer[]; issues: string[] } => {
    const list: XContainer[] = [];
    const issues: string[] = [];
    const cRows = xTableRows(text, CONTAINER_ANCHOR);
    if (!cRows) issues.push(`设计文档内找不到容器指针表（锚「${CONTAINER_ANCHOR}」）——跨层判据的覆盖对象失去正向声明基线`);
    for (const cells of cRows ?? []) {
      if (cells.length < 3 || /^-+$/.test(cells[0]) || cells[0] === '容器') continue;
      const docM = cells[1].match(X_MD_RE);
      if (!docM) { issues.push(`指针表行「${cells[0]}」详设文档列无法机械判定：${cells[1]}`); continue; }
      const srcM = cells[2].match(X_MMD_RE);
      const schemaOnly = !srcM && cells[2].includes('schema 型详设');
      // 部署型（记号闭集一员）：物理落位视图、非容器分解——列图源路径计入覆盖声明，跨层判免（叠画之外的第二种免检身份，皆由声明取得）
      const deploy = !!srcM && cells[2].includes('部署型');
      if (!srcM && !schemaOnly) {
        issues.push(`指针表行「${cells[0]}」图源列无法机械判定：${cells[2]}（列图源路径＝组件图型；免检须写「schema 型详设，无图源」；部署视图列图源路径并带「部署型」记号）`);
        continue;
      }
      const kind: XContainer['kind'] = schemaOnly ? 'schema' : deploy ? 'deploy' : 'component';
      list.push({ name: cells[0], short: wDisplay(cells[0]), docRel: docM[0], srcRel: srcM ? srcM[0] : null, kind, from: 'container' });
    }
    // 机制视图小表：表缺席不红——机制轴按需设立，首个机制入区前本无此表；
    // 表在则逐行正向声明可执行（列了什么就得在位，堵「删文件即静默降格免检」的逃逸）。
    for (const cells of xTableRows(text, MECHANISM_ANCHOR) ?? []) {
      if (cells.length < 4 || /^-+$/.test(cells[0]) || cells[0] === '机制') continue;
      const docM = cells[1].match(X_MD_RE);
      if (!docM) { issues.push(`机制视图表行「${cells[0]}」详设文档列无法机械判定：${cells[1]}`); continue; }
      const srcM = cells[2].match(X_MMD_RE);
      if (!srcM) { issues.push(`机制视图表行「${cells[0]}」图源列无法机械判定：${cells[2]}（机制视图须列本机制的图源件）`); continue; }
      if (!cells[3].includes('叠画图型')) {
        issues.push(`机制视图表行「${cells[0]}」图型列无法机械判定：${cells[3]}（图型闭集现为「叠画图型」，扩型须裁决）`);
        continue;
      }
      // 联合反查列（联合设计反查的登记义务）：值须为治理账上的裁决地址，或合法初值记号（收官前须实查换号）。
      // 陈旧与否是治理判断，机器只守指涉完整性——覆盖边界如实：地址的**存在性**跨区，归治理账面不在本包。
      const jr = (cells[5] ?? '').trim();
      if (!(jr === PENDING_MARK || /^[A-Za-z][A-Za-z0-9]*-D[1-9][0-9]*$/.test(jr))) {
        issues.push(`机制视图表行「${cells[0]}」联合反查列无法机械判定：${jr || '（缺列）'}（须为裁决地址形「<任务身份>-D<序号>」或初值记号「${PENDING_MARK}」——缺列即未登记）`);
      }
      list.push({ name: cells[0], short: wDisplay(cells[0]), docRel: docM[0], srcRel: srcM[0], kind: 'overlay', from: 'mechanism' });
    }
    return { list, issues };
  };
  const xPtr = xPointerTable(dText); // 一次解析两判据共用（问题由 (x) 段单点上报，不双报）

  // ---------- (w) 架构图文对齐 ----------
  const wIssues: string[] = [];
  {
    const wDone: string[] = [];
    const wOverlay: string[] = [];
    // 逐份图源件与同目录同名详设文档成对（区契约）——无配对即红；
    // 图种按正向声明分流：叠画图型走叠画判定器，其余走组件图型边表判定器。
    for (const rel of listL3Sources(root)) {
      const mdRel = rel.replace(/\.mmd$/, '.md');
      const pair = basename(rel, '.mmd');
      const docRel = toRootRel(mdRel);
      if (!existsSync(join(root, docRel))) {
        wIssues.push(`${pair}：图源无配对详设文档——${docRel} 不在位（区契约：图源与详设文档成对，边表正本住文档）`);
        continue;
      }
      const src = readFileSync(absOf(rel), 'utf8');
      const docText = readFileSync(join(root, docRel), 'utf8');
      if (xPtr.list.find(c => c.srcRel && toRootRel(c.srcRel) === toRootRel(rel))?.kind === 'overlay') {
        const r = oCompare(pair, src, docRel, docText, xPtr.list);
        wIssues.push(...r.issues);
        if (!r.issues.length) wOverlay.push(`${pair} 叠画图 ${r.count} 边逐边机械等价·锚 ${r.anchored}/${r.rows} 全解析${r.redE + r.redB ? `·红集 ${r.redE} 边 ${r.redB} 本体染色一致` : ''} ✓`);
        continue;
      }
      const r = wCompare(pair, src, docRel, docText);
      wIssues.push(...r.issues);
      wDone.push(`${pair} ${r.count} 边${r.exempt ? `（另 ${r.exempt} 行豁免）` : ''}`);
    }
    // 机制视图表的正向声明可执行：表行列了图源与详设文档，两件就必须在位（删图删文不得静默降格免检）
    for (const c of xPtr.list) {
      if (c.from !== 'mechanism') continue;
      if (c.srcRel && !existsSync(absOf(c.srcRel))) {
        wIssues.push(`机制视图「${c.name}」：机制视图表声明的图源 ${toRootRel(c.srcRel)} 不在位——正向声明可执行`);
      }
      if (!existsSync(absOf(c.docRel))) {
        wIssues.push(`机制视图「${c.name}」：机制视图表声明的详设文档 ${toRootRel(c.docRel)} 不在位——正向声明可执行`);
      }
    }
    // 层二各图与设计文档内其后的编号边表比对
    if (!DESIGN) {
      out.w.push(info('架构图文对齐：本包登记表未声明 settings.design_doc——层二段与声明表段如实跳过，只判图源与详设成对'));
    } else if (!dText) {
      wIssues.push(`设计文档不在位：${DESIGN}（本包登记表 settings.design_doc 登记了它——登记即在位）`);
    } else if (spans.length === 0) {
      out.w.push(info(`架构图文对齐：${DESIGN} 内无图源围栏块，层二段跳过（图源尚未落地）`));
    } else if (!L2_NAMES.length) {
      out.w.push(info('架构图文对齐：本包登记表未声明 settings.l2_diagrams——层二段如实跳过（图名清单是对照基线）'));
    } else {
      for (const name of L2_NAMES) {
        const v = l2Region(name);
        if (!v) { wIssues.push(`层二：${DESIGN} 内找不到自报名为「${name}」的图源——层二边表失去对照基线（整图消失不该静默）`); continue; }
        const r = wCompare(name, v.src, DESIGN, v.region);
        wIssues.push(...r.issues);
        wDone.push(`${name} ${r.count} 边${r.exempt ? `（另 ${r.exempt} 行豁免）` : ''}`);
      }
    }
    // 外系统视图：一目录多图源，故每图须在详设内有归属边表节（标题含「边表」且含图名余名）；
    // 零命中＝图无表即红、多命中＝归属歧义即红（闸不猜）、边表节无图认领＝表无图即红。
    const wExt: string[] = [];
    {
      const extByDir = new Map<string, string[]>();
      for (const rel of listExternalViewSources(root)) {
        const parts = toRootRel(rel).split('/');
        const dir = parts[parts.length - 2];
        if (!extByDir.has(dir)) extByDir.set(dir, []);
        extByDir.get(dir)!.push(rel);
      }
      for (const [dir, srcs] of extByDir) {
        const docRel = `${ARCH}/${dir}/${dir}.md`;
        if (!existsSync(join(root, docRel))) {
          wIssues.push(`外系统视图「${dir}」：图源在位而详设 ${docRel} 不在位（区契约：详设与图源成对）`);
          continue;
        }
        const docText = readFileSync(join(root, docRel), 'utf8');
        const secs = extSections(docText); // 归属边表节规则的唯一实现（叠画锚的容器层边表回退同读它，T83）
        const claimed = new Set<number>();
        const done: string[] = [];
        for (const rel of srcs) {
          const src = readFileSync(absOf(rel), 'utf8');
          const { figure, stem } = extFigureOf(src, rel);
          const hits = secs.map((s, idx) => ({ s, idx })).filter(x => wNorm(x.s.title).includes(wNorm(stem)));
          if (!hits.length) {
            wIssues.push(`外系统视图「${dir}」：图「${figure}」在 ${docRel} 内无归属边表节（标题须含「边表」且含图名余名「${stem}」——图无表即红）`);
            continue;
          }
          if (hits.length > 1) {
            wIssues.push(`外系统视图「${dir}」：图「${figure}」的边表节归属歧义——「${hits.map(h => h.s.title).join('」「')}」皆命中（闸不猜）`);
            continue;
          }
          claimed.add(hits[0].idx);
          const r = wCompare(`外系统视图 ${figure}`, src, docRel, hits[0].s.region);
          wIssues.push(...r.issues);
          done.push(`${figure} ${r.count} 边${r.exempt ? `（另 ${r.exempt} 行豁免）` : ''}`);
        }
        secs.forEach((s, idx) => {
          if (!claimed.has(idx)) wIssues.push(`外系统视图「${dir}」：边表节「${s.title}」无图源认领（表无图——删图残表或图名漂移即红）`);
        });
        if (done.length) wExt.push(`${dir}：${done.join('、')}`);
      }
    }
    if (wIssues.length) wIssues.forEach(m => out.w.push(red(`架构图文对齐：${m}`)));
    else {
      out.w.push(info(`架构图文对齐：${wDone.join('、') || '（无成对图文）'} 逐边机械等价（端点＋标签＋线型全合）✓`
        + '——覆盖边界：闸判编号边表；散文注记（组件注记、语义段、视图注记）的语义漂移归评审看守'));
      if (wOverlay.length) {
        out.w.push(info(`叠画图型：${wOverlay.join('、')}——判据＝边集经组件图判定器逐边机械等价＋锚可解析＋染色一致（反事实理由归评审）`));
      }
      if (wExt.length) {
        out.w.push(info(`外系统视图：${wExt.join('；')} 逐边机械等价 ✓——发现共用渲染器收集器（单一源纪律）；图无表、表无图、归属歧义、详设缺席皆红`));
      }
    }
  }

  // ---------- (x) 架构跨层对齐 ----------
  {
    const xIssues: string[] = [];
    const xExempt: string[] = []; // 豁免与候定清单（文件·边号·类型）——绿灯逐项列出，逃逸永远可见
    const xDone: string[] = [];
    type XCls = { short: string; full: string };
    // 类别相符：短名相等 ／ 一方短名含于另一方全显示名 ／ 别名表
    const xClsMatch = (a: XCls, b: XCls): boolean =>
      a.short === b.short
      || (!!a.short && b.full.includes(a.short)) || (!!b.short && a.full.includes(b.short))
      || X_CROSS_ALIAS.some(([p, q]) => (a.short === p && b.short === q) || (a.short === q && b.short === p));
    // 端点类别：属外部子图者折叠为子图标签，否则取节点自身。
    // 「外部」的机械判据＝该节点非本系统一族（族含成员皆本族的分组框）：本系统边界框里装的是自己的容器，折叠它们会把内部件误报成整体。
    const xClsOf = (g: WGraph, display: string, ownSub: string | null): XCls => {
      const nd = g.byName.get(display);
      if (!nd) return { short: display, full: display };
      if (nd.sub && nd.sub !== ownSub && !g.family.has(nd.id)) {
        const sg = g.subs.get(nd.sub);
        if (sg) return { short: sg.short, full: sg.full };
      }
      return { short: nd.short, full: nd.full };
    };
    // 锚点提取：只认编号边表行内；候定记录先剔除——它不是正式锚
    const xL2Anchors = (line: string): number[] =>
      [...line.replace(X_PENDING_ALL, ' ').matchAll(/L2\s*边\s*(\d+)/g)].map(m => Number(m[1]));
    const xC1Anchors = (line: string): number[] =>
      [...line.replace(X_PENDING_ALL, ' ').matchAll(/C1\s*边\s*(\d+)/g)].map(m => Number(m[1]));
    // 候定记录：其文本内含层二边号者计为该边的回指（留白显式登记、不偷跑设计）
    const xPendingAnchors = (text: string): number[] =>
      [...text.matchAll(X_PENDING_ALL)].flatMap(m => [...m[0].matchAll(/L2\s*边\s*(\d+)/g)].map(x => Number(x[1])));

    if (!DESIGN || !dText) {
      out.x.push(info('架构跨层对齐：本包登记表未声明 settings.design_doc（或该件不在位）——跨层链失去声明基线，如实跳过'));
    } else if (spans.length === 0) {
      out.x.push(info(`架构跨层对齐：${DESIGN} 内无层二图源，跳过（图源尚未落地）`));
    } else if (!L2_CONTEXT || !L2_CONTAINER) {
      out.x.push(info('架构跨层对齐：settings.l2_diagrams 未声明系统语境图与容器图两张——跨层链失去基线，如实跳过'));
    } else {
      const c1 = xView(L2_CONTEXT);
      const c2 = xView(L2_CONTAINER);
      if (!c1 || !c2) {
        xIssues.push('跨层链失去基线：系统语境图或容器图图源缺席（缺席详情见图文对齐判据）——两段皆不可判');
      } else {
        // 本系统一族＝class … shell 声明 ∪ 成员皆本族的分组框（分组框作端点时算本系统件，不折叠为系统框）
        const shellShorts = new Set([...c2.g.family].map(id => c2.g.nodes.get(id)?.short).filter(Boolean) as string[]);
        if (!shellShorts.size) {
          xIssues.push('层二→层一：容器图图源无本系统一族声明（class … shell）——本系统容器集无法机械判定（闸不猜；口径变更须裁决）');
        }
        // 层二→层一：外沿边携层一锚、对端相符；层一每边被回指；两端皆本系统一族者机械免锚
        c2.exemptRows.forEach(r => xExempt.push(`容器图边 ${r.num}：${X_NOTIN}`));
        const c1Nums = c1.rows.map(r => Number(r.num));
        const c1Ref = new Set<number>();
        let c2Outer = 0;
        for (const r of c2.rows) {
          const anchors = xC1Anchors(r.line);
          anchors.forEach(n => c1Ref.add(n));
          if (!shellShorts.size) continue; // 容器集不可判时不叠报（上面已红）
          if (shellShorts.has(r.from) && shellShorts.has(r.to)) continue; // 内部边：机械免锚
          const ext = shellShorts.has(r.from) ? r.to : r.from;
          if (r.marks.includes(X_SUB_C1)) { xExempt.push(`容器图边 ${r.num}：${X_SUB_C1}`); continue; }
          c2Outer++;
          if (!anchors.length) {
            xIssues.push(`x3 层二→层一：容器图边 ${r.num}（外沿边，外部对端「${ext}」）缺层一锚——外沿边须携「C1 边 N」或精确记号${X_SUB_C1}`);
            continue;
          }
          const extCls = xClsOf(c2.g, ext, null);
          for (const n of anchors) {
            const row = c1.rows.find(x => Number(x.num) === n);
            if (!row) { xIssues.push(`x1 层二→层一：容器图边 ${r.num} 的锚点「C1 边 ${n}」不存在于系统语境图边表——锚点不可解析`); continue; }
            const ends: XCls[] = [xClsOf(c1.g, row.from, null), xClsOf(c1.g, row.to, null)];
            if (!ends.some(e => xClsMatch(e, extCls))) {
              xIssues.push(`x1 层二→层一：容器图边 ${r.num} 锚「C1 边 ${n}」对端错配——层一边两端「${row.from}／${row.to}」均不与外部对端「${ext}」类别相符`);
            }
          }
        }
        for (const n of [...new Set(c1Nums)].sort((a, b) => a - b)) {
          if (!c1Ref.has(n)) xIssues.push(`x2 层二→层一：系统语境图边 ${n} 无任何容器图锚回指——层一边须在外沿边表落锚（反向全覆盖）`);
        }
        xDone.push(`层二→层一 外沿 ${c2Outer} 边锚齐、语境 ${new Set(c1Nums).size} 边全被回指`);

        // 层三→层二：逐组件图型容器过三判据
        const ptr = xPtr; // 指针表解析在图文对齐段一次完成，两判据共用（单一源纪律）
        // 反向覆盖：正向声明须盖住磁盘全集——删声明行或新容器漏登记不得静默缩小覆盖面
        {
          const declared = new Set(ptr.list.map(c => c.srcRel && toRootRel(c.srcRel)).filter(Boolean));
          for (const rel of listL3Sources(root)) {
            if (!declared.has(toRootRel(rel))) xIssues.push(`覆盖声明：磁盘图源 ${toRootRel(rel)} 未在容器指针表登记——覆盖面不得由声明缺席缩小`);
          }
        }
        ptr.issues.forEach(x => xIssues.push(`覆盖声明：${x}`));
        for (const c of ptr.list) {
          if (c.kind === 'schema') { xExempt.push(`指针表「${c.name}」：schema 型详设（无图源）免判`); continue; }
          if (c.kind === 'deploy') { xExempt.push(`指针表「${c.name}」：部署型详设（物理落位视图，非容器分解）免跨层判`); continue; }
          // 叠画图型：底图即容器与组件，跨层落点不在边界边上而在边表锚列里——故免本判据，
          // 图文对齐与锚可解析统归叠画判定器（免检身份取自正向声明，不由文件缺席推导）
          if (c.kind === 'overlay') {
            xExempt.push(`${c.from === 'mechanism' ? '机制视图表' : '指针表'}「${c.name}」：叠画图型免跨层判——图文对齐与锚可解析归叠画判定器`);
            continue;
          }
          const srcAbs = absOf(c.srcRel!);
          const docAbs = absOf(c.docRel);
          const docName = basename(c.docRel);
          if (!existsSync(srcAbs)) {
            xIssues.push(`覆盖声明：指针表声明「${c.name}」为组件图型，但图源 ${toRootRel(c.srcRel!)} 不在位——图源与配对边表须俱在（删图不得降格免检）`);
            continue;
          }
          if (!existsSync(docAbs)) {
            xIssues.push(`覆盖声明：指针表声明的详设文档 ${toRootRel(c.docRel)} 不在位——图源与配对边表须俱在`);
            continue;
          }
          const g = wParseGraph(readFileSync(srcAbs, 'utf8'));
          const docText = readFileSync(docAbs, 'utf8');
          const p = wParseRows(docText);
          if (!p.rows.length && !p.exemptRows.length) {
            xIssues.push(`覆盖声明：${docName} 无编号边表——组件图型的图源与边表须俱在`);
            continue;
          }
          const own = [...g.subs.values()].find(s => s.short === c.short);
          if (!own) {
            xIssues.push(`${docName}：图源内找不到本容器子图——子图标签短名须与指针表容器名「${c.short}」相合（闸不猜）`);
            continue;
          }
          // 容器成员判定沿子图链上溯：嵌在本容器里几层分组框都算本容器成员（分组框是布局约定，不是容器边界）
          const inside = (id?: string): boolean => {
            for (let cur: string | undefined = id; cur; cur = g.nodes.get(cur)?.sub ?? undefined) if (cur === own.id) return true;
            return false;
          };
          const pending = xPendingAnchors(docText);
          pending.forEach(n => xExempt.push(`${docName}（跨层候定）：L2 边 ${n} ${X_PENDING}`));
          const anchored = new Set<number>(pending);
          // 锚点校验：存在于容器图边表 → 一端为本容器 → 外部对端类别相符（内部边无对端可比）
          const xAnchor = (n: number, rowNum: string | undefined, extCls: XCls | null): void => {
            const row = c2.rows.find(x => Number(x.num) === n);
            if (!row) {
              const ex = c2.exemptRows.find(x => Number(x.num) === n);
              xIssues.push(`x1 ${docName} 边 ${rowNum}：锚点「L2 边 ${n}」${ex ? `指向携${X_NOTIN}的容器图豁免行——豁免边不作落点` : '不存在于容器图边表'}——锚点不可解析`);
              return;
            }
            const ends = [row.from, row.to];
            if (!ends.includes(c.short)) {
              xIssues.push(`x1 ${docName} 边 ${rowNum}：锚点「L2 边 ${n}」（${row.from}／${row.to}）不触及本容器「${c.short}」——错容器锚`);
              return;
            }
            if (!extCls || (ends[0] === c.short && ends[1] === c.short)) return;
            const other = ends[0] === c.short ? ends[1] : ends[0];
            const otherCls = xClsOf(c2.g, other, null);
            if (!xClsMatch(otherCls, extCls)) {
              xIssues.push(`x1 ${docName} 边 ${rowNum}：锚「L2 边 ${n}」对端错配——层二边的外部对端「${otherCls.short}」与本行外部端点类别「${extCls.short}」不符`);
            }
          };
          // 图源边池（多重边逐条消耗）：行与图源边的等价由图文对齐判据保证，此处只借其分辨内外与端点归属
          const pool = g.edges.map(e => ({ e, used: false }));
          let boundary = 0;
          for (const r of p.rows) {
            const f = wResolve(r.from, g.displays), t = wResolve(r.to, g.displays);
            if (f.err || t.err) continue; // 图文对齐判据已报
            const key = wKey({ ...r, from: f.name!, to: t.name! });
            const slot = pool.find(x => !x.used && wKey(x.e) === key);
            if (!slot) continue; // 与图源不等价：图文对齐判据已报，本判据不叠报
            slot.used = true;
            const anchors = xL2Anchors(r.line);
            anchors.forEach(n => anchored.add(n));
            const extId = inside(slot.e.fromId)
              ? (inside(slot.e.toId) ? undefined : slot.e.toId)
              : slot.e.fromId;
            if (extId === undefined) { // 内部边：带锚不禁止，只做弱校验（存在＋触及本容器）
              anchors.forEach(n => xAnchor(n, r.num, null));
              continue;
            }
            boundary++;
            const extCls = xClsOf(g, g.nodes.get(extId)!.short, own.id);
            if (!anchors.length) {
              if (r.marks.includes(X_SUB_L2)) { xExempt.push(`${docName} 边 ${r.num}：${X_SUB_L2}`); continue; }
              if (r.marks.includes(X_PENDING)) continue; // 行内候定记录（已入清单）
              xIssues.push(`x3 ${docName} 边 ${r.num}「${key}」为边界边却未携锚——须含「L2 边 N」或精确记号${X_SUB_L2}或候定记录（否定散文不作豁免）`);
              continue;
            }
            anchors.forEach(n => xAnchor(n, r.num, extCls));
          }
          // 反向全覆盖：容器图凡一端为本容器的边（不入图豁免行不在此列）须至少一处回指
          let rev = 0;
          for (const r of c2.rows) {
            if (r.from !== c.short && r.to !== c.short) continue;
            rev++;
            if (!anchored.has(Number(r.num))) {
              xIssues.push(`x2 ${docName}：容器图边 ${r.num}「${r.from}／${r.to}：${r.label}」一端为本容器却无回指——层二变更须回补层三边表行内锚或候定记录`);
            }
          }
          xDone.push(`${basename(c.docRel, '.md')} 边界 ${boundary} 边锚齐／反向 ${rev} 边全覆盖`);
        }
      }
      if (xIssues.length) xIssues.forEach(m => out.x.push(red(`架构跨层对齐：${m}`)));
      else {
        out.x.push(info(`架构跨层对齐：${xDone.join('、') || '（无跨层对象）'} ✓——豁免与候定 ${xExempt.length} 项：`
          + (xExempt.length ? xExempt.join('；') : '无')
          + '（机器不判理由真假，逃逸永远可见；记号闭集扩集须裁决）'));
      }
    }
  }
  return out;
}

type XContainer = {
  name: string; short: string; docRel: string; srcRel: string | null;
  kind: 'component' | 'overlay' | 'schema' | 'deploy'; from: 'container' | 'mechanism';
};

function computed(ctx: CheckContext): Computed {
  const key = ctx.root;
  if (!CACHE.has(key)) CACHE.set(key, computeAll(ctx));
  return CACHE.get(key)!;
}

// criterion＝机读自述（T59 批四补）：`--gate-report` 逐条输出它。此前本包三项都没有这个字段，
// 报告里只印一句占位话「自述见该包区契约」，于是「这条判据到底判什么」在机读面上查不到，
// 而通用判据族 19 项全写了——自述面缺一块，比没夹具更难发现。
export const checks = [
  {
    id: '(e)', name: '图源与渲染产物一致',
    criterion: '图纸区逐张：图源（.mmd）与渲染产物（.svg）须同源同鲜——产物在位、产物内嵌的有效源哈希等于图源现算值'
      + '（有效源＝默认头＋图源正文，故默认头一变即须重渲）；另判可移植投影在位且新鲜、图纸区零孤儿（产物皆在本包登记表登记）。'
      + '受检面＝本包登记表 settings.arch_zone 所指图纸区；该区不在位即如实跳过',
    run: (ctx: CheckContext): Finding[] => computed(ctx).e,
  },
  {
    id: '(w)', name: '架构图文对齐',
    criterion: '每张图源与其承载文档的编号边表逐边机械等价：端点、标签、线型三项全合方算一边对上——'
      + '图里有而表里无、表里有而图里无、同一边线型不符，三者皆红。叠画图型另判锚可解析（锚三型：C2 边 N ／ <容器> 边 N ／ 法典行 N，'
      + '多段以全角「＋」连写各段皆判；容器层边表取设计文档内嵌容器图源的边表，缺则取层二图名所指外系统视图详设的唯一归属边表节，T83）'
      + '与染色一致。覆盖边界如实：本判据只判编号边表，散文注记（组件注记·语义段·视图注记）的语义漂移归评审看守',
    run: (ctx: CheckContext): Finding[] => computed(ctx).w,
  },
  {
    id: '(x)', name: '架构跨层对齐',
    criterion: '层间锚点可解析：层二的外沿边须在层一有回指锚、层一的语境边须被层二回指、层三的边界边须锚到层二；'
      + '容器指针表逐行须指得到实存详设与图源。豁免两类且逐条打印（机器不判豁免理由的真假，逃逸永远可见）：'
      + '边表行自带的方括号豁免记号、指针表行带「部署型」记号者（物理落位视图，非容器分解）',
    run: (ctx: CheckContext): Finding[] => computed(ctx).x,
  },
];
