# 安全区日常地点标签与 SF Symbols 图标扩展

```json
{
  "id": "T43",
  "revision": 730,
  "assignee": "Codex",
  "parent": null,
  "deps": [],
  "round": 1,
  "status": "交付"
}
```

## 登记依据

用户指出安全区标签目前只有家和市场两种图标，希望补齐医院、地铁站、饭店等日常地点，并在收到一套 12 类地点的 SF Symbols 建议后要求登记为新任务。本次指令只登记方案，不代表批准实施或验收通过。

只读核对发现，位置页以名称是否等于 Home 二选一显示 house.fill 或 storefront.fill；编辑页已有 Home、Market、Hospital 三个预置标签，但 Hospital 也显示成店铺。本件拟统一地点标签与图标的对应关系，供后续批准实施。

## 任务包

- [规划目标](goal.md)
- [执行计划](plan.md)

## 批准基线与回执

- [approval-001.md](approval-001.md)
- [receipt-000730.md](receipt-000730.md)

## 过程记录

- #715｜create｜Codex｜{"authority": null, "deps": [], "id": "T43", "parent": null, "proposal": {"criteria": "| 编号 | 可观察的结果 | 验证方法 | 通过条件 |\n| --- | --- | --- | --- |\n| A1 | 日常地点显示对应图标 | 对照上表逐项核对映射；用 UIKit 的 UIImage(systemName:) 在 iOS 模拟器验证符号存在 | 11 类预置地点均对应指定符号；Hospital 不再显示店铺；符号均能生成图片 |\n| A2 | 旧数据与自定义标签可继续使用 | 核对现有 Home、Market、Hospital 数据；测试英文大小写、首尾空格、未知名称以及显式家的标记 | 旧数据不需迁移；家的图标遵守现有判断；未知名称显示定位针；不改安全区网络数据格式 |\n| A3 | 新增、编辑和地图展示一致 | 模拟器实际打开新增、编辑安全区页，逐类选择、保存并返回地图；核对长标签和横向滚动 | 所有预置标签可选，地图与所选标签一致，自定义标签可保存；现有标记样式保持，文字可读、选项可达 |\n| A4 | 自动化检查通过 | 仓库根运行 sh object/dev/ios-check.sh 全套；git diff --check；修改 truth 后运行 node --experimental-strip-types --disable-warning=ExperimentalWarning tool/diagram/check.mts；提交时运行队列检查 | 各命令退出码 0，无失败用例；新增必要的映射、兼容与符号存在性用例 |\n| A5 | 要求与实现一致、改动在范围内 | 阅读产品设计第 5.4 节及 git diff --stat、git diff | 要求与上述对应表及自定义地点规则一致；仅修改授权位置 |\n\n验收安排：执行者代跑检查和模拟器核对，回执附原样命令、退出码与输出摘录，标明未独立验证；截图放会话临时目录供用户查看。最终产品效果与是否通过由用户决定。本轮只有任务登记，不运行 App 开发验收。", "origin": "用户指出安全区标签目前只有家和市场两种图标，希望补齐医院、地铁站、饭店等日常地点，并在收到一套 12 类地点的 SF Symbols 建议后要求登记为新任务。本次指令只登记方案，不代表批准实施或验收通过。\n\n只读核对发现，位置页以名称是否等于 Home 二选一显示 house.fill 或 storefront.fill；编辑页已有 Home、Market、Hospital 三个预置标签，但 Hospital 也显示成店铺。本件拟统一地点标签与图标的对应关系，供后续批准实施。", "plan": "1. 本轮通过队列工具登记方案，保持登记状态，同批提交并推送任务记录；不批准、不领取、不改产品代码。\n2. 后续获得用户明确批准后，核对最新工作树、状态包及本件基线，再领取施工；与其他涉及位置页的任务协调写入，保护既有差异。\n3. 更新产品设计第 5.4 节，集中实现标签及图标配置，接入编辑页和位置页；补充必要测试。\n4. 施工中只跑受影响测试类；交付前按 gate/checks.md 跑一次不设 SAFEORBIT_ONLY_TESTING 的 iOS 全套，再跑图纸、差异及队列检查，并在模拟器核对画面。\n5. 写回执交付，同批提交并推送，等用户验收；不把自验通过当作用户验收。", "scope": "- 要交付：安全区日常地点标签与图标的统一配置；扩展新增、编辑安全区页的预置标签，并让位置页地图按对应地点显示图标；未知、自定义地点默认显示定位针。\n- 拟采用的对应表如下，作为本任务方案，不直接写入已确认的产品要求：\n\n| 地点 | 英文标签 | SF Symbols 名称 |\n| --- | --- | --- |\n| 家 | Home | house.fill |\n| 市场、超市 | Market | storefront.fill |\n| 医院、诊所 | Hospital | cross.case.fill |\n| 药店 | Pharmacy | pills.fill |\n| 地铁站 | Subway Station | tram.fill |\n| 公交站 | Bus Stop | bus.fill |\n| 饭店、食堂 | Restaurant | fork.knife |\n| 公园 | Park | tree.fill |\n| 商场 | Shopping Mall | bag.fill |\n| 银行 | Bank | building.columns.fill |\n| 社区活动中心 | Community Center | person.3.fill |\n| 其他、自定义地点 | 自定义名称 | mappin.and.ellipse |\n\n- 沿用地图标记的白色图标、青绿色圆底；保留现有自定义标签功能；图标查找处理英文大小写和首尾空格，未知名称用通用定位针；家的图标沿用现有 isHomeZone 判断，不修改家的业务规则。\n- 保持现有安全区请求、回复与存储格式，图标由 App 根据标签映射；本件不新增图标选择器，不自动猜测具体地址或任意自定义名称的地点类型。\n- 产品设计第 5.4 节同步列明扩展后的预置地点与自定义地点图标规则；须在本件获批准后更新。\n- 不包含：后端、数据库、地图服务、出行与风险规则、老人端独立页面、其他页面版式整理、完整中文翻译、新增依赖。\n- 拟允许修改的位置：object/ios/SafeOrbit/LocationUI.swift、object/ios/SafeOrbit/LocationModels.swift、object/ios/SafeOrbit/Localizable.xcstrings（仅新增地点标签资源）、object/ios/SafeOrbitTests/LocationTests.swift、truth/产品设计.md（仅第 5.4 节与本件修订说明）。任务记录只经队列工具维护；既有未提交差异不混入本件。", "title": "安全区日常地点标签与 SF Symbols 图标扩展"}}
- #728｜approve｜Codex｜{"authority": {"basis": "用户明确要求实施 T43，按已登记的 11 类安全区预置标签、图标映射和验收范围开发。", "by": "用户"}, "expect": 715, "id": "T43"}
- #729｜claim｜Codex｜{"expect": 728, "id": "T43"}
- #730｜deliver｜Codex｜{"artifacts": [{"path": "object/ios/SafeOrbit/Localizable.xcstrings", "sha256": "018a5f05b16c3ed7a0fa5978342a042a1c9be334a6e03d13be39bc1fb55dbf00"}, {"path": "object/ios/SafeOrbit/LocationModels.swift", "sha256": "144a8f6af0840b1a9c8df6bba95ccf52b270efa438af3614d98b47aed808e45f"}, {"path": "object/ios/SafeOrbit/LocationUI.swift", "sha256": "e2f197ae58def1cdb2a00b6fda9cb302dc51003b6cdacdfeaf46739e1b66ed0c"}, {"path": "object/ios/SafeOrbitTests/LocationTests.swift", "sha256": "6a044e5cb39d5c305f7715b3acbb458901e82ef521f910892b6144351b8572bc"}, {"path": "truth/产品设计.md", "sha256": "d0b17f397ebbe35e09e44c55eee23a5ca6700c4d3ef6e66cebe99cd039c00ca1"}], "expect": 729, "id": "T43", "receipt": "# T43 交付回执\n\n## 实现\n\n- 新增、编辑安全区共用 11 类预置地点。较长标签可横向滚动查看，打开编辑页会显示当前选择。自定义标签、已有名称与数据格式照常使用。\n- 位置页按名称匹配对应图标，忽略英文大小写和首尾空白。既有的家标记优先，未匹配标签使用通用定位针。地图标记沿用白色图标与青绿色圆底。\n- 字符串目录添加 11 个地点资源，产品设计第 5.4 节登记标签与图标对应关系。没有新增依赖。\n- 只读探查和初版实现由子代理完成。执行者复核并调整了标签资源的调用方式，沿用地图标记的更新机制，负责合入、测试和交付。本回执的读数为执行者自验，未独立验证。\n\n## A1、A2、A4、A5 的检查\n\n- 独立工作副本中，取消设置 `SAFEORBIT_ONLY_TESTING` 后运行 `SAFEORBIT_SIMULATOR_ID=\"$qa_id\" sh object/dev/ios-check.sh`，退出码 0。原样摘录 `Executed 168 tests, with 0 failures (0 unexpected) in 624.444 (624.515) seconds`、`** TEST SUCCEEDED **`。新增用例核对全部 11 个图标与通用定位针在 iOS 上可加载，覆盖旧格式、显式家标记、大小写、空白和自定义标签。\n- `node --experimental-strip-types --disable-warning=ExperimentalWarning tool/diagram/check.mts`，退出码 0，原样摘录 `无红。`。\n- `git diff --check` 和 `git diff --cached --check`，退出码 0，输出为空。按允许位置核对暂存改动，产品设计只改第 5.4 节。\n- 资源目录的 JSON 比对退出码 0，原样摘录 `PASS: 11 preset resources are the only committed catalog changes; all pre-existing working catalog entries are preserved.`。与资源目录有关的既有未提交改动另外保留，签名设置的既有改动也仍在工作区。\n- 交付前运行 `sh object/dev/queue.sh check --staged`，退出码 0，原样输出 `{\"ok\": true, \"checked\": \"staged\", \"seq\": 729}`。提交时正常钩子会再核对交付工件。\n\n## A3 的模拟器核对\n\n- 在 iPhone 17e 模拟器用普通构建和示例数据打开家属端，新增页列出全部 11 类；横向拖动后，Community Center 完整显示并可选中，原样摘录 `button (selected) Description: #Community Center`。普通构建按既有规则提示 `AMap requires a physical iPhone on this simulator runtime.`，保存按钮显示 `button (disabled) Description: Create Safe Zone`。\n- 在临时副本里以模拟器可用状态替代高德选点，运行家属端示例数据。通过 Device Hub 实际进入编辑页，依次选择并保存全部 11 类，每次返回地图并核对标记，输出摘录 `Hospital = cross.case.fill`、`Community Center = person.3.fill`、`Home = house.fill`。另从新增页选 Hospital 并创建，地图读数为 `Description: Edit Hospital safe zone, ID: cross.case.fill`。\n- 从新增页创建自定义标签 Grandma Garden，保存后地图标记为 `Grandma Garden = mappin.and.ellipse`，重开编辑页读到 `button (selected) Description: #Grandma Garden`。\n- 临时测试构建以同一工程运行 `xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination \"platform=iOS Simulator,id=$qa_id\" -derivedDataPath \"$fixture_derived_data\" CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- build`，退出码 0，原样摘录 `** BUILD SUCCEEDED **`。截图留在会话临时目录。模拟器保存验证使用本地示例数据，真机高德选点和实际服务器保存留给最终产品验收。\n", "summary": "新增和编辑安全区共用 11 类标签，地图图标匹配并兼容旧数据和自定义标签；全套 iOS 测试及模拟器界面核对通过，真机高德保存待用户验收。", "verification": "passed"}

## 接手说明

尚无接手说明。

> 工具生成；状态来自机器账，不可直接编辑。授权为 Agent 代书，未独立见证。
