# 家属导航核对记录

未独立验证。最终完整82项iOS测试0失败、Release构建退出码0。仅LocationUI.swift与LocationTests.swift为本轮源码修改；无依赖、导航数据接口或老人顶部卡变更。

402×874、393×852、375×812标准截图测量：叉号可见左边缘、末项绿色数值可见右边缘分别距胶囊36点，三份测量均36/36；圆形按钮图标黑色，阴影只在白色Circle背景。顶部卡片402/393为82点，375因文字换行为100点，语音圆形中心与卡片中心偏差约0.17点；新增高度按自然高度20%保持，上下各分10%。卡片上缘、宽度、字号及圆角保持。数据见measurements.json。

320×568大字号初始视口不能同时显示整个导航界面，已有ScrollView。测试定位其纵向UIScrollView并滚动至末端，refined-navigation-small-scrolled.png中三项统计、说明和叉号均完整显示，不缩字体。该证据为测试直接改变滚动位置，未实测该尺寸原生手势。375大字沿用同一布局。

标记截图navigation-markers-combined/separated/rotated/missing-route覆盖同坐标组合、不同坐标、相机90度及缺路线；终点圆点可见，气泡箭头始终朝屏幕上方；坐标测试覆盖末尾无效坐标、缺老人。两套地图共用AMapMarker视觉内容。本轮运行截图为MapKit展示回退；不能证明真机高德鉴权、GPS和实际路线。

模拟器原生操作：Caregiver→Navigate进入导航；Route overview显示姓名、气泡及终点；Back to my location恢复蓝点居中、前进路线朝上；Mute guidance切为Unmute guidance，再点恢复Mute guidance；叉号显示Exit navigation/Cancel，Cancel恢复统计并保留导航，再次确认Exit navigation返回Location首页。截图native-follow、native-overview、native-exit-confirmation。语音真实听感未独立核对，模型回归测试覆盖静音与退出停止。

原样截图命令，退出码均0：
```sh
xcrun simctl io DFC762F4-52D3-4703-8AFF-7625E0843313 screenshot object/ios/Verification/T14/nav-marker-layout/native-follow.png
xcrun simctl io DFC762F4-52D3-4703-8AFF-7625E0843313 screenshot object/ios/Verification/T14/nav-marker-layout/native-overview.png
xcrun simctl io DFC762F4-52D3-4703-8AFF-7625E0843313 screenshot object/ios/Verification/T14/nav-marker-layout/native-exit-confirmation.png
```

原样输出摘录：`Detected file type from extension: PNG`。此前高德真机及地图拖动手势余项保留，未提交、推送或记录用户验收。
