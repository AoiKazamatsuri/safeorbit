# 地图与导航修复核对

未独立验证。基准为 iPhone 18 Pro 的 402×874 逻辑点。

- `elder-navigation-402x874.png`：顶部指引卡与家属导航同顶距；底部 Cancel、Call Family 两枚按钮均为 56 点高，与老人首页按钮一致。截图来自样例前端，不能证明高德真机路线。
- `caregiver-navigation-402x874.png`：现有家属指引卡、绿色统计胶囊、右侧按钮及路线标记未被本轮改动挤压。截图中的路线是明确标注的演示路线。
- `caregiver-home-393x852.png`：家属底栏 Location 图标显示为人物与定位箭头组合，出行轨迹在 MapKit 展示回退中加粗。原生高德的线宽仍需真机核对。
- `safe-zone-editor-402x874.png`：地图从南京所选地点打开，Create Safe Zone 在同一行完整显示。`safe-zone-editor-393x852.png` 核对较窄尺寸。模拟器使用 MapKit 展示回退；白色提示说明高德 SDK 需要物理 iPhone，此图不能证明原生高德标识位置。
- `role-selection-402x874.png`：应用在模拟器可启动并显示角色选择。此图不是地图页面验收证据。

真机设备列表中 iPhone 14 状态为 `unavailable`。高德鉴权、GPS 实际读数、路线请求结果、原生高德线宽与标识位置本轮未能在物理设备上实测；待设备可用时复核。代码将高德错误按配置、网络、超时、无有效路线分类，并只在 SDK 返回有效路线几何时显示导航。
