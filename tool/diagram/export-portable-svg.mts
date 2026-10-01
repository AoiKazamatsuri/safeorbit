#!/usr/bin/env -S node --experimental-strip-types --disable-warning=ExperimentalWarning
// 独立运行版注记：本件自 envshell 仓 packs/diagram/export-portable-svg.mts@4a439c5 逐字承接，只改公共库导入路径（../../tool/lib.mts → ./lib.mts）与帮助文字里的路径（packs/diagram → tool/diagram）。
// 下文沿用上游用语：「本包」＝tool/diagram/，「本包登记表」＝tool/diagram/registry.json，「机检器」＝tool/diagram/check.mts，
// 「提交闸」＝tool/diagram/pre-commit.sh；「域包／元工具／三池」是 envshell 的装卸机制，独立运行版不设（见 tool/diagram/AGENTS.md）。
// 蓝本溯源：tool/export-portable-svg.mts@c192490（首实例仓）；档位：第二档工具（可调用不可改，自定义唯配置旋钮）；
// 手术：图纸区路径改读本包 settings（同渲染器一处正本），浏览器可执行文件住址改读本包 puppeteer-config.json
// 并在缺件时响亮报缺（原件读的是一个已迁走的旧址、缺件时静默回退到某台机器上的固定路径），剥治理记号与沿革注记。
//
// 可移植 SVG 导出器：把产线 SVG（mermaid 渲染）派生为矢量工具可导入的第二投影 `-portable.svg`。
// 背景：常见矢量工具的导入器不认产线 SVG 的三样机制——内嵌样式表＋类引用（黑盒之因）、箭头标记 marker（黑三角之因）、
// HTML 嵌套文字 foreignObject。靶格式＝经实测可导入的外部样本：样式全内联、箭头实体三角、零样式表零类引用零标记。
// 手法：浏览器计算样式烘焙——浏览器算出每个元素的最终样式后写回元素属性，几何 API 给出路径切线与文本基线，
// 确定性、零 LLM、零网络（本机浏览器，与渲染器同一依赖）。产物是机器派生投影，勿手改。
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { readFileSync, writeFileSync, readdirSync, statSync, existsSync, rmSync, mkdirSync } from 'node:fs';
import { join, dirname, basename } from 'node:path';
import { fileURLToPath } from 'node:url';
import { ROOT } from './lib.mts';
import { ARCH_ZONE } from './render-diagrams.mts';

const PACK_DIR = fileURLToPath(new URL('.', import.meta.url)).replace(/\/$/, '');
const DIAG_DIR = join(ROOT, ARCH_ZONE);
// 可移植投影住 portable/ 子目录——图纸区顶层一图一件，双投影不同层混淆。
// 分容器：每个需要组件图的容器有同名子目录，各带自己的 portable/；
// 全局清单只有一份、住图纸区顶层（键与源路径皆为相对图纸区根的路径）。
const MANIFEST = join(DIAG_DIR, 'portable-manifest.json');
const PPTR_CONFIG = join(PACK_DIR, 'puppeteer-config.json');

// 浏览器住址：本包渲染参数件的 executablePath 是唯一正本——缺件或路径不存在即**响亮报缺**，
// 不回退到某个平台上的固定路径（静默回退会让「装在别处」与「根本没装」在读数上一模一样）。
function resolveBrowser(): string {
  let p: unknown = null;
  try { p = JSON.parse(readFileSync(PPTR_CONFIG, 'utf8')).executablePath; } catch {
    throw new Error(`浏览器配置不可用：${PPTR_CONFIG}（缺件或坏 JSON）——本器官靠本机浏览器烘焙，先把 executablePath 填对`);
  }
  if (typeof p !== 'string' || !p.trim()) throw new Error(`${PPTR_CONFIG} 未给 executablePath——填本机浏览器可执行文件的绝对路径`);
  if (!existsSync(p)) throw new Error(`浏览器不在位：${p}（出自 ${PPTR_CONFIG}）——装一个或把路径改对`);
  return p;
}

