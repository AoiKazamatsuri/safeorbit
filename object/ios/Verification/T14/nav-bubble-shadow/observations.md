# 气泡阴影与侧栏圆角核对

未独立验证。完整82项iOS测试0失败，Release及队列/临时索引检查均退出码0。两处源码修复：LocationUI.swift中的老人导航气泡去掉可见姓名、圆形与尖角以单一白色轮廓绘制背景阴影；CaregiverChrome.swift将侧栏背景和内容一起裁切，合成后对整体不透明轮廓绘制外侧阴影，右上/右下36点。

家属与老人侧栏402×874、393×852、375×812及320×568大字号截图保存在本目录。右上角不再呈直角，头像信息卡保持胶囊形状，入口及底部Log Out保留。实际模拟器native-sidebar-before/after显示修复前直角与修复后圆弧；Caregiver→打开设置→Log Out→身份选择→重新Caregiver路径实点通过。

navigation-markers-combined/separated/rotated/missing-route截图显示气泡没有可见姓名，黑色箭头清晰、圆形和尖角阴影连贯；组合气泡下方连接线与终点圆点可见，分离、90度旋转及缺路线状态也保持。原坐标测试继续通过。原生Navigate→Route overview实点通过，native-navigation-overview.png用于核对实际预览。屏幕阅读器保留已有标记名称描述，未移除资料姓名。

小屏大字号沿用既有滚动布局；本轮refined-navigation-small-scrolled.png由测试滚动到末端，非原生手势证据。高德真机鉴权、GPS、实际道路路线及此前地图拖动手势余项保留。无新增依赖、接口或资料结构变更，不提交推送或用户验收。

原样截图命令，退出码均0：
```sh
xcrun simctl io DFC762F4-52D3-4703-8AFF-7625E0843313 screenshot /tmp/sidebar-corner-before.png
xcrun simctl io DFC762F4-52D3-4703-8AFF-7625E0843313 screenshot object/ios/Verification/T14/nav-bubble-shadow/native-sidebar-after.png
xcrun simctl io DFC762F4-52D3-4703-8AFF-7625E0843313 screenshot object/ios/Verification/T14/nav-bubble-shadow/native-navigation-overview.png
```

原样输出摘录：`Detected file type from extension: PNG`。
