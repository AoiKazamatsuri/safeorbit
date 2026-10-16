# 记录页：恢复 Trend 指标卡并排，点日期显示整周，详情轨迹改实线

## 范围

- 要交付：
  - Trend 四张指标卡：默认字号下，宽度不小于 380 点时排两列，每张卡左边数字、右边两根柱状图并排，同排两卡等高；“50%”这类数字与单位不拆行，箭头与变化百分比同在一行。窄于 380 点时改为单列，每张卡仍然并排。辅助功能大字号下允许单列、卡内上下排列，不裁切、不重叠。保留 16 点左右外边距，不改字体、配色和卡片内容。
  - 一周统一为周一到周日：`DemoRecords.calendar` 的一周起始日改为周一，本周列表、上一周与下一周、趋势图八周分组都随之按周一起算（趋势图标签变为 Jul 6 … Aug 24，与设计稿 09 一致）。月历表头仍从周日开始，与设计稿 07 一致。按月统计的数字（本月合计、环比、指标卡与智能体示例回答）不变。
  - 点月历日期显示整周：点任一日期，下方列表切到该日期所在的周一到周日，并展开显示这一周的全部出行，不再只列当天。例如点 8 月 26 日显示 Aug 24 – Aug 30；点 8 月 2 日（周日）显示 Jul 27 – Aug 2，含 7 月底的出行。默认显示演示数据的当前周 Aug 24 – Aug 30。从出行详情返回后仍停在该周；切换月份不改变列表所示的周（沿用现状）。
  - 列表标题：所示周为演示数据当前周时显示“This Week”和日期区间（与设计稿 07 一致），其他周只显示日期区间；去掉单日筛选用的“Clear”按钮。不新增界面文字。
  - 出行详情页轨迹：改用位置页同一规格 `CaregiverTrailStyle.lines(coordinates:)`（底层 9 点白边、上层 6 点系统蓝实线），不再设虚线；只改 `RecordsUI.swift` 中的调用处，异常位置标记与取景不变。
  - 测试：更新 `testRecordingCalendarFilteringExpansionAndDetailReturn`（选日期改为整周）和 `testSampleRecordsStayConsistentAcrossPages`（周起始改为周一）；新增指标卡并排与同排等高（390、402 点宽）、窄屏单列（375 点宽）、详情页轨迹为两条实线的用例。
- 不包含：记录页以外的页面；Data 页记录行、月历尺寸与表头顺序；Trend 大卡片与折线图的布局；月历上所选日期的高亮标记（设计稿没有）；字体、配色与界面文字；后端与真实出行数据；不新增依赖；不改 truth。不改任务 T21 的交付文件（`AMapCanvas.swift`、`LocationUI.swift`、`LocationTests.swift`、`SafeZoneSelectionMap.swift`、`object/ios/README.md`），以免它们的文件指纹失效；README 第 22 行“Data 可切换月份、选日期、切换周次及展开记录”的说明仍然成立，不改。
- 允许修改的位置：`object/ios/SafeOrbit/RecordsUI.swift`；`object/ios/SafeOrbit/RecordsDemoData.swift`（仅一周起始日）；`object/ios/SafeOrbitTests/RecordsTests.swift`；`object/ios/SafeOrbit/Localizable.xcstrings`（仅删去不再使用的“Clear”条目）。队列记录只经工具维护。

## 验收标准与验证方法

| 编号 | 可观察的结果 | 验证方法 | 通过条件 |
|---|---|---|---|
| A1 | 指标卡并排、同排等高 | 新增布局用例：390×844 与 402×874、默认字号，读取四张卡及其数字区与柱状图的位置；iPhone 16e 与 iPhone 16 Pro 模拟器截图对照设计稿 09 | 四张卡的柱状图都在数字右侧且纵向重叠；同排两卡高度差不超过 1 点；“50%”与“▲ +100%”各在一行；截图排布与设计稿 09 一致 |
| A2 | 窄屏与大字号不回退 | 新增 375 点宽默认字号用例；运行现有 `testRecordingLayoutMatrixAndRealScrollReachability`、`testSessionAndRecordsLayoutsAtAllRequiredSizes`、`testCaregiverPageSnapshots` | 375 点宽为单列且每张卡并排；大字号无裁切、无重叠；上述现有用例通过 |
| A3 | 点日期显示整周 | 更新后的 `testRecordingCalendarFilteringExpansionAndDetailReturn`；模拟器点 8 月 26 日、8 月 2 日并截图 | 分别列出 Aug 24 – Aug 30、Jul 27 – Aug 2 这一周的全部出行；没有单日筛选和“Clear”按钮；从详情返回仍是该周 |
| A4 | 一周统一为周一到周日 | 单元测试核对默认周、上一周与下一周、趋势图八周起点 | 默认为 Aug 24 – Aug 30；各周起点均为周一；趋势图标签为 Jul 6 … Aug 24；8 月偏离合计 4 次等跨页数字不变 |
| A5 | 详情页轨迹为带白边的实线 | 单元测试核对详情页地图线条；模拟器打开一次出行详情截图 | 两条线依次为 9 点白线、6 点蓝线，均无虚线；截图为连续实线带细白边 |
| A6 | 全部测试与真机编译 | 在模拟器运行全部 iOS 单元测试与截图测试；以 `-sdk iphoneos`、`CODE_SIGNING_ALLOWED=NO` 构建 | 除已知与本任务无关的 4 个失败用例（`LocationTests.testBoundRoutingAndRefreshRetainsLastLocation` 与 3 个登录用例）外无失败，且这 4 个如实列出；构建成功 |
| A7 | 改动只在授权位置 | `git diff --stat`、`git diff --check`；核对 T21 五个交付文件的指纹；提交时的队列检查 | 仅授权文件；T21 文件指纹与其交付时一致；检查退出码 0 |

验收安排：A1–A7 由执行者代跑，回执附原样命令、退出码与输出摘录，标“未独立验证”；对比截图发给用户查看，不入库。记录页布局在模拟器与真机上相同；详情页轨迹在真机上画在高德底图上，可随 T21 真机复测顺带查看，不作为本任务通过条件。最终由用户验收。