// 页内烘焙脚本：在浏览器里对 SVG 做四步手术，随后 --dump-dom 收尸取回
const BAKE = `
(() => {
  const NS = 'http://www.w3.org/2000/svg';
  const svg = document.querySelector('svg');
  if (!svg) return;
  const toHex = (c) => {
    const m = String(c).match(/rgba?\\(([^)]+)\\)/);
    if (!m) return { color: c, alpha: null };
    const parts = m[1].split(',').map(s => parseFloat(s));
    const hex = '#' + parts.slice(0, 3).map(v => Math.round(v).toString(16).padStart(2, '0')).join('');
    return { color: hex, alpha: parts.length > 3 ? parts[3] : null };
  };
  const stripPx = (v) => String(v).replace(/px/g, '').trim();

  // 一、样式烘焙：把计算样式写回元素属性（填充与描边必写——fill:none 正是连线不糊黑的关键）
  const SHAPES = ['rect', 'circle', 'ellipse', 'polygon', 'polyline', 'line', 'path'];
  for (const el of Array.from(svg.querySelectorAll('*'))) {
    const tag = el.tagName.toLowerCase();
    if (!SHAPES.includes(tag) && tag !== 'text' && tag !== 'tspan') continue;
    const cs = getComputedStyle(el);
    const fill = toHex(cs.fill === '' ? 'none' : cs.fill);
    el.setAttribute('fill', cs.fill === 'none' || cs.fill === '' ? 'none' : fill.color);
    if (fill.alpha !== null && fill.alpha < 1) el.setAttribute('fill-opacity', String(fill.alpha));
    const stroke = toHex(cs.stroke);
    el.setAttribute('stroke', cs.stroke === 'none' || cs.stroke === '' ? 'none' : stroke.color);
    if (cs.stroke !== 'none' && cs.stroke !== '') {
      el.setAttribute('stroke-width', stripPx(cs.strokeWidth));
      if (cs.strokeDasharray && cs.strokeDasharray !== 'none') el.setAttribute('stroke-dasharray', stripPx(cs.strokeDasharray).replace(/,/g, ' '));
    }
    if (tag === 'text' || tag === 'tspan') {
      el.setAttribute('font-family', cs.fontFamily.replace(/"/g, ''));
      el.setAttribute('font-size', stripPx(cs.fontSize));
      if (cs.fontWeight !== '400' && cs.fontWeight !== 'normal') el.setAttribute('font-weight', cs.fontWeight);
    }
  }

  // 二、箭头实体化：按路径末端切线画实体小三角，随后剥掉 marker 引用
  const addTri = (parent, tip, back, color) => {
    const ang = Math.atan2(tip.y - back.y, tip.x - back.x);
    const L = 10, W = 7;
    const bx = tip.x - L * Math.cos(ang), by = tip.y - L * Math.sin(ang);
    const ox = (W / 2) * Math.sin(ang), oy = -(W / 2) * Math.cos(ang);
    const poly = document.createElementNS(NS, 'polygon');
    poly.setAttribute('points',
      tip.x.toFixed(2) + ',' + tip.y.toFixed(2) + ' ' +
      (bx + ox).toFixed(2) + ',' + (by + oy).toFixed(2) + ' ' +
      (bx - ox).toFixed(2) + ',' + (by - oy).toFixed(2));
    poly.setAttribute('fill', color);
    poly.setAttribute('stroke', 'none');
    parent.appendChild(poly);
  };
  for (const path of Array.from(svg.querySelectorAll('[marker-end], [marker-start]'))) {
    if (typeof path.getTotalLength !== 'function') continue;
    let total = 0;
    try { total = path.getTotalLength(); } catch { continue; }
    if (total <= 0) continue;
    const color = path.getAttribute('stroke') && path.getAttribute('stroke') !== 'none' ? path.getAttribute('stroke') : '#333333';
    if (path.hasAttribute('marker-end')) {
      addTri(path.parentNode, path.getPointAtLength(total), path.getPointAtLength(Math.max(0, total - 8)), color);
      path.removeAttribute('marker-end');
    }
    if (path.hasAttribute('marker-start')) {
      addTri(path.parentNode, path.getPointAtLength(0), path.getPointAtLength(Math.min(total, 8)), color);
      path.removeAttribute('marker-start');
    }
  }

  // 三、文本扁平化：多行 tspan 拍平为独立 text（绝对基线坐标、锚点归一为 start）——对齐靶格式
  for (const t of Array.from(svg.querySelectorAll('text'))) {
    // 只取直接子级的「行」tspan——渲染器的行内还套「词」tspan，全量拍平会行、词各发一份成重影；
    // textContent 取行级即自动并入行内各词。
    const spans = Array.from(t.children).filter(c => c.tagName && c.tagName.toLowerCase() === 'tspan');
    const parent = t.parentNode;
    const emit = (node, content) => {
      const cs = getComputedStyle(node);
      let pt;
      try { pt = node.getStartPositionOfChar(0); } catch { return; }
      const nt = document.createElementNS(NS, 'text');
      nt.setAttribute('x', pt.x.toFixed(2));
      nt.setAttribute('y', pt.y.toFixed(2));
      nt.setAttribute('text-anchor', 'start');
      nt.setAttribute('font-family', cs.fontFamily.replace(/"/g, ''));
      nt.setAttribute('font-size', stripPx(cs.fontSize));
      if (cs.fontWeight !== '400' && cs.fontWeight !== 'normal') nt.setAttribute('font-weight', cs.fontWeight);
      nt.setAttribute('fill', toHex(cs.fill).color);
      nt.textContent = content;
      parent.insertBefore(nt, t);
    };
    if (spans.length === 0) {
      if (t.textContent && t.textContent.trim()) { emit(t, t.textContent.trim()); t.remove(); }
      continue;
    }
    for (const sp of spans) {
      if (sp.textContent && sp.textContent.trim()) emit(sp, sp.textContent.trim());
    }
    t.remove();
  }

  // 四、剥离：样式表、类引用、标记定义、根上的 HTML 化痕迹
  svg.querySelectorAll('style').forEach(s => s.remove());
  svg.querySelectorAll('marker').forEach(m => m.remove());
  svg.querySelectorAll('defs').forEach(d => { if (!d.children.length) d.remove(); });
  svg.querySelectorAll('[class]').forEach(el => el.removeAttribute('class'));
  svg.removeAttribute('class'); // querySelectorAll 只及子孙——根节点自己的类引用得单收
  svg.removeAttribute('style');
  const vb = (svg.getAttribute('viewBox') || '').split(/\\s+/).map(Number);
  if (vb.length === 4) { svg.setAttribute('width', String(vb[2])); svg.setAttribute('height', String(vb[3])); }
})();
`;

