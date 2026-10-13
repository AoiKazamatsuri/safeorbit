# 家属首页地图可见区域居中与比例尺回执

未独立验证。家属首页从实际地图边界和老人信息卡片顶部求可见区域中心，老人位置在该中心；地图初始纵横范围分别按视口高度和宽度乘参考米/点计算，避免竖屏被地图 SDK 自动扩展纵向跨度。回到默认视图复用同一区域。家属导航仍以家属蓝点为中心、路线朝上；老人端、安全区、Set Home、Recording 及 T15 未改。只修改 AMapCanvas.swift、LocationUI.swift、LocationTests.swift，新增截图与证据见 `object/ios/Verification/T14/home-map-scale/observations.md`。无新增依赖或资料改动。

402×874 MapKit 模拟器截图 `object/ios/Verification/T14/home-map-scale/caregiver-home-402x874.png` 约 0.33 逻辑点中心误差；高德 iPhone 18 Pro 真机物理比例尺仍未实测。完整 86 项 iOS 测试、Release 构建、队列检查及 git diff --check 退出码均为 0，原样命令与输出摘录在 observations.md。用户此前已有的 Localizable.xcstrings 工作区改动未纳入本轮。没有提交、推送或记录用户验收。
