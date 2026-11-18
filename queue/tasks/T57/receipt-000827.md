# T57 验收补充回执

本轮补录配对 iPhone 14 的安装结果与用户验收结论。交付文件与回执 000825 的指纹一致，沿用其中的真机编译成功、197 项 iOS 测试零失败及暂存检查读数。

- `shasum -a 256 object/ios/SafeOrbit/{AMapCanvas,SafeZoneSelectionMap}.swift` 退出 0，两个文件分别输出 `bd2f5222bfa8bfad0007e73f71ad3e1e536fbf55d0788930f94a37ed51187cbe` 和 `d4711df3bcb330dab577f5f5021e8d0a6dc320564e07678c5e28e4ae9d779c62`。
- 提交 fbfbe84 的签名构建日志 `/private/tmp/safeorbit-fbfbe84-iphone.fqflkk/build.log` 输出 `** BUILD SUCCEEDED **`。同目录的设备安装结果 `install-final.json` 为 `"outcome" : "success"`，安装包为 `org.safeorbit.demo`。安装后查询 `installed-app.json` 返回同一 App。
- 真机产品验收以用户明确回复“验收通过”为依据。用户给出的是总体结论，未提供逐项点测记录。执行者核对了安装记录和工件指纹，未另行独立点测地图缩放或地点交互。