function exportOne(browser: string, rel: string): string {
  const srcPath = join(DIAG_DIR, rel);
  const svgText = readFileSync(srcPath, 'utf8');
  const harness = `<!doctype html><meta charset="utf-8"><body>\n${svgText}\n<script>${BAKE}</script>`;
  // 临时件留在图纸区顶层（文件名取基名，免得相对路径里的分隔符被当成目录）
  const tmp = join(DIAG_DIR, `.tmp-portable-${basename(rel)}.html`);
  writeFileSync(tmp, harness, 'utf8');
  let dump = '';
  try {
    dump = execFileSync(browser, ['--headless', '--disable-gpu', '--dump-dom', `file://${tmp}`],
      { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024, stdio: ['ignore', 'pipe', 'ignore'] });
  } finally { rmSync(tmp, { force: true }); }
  const m = dump.match(/<svg[\s\S]*<\/svg>/);
  if (!m) throw new Error(`烘焙失败：${rel} 的输出里找不到 SVG`);
  return m[0];
}

// 递归收集产线 SVG：图纸区下全部非 portable 目录内的 *.svg——
// 顶层住 L2 级图，容器子目录住该容器的组件图；任何 portable/ 目录整枝跳过（那是产物不是源）。
function collectCanonical(dir: string): string[] {
  const out: string[] = [];
  let entries: string[] = [];
  try { entries = readdirSync(join(DIAG_DIR, dir || '.')); } catch { return out; }
  for (const e of entries.sort()) {
    if (e.startsWith('.')) continue;
    const rel = dir ? `${dir}/${e}` : e;
    let st; try { st = statSync(join(DIAG_DIR, rel)); } catch { continue; }
    if (st.isDirectory()) {
      if (e === 'portable') continue;
      out.push(...collectCanonical(rel));
    } else if (e.endsWith('.svg') && !e.endsWith('-portable.svg')) {
      out.push(rel);
    }
  }
  return out;
}

