// 制图工具公共库（独立运行版新写）。
// 来源：envshell 仓 tool/lib.mts@4a439c5 中制图工具用到的五项（ROOT、DEFAULT_LAYOUT.truth_dir、listMdFiles、readDoc、docBase），
// 函数体逐字承接；其余与 envshell 队列、登记表相关的读取器独立运行版不需要，不搬。
//
// 纪律：零依赖、零网络；本件只放解析与读取，不写盘、不判定。
import { existsSync, readFileSync, readdirSync, statSync } from 'node:fs';
import { join, basename } from 'node:path';
import { fileURLToPath } from 'node:url';

/**
 * 仓库根：环境变量 DIAGRAM_ROOT 优先（夹具与临时检查用）；否则＝本件所在 tool/diagram/ 的上两级。
 * 检查入口 check.mts 另有 --root 与 --staged，走 checks 的 ctx.root，不经此值。
 */
export const ROOT: string = (process.env.DIAGRAM_ROOT && process.env.DIAGRAM_ROOT.trim())
  ? process.env.DIAGRAM_ROOT.trim().replace(/\/$/, '')
  : fileURLToPath(new URL('../..', import.meta.url)).replace(/\/$/, '');

/** 默认布局：制图工具只用到 truth 目录（registry.json 未给 settings.arch_zone 时的图纸区默认值＝truth/architecture）。 */
export const DEFAULT_LAYOUT = {
  truth_dir: 'truth',
};

/** 列出某目录下的 markdown 文件（不递归；缺目录返回空表而非抛错）。 */
export function listMdFiles(dir: string, root: string = ROOT): string[] {
  const abs = join(root, dir);
  if (!existsSync(abs)) return [];
  return readdirSync(abs)
    .filter(f => f.endsWith('.md') && !f.startsWith('.'))
    .filter(f => statSync(join(abs, f)).isFile())
    .sort((a, b) => a.localeCompare(b, 'zh-Hans-CN-u-co-pinyin'));
}

export function readDoc(dir: string, file: string, root: string = ROOT): string {
  return readFileSync(join(root, dir, file), 'utf8');
}

export function docBase(file: string): string {
  return basename(file, '.md');
}
