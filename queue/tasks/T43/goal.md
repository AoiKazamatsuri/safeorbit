# 安全区日常地点标签与 SF Symbols 图标扩展

## 范围

- 要交付：安全区日常地点标签与图标的统一配置；扩展新增、编辑安全区页的预置标签，并让位置页地图按对应地点显示图标；未知、自定义地点默认显示定位针。
- 拟采用的对应表如下，作为本任务方案，不直接写入已确认的产品要求：

| 地点 | 英文标签 | SF Symbols 名称 |
| --- | --- | --- |
| 家 | Home | house.fill |
| 市场、超市 | Market | storefront.fill |
| 医院、诊所 | Hospital | cross.case.fill |
| 药店 | Pharmacy | pills.fill |
| 地铁站 | Subway Station | tram.fill |
| 公交站 | Bus Stop | bus.fill |
| 饭店、食堂 | Restaurant | fork.knife |
| 公园 | Park | tree.fill |
| 商场 | Shopping Mall | bag.fill |
| 银行 | Bank | building.columns.fill |
| 社区活动中心 | Community Center | person.3.fill |
| 其他、自定义地点 | 自定义名称 | mappin.and.ellipse |

- 沿用地图标记的白色图标、青绿色圆底；保留现有自定义标签功能；图标查找处理英文大小写和首尾空格，未知名称用通用定位针；家的图标沿用现有 isHomeZone 判断，不修改家的业务规则。
- 保持现有安全区请求、回复与存储格式，图标由 App 根据标签映射；本件不新增图标选择器，不自动猜测具体地址或任意自定义名称的地点类型。
- 产品设计第 5.4 节同步列明扩展后的预置地点与自定义地点图标规则；须在本件获批准后更新。
- 不包含：后端、数据库、地图服务、出行与风险规则、老人端独立页面、其他页面版式整理、完整中文翻译、新增依赖。
- 拟允许修改的位置：object/ios/SafeOrbit/LocationUI.swift、object/ios/SafeOrbit/LocationModels.swift、object/ios/SafeOrbit/Localizable.xcstrings（仅新增地点标签资源）、object/ios/SafeOrbitTests/LocationTests.swift、truth/产品设计.md（仅第 5.4 节与本件修订说明）。任务记录只经队列工具维护；既有未提交差异不混入本件。

## 验收标准与验证方法

| 编号 | 可观察的结果 | 验证方法 | 通过条件 |
| --- | --- | --- | --- |
| A1 | 日常地点显示对应图标 | 对照上表逐项核对映射；用 UIKit 的 UIImage(systemName:) 在 iOS 模拟器验证符号存在 | 11 类预置地点均对应指定符号；Hospital 不再显示店铺；符号均能生成图片 |
| A2 | 旧数据与自定义标签可继续使用 | 核对现有 Home、Market、Hospital 数据；测试英文大小写、首尾空格、未知名称以及显式家的标记 | 旧数据不需迁移；家的图标遵守现有判断；未知名称显示定位针；不改安全区网络数据格式 |
| A3 | 新增、编辑和地图展示一致 | 模拟器实际打开新增、编辑安全区页，逐类选择、保存并返回地图；核对长标签和横向滚动 | 所有预置标签可选，地图与所选标签一致，自定义标签可保存；现有标记样式保持，文字可读、选项可达 |
| A4 | 自动化检查通过 | 仓库根运行 sh object/dev/ios-check.sh 全套；git diff --check；修改 truth 后运行 node --experimental-strip-types --disable-warning=ExperimentalWarning tool/diagram/check.mts；提交时运行队列检查 | 各命令退出码 0，无失败用例；新增必要的映射、兼容与符号存在性用例 |
| A5 | 要求与实现一致、改动在范围内 | 阅读产品设计第 5.4 节及 git diff --stat、git diff | 要求与上述对应表及自定义地点规则一致；仅修改授权位置 |

验收安排：执行者代跑检查和模拟器核对，回执附原样命令、退出码与输出摘录，标明未独立验证；截图放会话临时目录供用户查看。最终产品效果与是否通过由用户决定。本轮只有任务登记，不运行 App 开发验收。