// 出厂自检：四项归零（靶格式合规），不过关不落盘——验收先于交付
function selfCheck(name: string, body: string): string[] {
  const bad: string[] = [];
  if (body.includes('<foreignObject')) bad.push('HTML 嵌套文字残留');
  if (body.includes('<style')) bad.push('样式表残留');
  if (/\sclass="/.test(body)) bad.push('类引用残留');
  if (body.includes('<marker')) bad.push('箭头标记残留');
  if ((body.match(/fill="/g) ?? []).length < 10) bad.push('内联填充属性过少（烘焙疑似未生效）');
  return bad.map(x => `${name}: ${x}`);
}

if (process.argv.includes('--help')) {
  console.log([
    '可移植 SVG 导出器（制图域包）——产线 SVG 派生为矢量工具可导入的第二投影',
    '',
    '用法：node --experimental-strip-types --disable-warning=ExperimentalWarning tool/diagram/export-portable-svg.mts [--help]',
    '',
    `图纸区（settings.arch_zone）：${ARCH_ZONE}`,
    `浏览器住址正本：${PPTR_CONFIG} 的 executablePath（缺件即响亮报缺，不静默回退）`,
    '产物：<图纸区>/<容器>/portable/<名>-portable.svg ＋ 图纸区顶层 portable-manifest.json',
  ].join('\n'));
  process.exit(0);
}

const canonical = collectCanonical('');
if (canonical.length === 0) { console.log('无产线 SVG 可导出。'); process.exit(0); }
let BROWSER: string;
try { BROWSER = resolveBrowser(); } catch (e) { console.error((e as Error).message); process.exit(2); }
const manifest: Record<string, { source: string; source_hash: string }> = {};
const failures: string[] = [];
for (const rel of canonical) {
  const out = exportOne(BROWSER, rel);
  const problems = selfCheck(rel, out);
  if (problems.length) { failures.push(...problems); continue; }
  // 投影落「源所在目录/portable/」——顶层图落 portable/，容器图落 <容器>/portable/
  const dir = dirname(rel) === '.' ? '' : dirname(rel);
  const prel = `${dir ? dir + '/' : ''}portable/${basename(rel).replace(/\.svg$/, '-portable.svg')}`;
  mkdirSync(join(DIAG_DIR, dirname(prel)), { recursive: true });
  writeFileSync(join(DIAG_DIR, prel), out + '\n', 'utf8');
  manifest[prel] = { source: rel, source_hash: createHash('sha256').update(readFileSync(join(DIAG_DIR, rel))).digest('hex').slice(0, 16) };
  console.log(`已导出：${prel}（源 ${rel}）`);
}
if (failures.length) {
  console.error(`导出自检未过（不落盘）：\n  ${failures.join('\n  ')}`);
  process.exit(1);
}
writeFileSync(MANIFEST, JSON.stringify(manifest, null, 2) + '\n', 'utf8');
console.log(`完成：${canonical.length} 张可移植投影，portable-manifest 已更新。`);
