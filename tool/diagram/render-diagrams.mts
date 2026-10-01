#!/usr/bin/env -S node --experimental-strip-types --disable-warning=ExperimentalWarning
// 独立运行版注记：本件自 envshell 仓 packs/diagram/render-diagrams.mts@4a439c5 承接，改动三处：公共库导入路径（../../tool/lib.mts → ./lib.mts）、帮助文字里的路径（packs/diagram → tool/diagram），
// 以及收集器的一条独立运行版规则——承载文档里只收自报 %% name: 的代码块（见 collectDiagrams 内注记）。
// 下文沿用上游用语：「本包」＝tool/diagram/，「本包登记表」＝tool/diagram/registry.json，「机检器」＝tool/diagram/check.mts，
// 「提交闸」＝tool/diagram/pre-commit.sh；「域包／元工具／三池」是 envshell 的装卸机制，独立运行版不设（见 tool/diagram/AGENTS.md）。
import { realpathSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
// 蓝本溯源：tool/render-diagrams.mts@c192490（首实例仓）；档位：第二档工具（可调用不可改，自定义唯配置旋钮）；
// 手术：图纸区路径与 L3 产物前缀由源码常量改为**包登记表 settings**（arch_zone／design_doc），
// 渲染依赖（mmdc）与渲染参数配置改从本包目录取（依赖随包走，不落工具池），剥治理记号与沿革注记。
// T21-D2（2026-09-06，出厂件固定性例外）：产物文件名前缀改读 settings.product_prefix——字符串即取之（空串＝无前缀），
//   缺键＝沿用承载文档名（层二取承载文档基名、层三取 settings.design_doc 基名）；层二与层三同规，导出器不动（可移植投影名自产线 SVG 名派生）。
//
// 图渲染器：把文档中的 mermaid 文本块与独立图源件渲染为 SVG。
// 文本源是唯一正本，SVG 是机器派生投影；manifest 记录源哈希供机检核对（图的语义保质期）。
// 依赖 mermaid-cli（mmdc）；未安装时明确报告，不静默跳过。
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { mkdirSync, writeFileSync, readFileSync, readdirSync, statSync, existsSync, rmSync } from 'node:fs';
import { join, dirname, basename } from 'node:path';
import { ROOT, DEFAULT_LAYOUT, listMdFiles, readDoc, docBase } from './lib.mts';

// 本包自己的家（绝对路径）：依赖、渲染参数、登记表都随包走——包挂到哪里，这几样跟到哪里
const PACK_DIR = fileURLToPath(new URL('.', import.meta.url)).replace(/\/$/, '');
const PACK_REGISTRY = join(PACK_DIR, 'registry.json');
// 包级默认层：图纸区默认落在常驻意志区之下的 architecture/ 子目录；实例改布局只改包登记表 settings，不改本件
const DEFAULT_ARCH_SUBDIR = 'architecture';

/**
 * 包设置：arch_zone＝图纸区（相对实例根，图源与产物之家）；design_doc＝承载文档路径（缺 product_prefix 时的 L3 前缀之源，null＝无前缀）；
 * product_prefix＝产物文件名前缀旋钮（字符串即取之，空串＝无前缀；缺键＝undefined，沿用承载文档名）。
 * 缺登记表或缺键即按包级默认取值并向 stderr 说一声——不静默用一个别人猜不到的路径。
 */
function loadSettings(): { arch_zone: string; design_doc: string | null; product_prefix: string | undefined } {
  const fallback = { arch_zone: `${DEFAULT_LAYOUT.truth_dir}/${DEFAULT_ARCH_SUBDIR}`, design_doc: null, product_prefix: undefined };
  let s: any = null;
  try { s = JSON.parse(readFileSync(PACK_REGISTRY, 'utf8'))?.settings ?? null; } catch { s = null; }
  if (!s || typeof s.arch_zone !== 'string' || !s.arch_zone.trim()) {
    console.error(`【制图包】登记表未给 settings.arch_zone（${PACK_REGISTRY}）——按包级默认取「${fallback.arch_zone}」`);
    return fallback;
  }
  return {
    arch_zone: s.arch_zone.trim().replace(/^\/+|\/+$/g, ''),
    design_doc: typeof s.design_doc === 'string' && s.design_doc.trim() ? s.design_doc.trim() : null,
    product_prefix: typeof s.product_prefix === 'string' ? s.product_prefix.trim() : undefined,
  };
}

export const SETTINGS = loadSettings();
/** 产物前缀旋钮：有 product_prefix 取之（空串＝无前缀），缺键则由各层按承载文档名派生（见 L3_SVG_PREFIX 与 collectDiagrams 层二分支） */
const PREFIX_OVERRIDE: string | undefined = SETTINGS.product_prefix;
/** 图纸区（相对实例根）：图源件与渲染产物之家 */
export const ARCH_ZONE = SETTINGS.arch_zone;
/** 承载文档面（相对实例根）：图纸区的上一级——L2 级图住在这一层的 .md 文档里的 ```mermaid 围栏块中 */
export const DOC_ZONE = dirname(ARCH_ZONE) === '.' ? '' : dirname(ARCH_ZONE);
/** 图纸区相对承载文档面的名字：listL3Sources／listExternalViewSources 返回的路径以此开头 */
export const ARCH_SUBDIR = basename(ARCH_ZONE);
// 层三投影文件名的稳定前缀：图源自承载文档迁出为独立 .mmd 后，**产物文件名不动**——
// 文件名是产物身份（两份清单的键、外部引用的落点），改名属另一件事、须裁决。
// 前缀之源＝settings.product_prefix（有则取之，空串＝无前缀）；缺键沿用 settings.design_doc 基名。
export const L3_SVG_PREFIX = PREFIX_OVERRIDE !== undefined
  ? PREFIX_OVERRIDE
  : (SETTINGS.design_doc ? basename(SETTINGS.design_doc).replace(/\.[^.]+$/, '') : '');

const OUT_DIR = join(ROOT, ARCH_ZONE);
const MANIFEST = join(OUT_DIR, 'manifest.json');
const MMDC = join(PACK_DIR, 'node_modules', '.bin', 'mmdc');
// 浏览器住址（本包渲染参数件的 executablePath）：填了才把参数件递给渲染引擎，空着即用引擎自带的浏览器
const PPTR_EXEC: string = (() => {
  try { const v = JSON.parse(readFileSync(join(PACK_DIR, 'puppeteer-config.json'), 'utf8')).executablePath; return typeof v === 'string' ? v.trim() : ''; }
  catch { return ''; }
})();

// 渲染配置默认头：渲染参数（布局、标签底框等）不是结构信息，正本住渲染器常量——
// 图源**无文件头即注入默认头**；图源**显式写头则显式优先**；
// 显式头必须闭合且以 config: 开头，残缺头不当显式头、响亮失败（静默当显式头＝渲染参数丢失而无人知）。
export const DEFAULT_HEADER = `---
config:
  htmlLabels: false
  themeVariables:
    edgeLabelBackground: "#ffffff"
  themeCSS: ".edgeLabel rect { opacity: 1; }"
  layout: elk
  elk:
    mergeEdges: false
    nodePlacementStrategy: NETWORK_SIMPLEX
  flowchart:
    htmlLabels: false
---
`;
export function renderSource(src) {
  if (!src.startsWith('---\n')) return DEFAULT_HEADER + src;
  if (!src.startsWith('---\nconfig:\n')) throw new Error('图源显式文件头须以 config: 开头（残缺头不当显式头——要么完整写头，要么不写头用默认头）');
  if (src.indexOf('\n---\n', 4) < 0) throw new Error('图源显式文件头未闭合（残缺头不当显式头——要么完整写头，要么不写头用默认头）');
  return src;
}
// manifest 哈希按**有效渲染源**（注入后文本）计——默认头一变，无头图源的哈希即变、全量重渲、陈旧判据抓响；
// 若按原始源计，改默认头不会触发重渲，投影静默陈旧。
export const effectiveHash = (src) => createHash('sha256').update(renderSource(src)).digest('hex').slice(0, 16);

// 围栏块提取（含位置）：start/end 为块在原文中的起止偏移，供消费者取「某块之后的正文区」
// （图文对齐判据据此定位容器图之后的编号边表区）——围栏解析只此一处，判据复用不另写正则（单一源纪律）。
export function extractMermaidBlocksWithSpan(text) {
  const blocks = [];
  const re = /```mermaid\n([\s\S]*?)```/g;
  let m;
  while ((m = re.exec(text)) !== null) blocks.push({ src: m[1], start: m.index, end: m.index + m[0].length });
  return blocks;
}

export function extractMermaidBlocks(text) {
  return extractMermaidBlocksWithSpan(text).map(b => b.src);
}

// 层三图源件发现：`<图纸区>/<容器>/<容器>.mmd`——一层子目录、文件名与目录同名（区契约「图源 .mmd 与详设文档 .md 成对」
// 的机械形态），整文件内容即图源。返回**相对承载文档面**的路径（以图纸区名开头）。
// root 形参供换根消费者（判据夹具在沙盒里跑）；缺区返空表。
// **发现逻辑只此一处**，渲染器与判据共用（单一源纪律，同 %% home 解析）。
export function listL3Sources(root = ROOT) {
  const zone = join(root, ARCH_ZONE);
  const out = [];
  let entries = [];
  try { entries = readdirSync(zone); } catch { return out; }
  for (const d of entries.sort((a, b) => a.localeCompare(b))) {
    if (d.startsWith('.')) continue;
    const file = join(zone, d, `${d}.mmd`);
    try {
      if (!statSync(join(zone, d)).isDirectory() || !statSync(file).isFile()) continue;
    } catch { continue; } // 无同名 .mmd 的子目录（候图脚手架、portable/）自然落选
    out.push(`${ARCH_SUBDIR}/${d}/${d}.mmd`);
  }
  return out;
}

// 外系统视图图源件发现：`<图纸区>/<名>/<名>-*.mmd`——一目录多图源、与详设 `<名>.md` 成对。
// 产物名＝%% name 自报（无前缀——外系统不冠层三前缀），归巢键照旧。
// **发现逻辑只此一处**，渲染器与判据共用（单一源纪律，同 listL3Sources）。
export function listExternalViewSources(root = ROOT) {
  const zone = join(root, ARCH_ZONE);
  const out = [];
  let entries = [];
  try { entries = readdirSync(zone); } catch { return out; }
  for (const d of entries.sort((a, b) => a.localeCompare(b))) {
    if (d.startsWith('.')) continue;
    const dirPath = join(zone, d);
    try { if (!statSync(dirPath).isDirectory()) continue; } catch { continue; }
    let files = [];
    try { files = readdirSync(dirPath); } catch { continue; }
    for (const f of files.sort((a, b) => a.localeCompare(b))) {
      if (f.startsWith(`${d}-`) && f.endsWith('.mmd')) {
        try { if (!statSync(join(dirPath, f)).isFile()) continue; } catch { continue; }
        out.push(`${ARCH_SUBDIR}/${d}/${f}`);
      }
    }
  }
  return out;
}

// root 形参供换根消费者（判据插件与夹具在沙盒里跑）：默认即实例根，语义与两个发现函数同款。
export function collectDiagrams(root = ROOT) {
  const items = [];
  // doc＝图源载体相对**承载文档面**的路径（L2 为承载文档 .md，L3 与外系统视图为图源件 .mmd）；
  // prefix＝产物文件名前缀（空串＝无前缀）；fallback＝无 %% name 时的退路名
  const add = (doc, src, prefix, fallback) => {
    // 语义命名：图源内以 %% name: 自报家门，防位置序号误读；无名者退回 fallback
    const named = src.match(/%%\s*name[:：]\s*([^\s%]+)/);
    // 归巢键：图源内以 %% home: <目录> 自报归属容器——产物落 <图纸区>/<home>/，
    // 可移植投影落 <图纸区>/<home>/portable/；无该键即落图纸区顶层（L2 级图）。
    // 目录名限 [a-z0-9-]+：不含分隔符，故拼接不可能越出图纸区。
    const home = src.match(/%%\s*home[:：]\s*([a-z0-9-]+)/);
    const file = `${prefix ? `${prefix}-` : ''}${named ? named[1] : fallback}.svg`;
    items.push({
      doc,
      home: home ? home[1] : '',
      // svg 是**相对图纸区根的路径**（渲染器与判据共用此一份解析——单一源纪律）
      svg: home ? `${home[1]}/${file}` : file,
      hash: (() => { try { return effectiveHash(src); } catch (e) { throw new Error(`${doc}：${(e as Error).message}`); } })(), // 残缺头报错带图源路径
      src,
    });
  };
  // L2 级：承载文档（承载文档面顶层 .md）内的 ```mermaid 围栏块；前缀＝product_prefix（有则取之），缺键取承载文档基名
  // 独立运行版规则（让项目先定稿 C1、C2，再逐个评估是否需要 C3）：承载文档里**只收自报 %% name: 的代码块**——
  // 图名是「这是一张架构图」的声明；没写图名的代码块是文档里的普通说明图（时序、数据实体、状态等），GitHub 照常显示，不进图纸区、不受三项检查。
  // 已声明于 settings.l2_diagrams 的图若丢了图名，(w) 以「找不到自报名为…的图源」报红，不会静默漏检。上游 envshell 此处收全部代码块（无名者退回「图N」）。
  const NAMED = /%%\s*name[:：]\s*[^\s%]+/;
  for (const f of listMdFiles(DOC_ZONE, root)) {
    extractMermaidBlocks(readDoc(DOC_ZONE, f, root)).forEach((src, i) => { if (NAMED.test(src)) add(f, src, PREFIX_OVERRIDE !== undefined ? PREFIX_OVERRIDE : docBase(f), `图${i + 1}`); });
  }
  // 层三级：独立图源件——整文件即图源，doc 记图源自身路径（图源就是正本，不再指向承载文档）
  for (const rel of listL3Sources(root)) {
    add(rel, readFileSync(join(root, DOC_ZONE, rel), 'utf8'), L3_SVG_PREFIX, basename(rel, '.mmd'));
  }
  // 外系统视图：整文件即图源，产物名＝%% name 自报（无前缀）
  for (const rel of listExternalViewSources(root)) {
    add(rel, readFileSync(join(root, DOC_ZONE, rel), 'utf8'), '', basename(rel, '.mmd'));
  }
  return items;
}

// 仅在直接运行时渲染（被判据导入时只提供收集器——看守者不得动环境）
import { pathToFileURL } from 'node:url';
if ((() => { try { return !!process.argv[1] && realpathSync(process.argv[1]) === realpathSync(fileURLToPath(import.meta.url)); } catch { return false; } })()) { // 真实路径比对：符号链接目录（如 /tmp）下字面不等
  if (process.argv.includes('--help')) {
    console.log([
      '图渲染器（制图域包）——把 mermaid 图源渲染为 SVG 投影',
      '',
      '用法：node --experimental-strip-types --disable-warning=ExperimentalWarning tool/diagram/render-diagrams.mts [--help]',
      '',
      `图纸区（settings.arch_zone）：${ARCH_ZONE}｜承载文档面：${DOC_ZONE || '（实例根）'}｜产物前缀（settings.product_prefix；缺键＝承载文档名）：${PREFIX_OVERRIDE !== undefined ? (PREFIX_OVERRIDE || '（空串＝无前缀）') : `（缺键——层三取 ${L3_SVG_PREFIX || '（无）'}、层二取各承载文档基名）`}`,
      `渲染依赖：${MMDC}（装法：cd tool/diagram && npm ci）｜浏览器住址：${PPTR_EXEC || '（未填——用引擎自带浏览器）'}`,
      '产物清单：<图纸区>/manifest.json（键＝产物相对图纸区路径，值＝源与有效源哈希）',
    ].join('\n'));
    process.exit(0);
  }
  const items = collectDiagrams();
  if (items.length === 0) {
    console.log('未发现 mermaid 图块。');
    process.exit(0);
  }
  if (!existsSync(MMDC)) {
    console.error(`渲染器未就绪：${MMDC} 不存在。安装：cd ${PACK_DIR} && npm install`);
    process.exit(2);
  }
  mkdirSync(OUT_DIR, { recursive: true });
  const prev = existsSync(MANIFEST) ? JSON.parse(readFileSync(MANIFEST, 'utf8')) : {};
  const manifest = {};
  for (const it of items) {
    manifest[it.svg] = { doc: it.doc, hash: it.hash };
    if (prev[it.svg]?.hash === it.hash && existsSync(join(OUT_DIR, it.svg))) {
      console.log(`未变更，跳过：${it.svg}`);
      continue;
    }
    // 临时源留在图纸区顶层（文件名取基名，免得相对路径里的分隔符被当成目录）
    const tmp = join(OUT_DIR, `.tmp-${basename(it.svg)}.mmd`);
    let effective; try { effective = renderSource(it.src); } catch (e) { throw new Error(`${it.doc}：${(e as Error).message}`); } // 残缺头报错带图源路径
    writeFileSync(tmp, effective, 'utf8');
    mkdirSync(dirname(join(OUT_DIR, it.svg)), { recursive: true }); // 归巢子目录按需现建
    // 渲染参数件只在真填了浏览器住址时才递给引擎：空 executablePath 递过去会让引擎去找一个不存在的浏览器，
    // 报出的错与「没装浏览器」难以分辨；不递则引擎用自带的那一个（本包依赖已带）。
    const pptrArgs = PPTR_EXEC ? ['-p', join(PACK_DIR, 'puppeteer-config.json')] : [];
    execFileSync(MMDC, ['-i', tmp, '-o', join(OUT_DIR, it.svg), '-b', 'transparent', ...pptrArgs], { stdio: 'pipe' });
    rmSync(tmp);
    console.log(`已渲染：${it.svg}（源 ${it.doc}）`);
  }
  // 键序沿用旧清单、新条目追加在后：键序无语义，序稳则 diff 只反映真实变更——
  // 发现顺序变动（如图源迁出承载文档）不该在清单上表现为整块搬家。
  const ordered = {};
  for (const k of Object.keys(prev)) if (k in manifest) ordered[k] = manifest[k];
  for (const k of Object.keys(manifest)) if (!(k in ordered)) ordered[k] = manifest[k];
  writeFileSync(MANIFEST, JSON.stringify(ordered, null, 2) + '\n', 'utf8');
  console.log(`完成：${items.length} 张图，manifest 已更新。`);
}
