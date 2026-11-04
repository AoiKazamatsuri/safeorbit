# 安全区日常地点标签与 SF Symbols 图标扩展

```json
{
  "id": "T43",
  "revision": 715,
  "assignee": null,
  "parent": null,
  "deps": [],
  "round": 0,
  "status": "登记"
}
```

## 登记依据

用户指出安全区标签目前只有家和市场两种图标，希望补齐医院、地铁站、饭店等日常地点，并在收到一套 12 类地点的 SF Symbols 建议后要求登记为新任务。本次指令只登记方案，不代表批准实施或验收通过。

只读核对发现，位置页以名称是否等于 Home 二选一显示 house.fill 或 storefront.fill；编辑页已有 Home、Market、Hospital 三个预置标签，但 Hospital 也显示成店铺。本件拟统一地点标签与图标的对应关系，供后续批准实施。

## 任务包

- [规划目标](goal.md)
- [执行计划](plan.md)

## 批准基线与回执


## 过程记录

- #715｜create｜Codex｜{"authority": null, "deps": [], "id": "T43", "parent": null, "proposal": {"criteria": "| 编号 | 可观察的结果 | 验证方法 | 通过条件 |\n| --- | --- | --- | --- |\n| A1 | 日常地点显示对应图标 | 对照上表逐项核对映射；用 UIKit 的 UIImage(systemName:) 在 iOS 模拟器验证符号存在 | 11 类预置地点均对应指定符号；Hospital 不再显示店铺；符号均能生成图片 |\n| A2 | 旧数据与自定义标签可继续使用 | 核对现有 Home、Market、Hospital 数据；测试英文大小写、首尾空格、未知名称以及显式家的标记 | 旧数据不需迁移；家的图标遵守现有判断；未知名称显示定位针；不改安全区网络数据格式 |\n| A3 | 新增、编辑和地图展示一致 | 模拟器实际打开新增、编辑安全区页，逐类选择、保存并返回地图；核对长标签和横向滚动 | 所有预置标签可选，地图与所选标签一致，自定义标签可保存；现有标记样式保持，文字可读、选项可达 |\n| A4 | 自动化检查通过 | 仓库根运行 sh object/dev/ios-check.sh 全套；git diff --check；修改 truth 后运行 node --experimental-strip-types --disable-warning=ExperimentalWarning tool/diagram/check.mts；提交时运行队列检查 | 各命令退出码 0，无失败用例；新增必要的映射、兼容与符号存在性用例 |\n| A5 | 要求与实现一致、改动在范围内 | 阅读产品设计第 5.4 节及 git diff --stat、git diff | 要求与上述对应表及自定义地点规则一致；仅修改授权位置 |\n\n验收安排：执行者代跑检查和模拟器核对，回执附原样命令、退出码与输出摘录，标明未独立验证；截图放会话临时目录供用户查看。最终产品效果与是否通过由用户决定。本轮只有任务登记，不运行 App 开发验收。", "origin": "用户指出安全区标签目前只有家和市场两种图标，希望补齐医院、地铁站、饭店等日常地点，并在收到一套 12 类地点的 SF Symbols 建议后要求登记为新任务。本次指令只登记方案，不代表批准实施或验收通过。\n\n只读核对发现，位置页以名称是否等于 Home 二选一显示 house.fill 或 storefront.fill；编辑页已有 Home、Market、Hospital 三个预置标签，但 Hospital 也显示成店铺。本件拟统一地点标签与图标的对应关系，供后续批准实施。", "plan": "1. 本轮通过队列工具登记方案，保持登记状态，同批提交并推送任务记录；不批准、不领取、不改产品代码。\n2. 后续获得用户明确批准后，核对最新工作树、状态包及本件基线，再领取施工；与其他涉及位置页的任务协调写入，保护既有差异。\n3. 更新产品设计第 5.4 节，集中实现标签及图标配置，接入编辑页和位置页；补充必要测试。\n4. 施工中只跑受影响测试类；交付前按 gate/checks.md 跑一次不设 SAFEORBIT_ONLY_TESTING 的 iOS 全套，再跑图纸、差异及队列检查，并在模拟器核对画面。\n5. 写回执交付，同批提交并推送，等用户验收；不把自验通过当作用户验收。", "scope": "- 要交付：安全区日常地点标签与图标的统一配置；扩展新增、编辑安全区页的预置标签，并让位置页地图按对应地点显示图标；未知、自定义地点默认显示定位针。\n- 拟采用的对应表如下，作为本任务方案，不直接写入已确认的产品要求：\n\n| 地点 | 英文标签 | SF Symbols 名称 |\n| --- | --- | --- |\n| 家 | Home | house.fill |\n| 市场、超市 | Market | storefront.fill |\n| 医院、诊所 | Hospital | cross.case.fill |\n| 药店 | Pharmacy | pills.fill |\n| 地铁站 | Subway Station | tram.fill |\n| 公交站 | Bus Stop | bus.fill |\n| 饭店、食堂 | Restaurant | fork.knife |\n| 公园 | Park | tree.fill |\n| 商场 | Shopping Mall | bag.fill |\n| 银行 | Bank | building.columns.fill |\n| 社区活动中心 | Community Center | person.3.fill |\n| 其他、自定义地点 | 自定义名称 | mappin.and.ellipse |\n\n- 沿用地图标记的白色图标、青绿色圆底；保留现有自定义标签功能；图标查找处理英文大小写和首尾空格，未知名称用通用定位针；家的图标沿用现有 isHomeZone 判断，不修改家的业务规则。\n- 保持现有安全区请求、回复与存储格式，图标由 App 根据标签映射；本件不新增图标选择器，不自动猜测具体地址或任意自定义名称的地点类型。\n- 产品设计第 5.4 节同步列明扩展后的预置地点与自定义地点图标规则；须在本件获批准后更新。\n- 不包含：后端、数据库、地图服务、出行与风险规则、老人端独立页面、其他页面版式整理、完整中文翻译、新增依赖。\n- 拟允许修改的位置：object/ios/SafeOrbit/LocationUI.swift、object/ios/SafeOrbit/LocationModels.swift、object/ios/SafeOrbit/Localizable.xcstrings（仅新增地点标签资源）、object/ios/SafeOrbitTests/LocationTests.swift、truth/产品设计.md（仅第 5.4 节与本件修订说明）。任务记录只经队列工具维护；既有未提交差异不混入本件。", "title": "安全区日常地点标签与 SF Symbols 图标扩展"}}

## 接手说明

尚无接手说明。

> 工具生成；状态来自机器账，不可直接编辑。授权为 Agent 代书，未独立见证。
