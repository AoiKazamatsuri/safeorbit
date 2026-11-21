# T60 家属首页英文路名与两条模拟器录屏

家属首页按老人最近一次有效定位显示英文道路名。接口给出短路名时使用该字段，兼容只带单一道路名的旧地址。仅有位置时，根据设备已有的地图服务查找道路，英文界面保留已有英文拼写或将中文道路专名及路型转写为英文。在高德道路几何相近且异名、未取得路名或定位过期的情况下，家属卡隐藏该行。移动到新位置时丢弃旧查询，同一位置的短时失败会重试。家属聊天的既有本地过滤可识别首页显示的路名。安全区编辑仍通过原接口取完整地址。

按用户指定顺序先在聊天提供两条英文路名成片及原速录屏，再完成正式 App 的英文路名修改。正常路线沿既有高德步行几何从建良楼到陶园南楼，全长约 1.10 公里。徘徊视频沿同一条汉口路折返，并展示模拟经过 7 分钟的警告及 15 分钟的高风险通知，最后打开同一事件的详情。所有媒体保存在本次聊天本机素材目录。

## 本机验证（未独立验证）

- **V1** 全套正式 iOS 模拟器测试，原样命令 `env -u SAFEORBIT_ONLY_TESTING SAFEORBIT_SIMULATOR_ID=9B8F63B0-C8CC-42FF-8F81-36790B95DD4C sh object/dev/ios-check.sh`。退出 0，输出 `Executed 212 tests, with 0 failures (0 unexpected) in 626.422 (626.485) seconds` 和 `** TEST SUCCEEDED **`。
- **V2** 真机构建，原样命令 `xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Release -sdk iphoneos -destination generic/platform=iOS -derivedDataPath /private/tmp/safeorbit-wander-1121/DeviceBuild CODE_SIGNING_ALLOWED=NO build`。退出 0，末行输出 `** BUILD SUCCEEDED **`。
- **V3** 单独的模拟器界面测试使用省略 `address`、`streetName` 的两次家属实时定位。普通 Debug App 的家属卡控件读数为 `STREET_RESULT raw=[Hankou Road] exact_hankou=true elapsed=0.5s`，`xcodebuild test-without-building` 退出 0，`Executed 1 test, with 0 failures`。另在本机核对八个公共路线点的英文结果，区分路名、校区名称和完整门牌。
- **V4** 正常成片 36 秒，徘徊成片 43 秒，两个剪辑版本均为 1486×2814、30 帧每秒。两段原始素材为 1206×2622。四个视频均经 `ffmpeg -xerror` 完整解码（退出 0），两份原速 MP4 中的 H.264 视频流与模拟器原始 MOV 的摘要一致。自动化操作从卡片读出 Hankou Road、Warning、High Risk 和 Wandering for 15 minutes。对比同一段 5.5–21.1 秒的剪辑，蓝点最长近停由 1.40 秒降为 0.27 秒，仍可识别五次折返。为压缩时间后的画面平滑，录像在本机按约 160 毫秒轮询相邻路线点的连续位置，剪辑仅对其中 6.2–20.9 秒内蓝点作局部时间平滑，原始录屏保留原画面；正式 App 的三秒轮询及实际风险门槛维持原设计。
- **V5** `git diff --check` 退出 0，无输出。

子代理分别完成回放服务、路名解析、两台模拟器的录制操作、后期逐帧蓝点测量、测试用例和普通 Debug 家属卡的现场核对。通知在专用模拟器上通过本机模拟推送展示。此次未实地走查手机上的高德在线查询；模拟路径、时间及通知不能作为一次真实出行记录或真机推送的证据。用户尚未作产品验收。
