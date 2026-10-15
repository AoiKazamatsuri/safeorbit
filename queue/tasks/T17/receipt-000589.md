# T17 实机补充验证回执

用户连接并解锁iPhone 14后，明确要求验证此前的地图问题，并要求继续。沿用同一排查任务返工补充实机证据；原批准允许的业务正本未扩大：只更新object/ios/Verification/map-initial-camera-20261015.md，使用临时脚本、日志和截图，没有修改或重装App。

## 实际结果

直接在已安装的SafeOrbit 0.1.0（1）、org.safeorbit.demo上调试。用户手动选择Caregiver、打开安全区、返回首页，执行者负责断点、读取、临时对照与截图。两个页面均实机复现全国范围。

| 页面 | 视图尺寸pt | 原版zoomLevel | 原版米/点 | 加载后重发原请求的zoomLevel | 重发后米/点 |
|---|---|---|---|---|---|
| 首页 | 390×844 | 3.256875277 | 17566.836479 | 14.348878860 | 6.605546 |
| 新增安全区 | 390×750 | 3.459919691 | 15520.439807 | 13.406385422 | 12.750843 |

首页原请求纬/经跨度0.050509762/0.027406117度；安全区0.044884267/0.052704072度。以只读寄存器断点保留最初的完整region，待页面显示后，对同一地图实例重新调用完全相同的setRegion:animated:NO，两个成功返回1，继续运行后尺度保持表中结果。安全区截图显示街区、范围圆和图钉，返回首页后的截图显示街区和原标记。截图均为App窗口直接绘制、未编辑的原图。

验证支持首次应用范围的时机有问题，且应用层缓存了已经处理、没有再补设。没有直接测量SDK内部阶段，不能精确声称是某一个内部初始化回调之前发生的错误。安全区重发后仍比首页尺度大1.9303倍，与750/390的竖屏比1.9231吻合，进一步支持还需修正安全区正方形地面范围。没有把临时正确显示称为代码修复。

完整说明、调用命令、原样读数与失败限制均已更新到报告。原始脚本与日志：/private/tmp/safeorbit_map_probe.py、/private/tmp/safeorbit-map-live-metrics.jsonl。已实际查看四张证据图：safeorbit-map-live-home-first.png、safeorbit-map-zone-first.png、safeorbit-map-zone-after-control.png、safeorbit-map-home-after-control.png，均在/private/tmp下。

## 执行与检查

原样使用的命令除个人设备标识以环境变量表示外，保留调用形式：

```sh
xcrun devicectl device info apps --device "$SAFEORBIT_DEVICE" --filter 'bundleIdentifier CONTAINS "safeorbit"'
xcrun devicectl device process launch --device "$SAFEORBIT_DEVICE" --terminate-existing --start-stopped org.safeorbit.demo
xcrun lldb
xcrun devicectl device copy from --device "$SAFEORBIT_DEVICE" --source tmp/safeorbit-map-zone-first.png --domain-type appDataContainer --domain-identifier org.safeorbit.demo --destination /private/tmp/safeorbit-map-zone-first.png
```

以上均退出码0。原样输出摘录：

```text
SafeOrbit   org.safeorbit.demo   0.1.0     1
Launched application with org.safeorbit.demo bundle identifier.
File received from Device
Process 16277 detached
```

LLDB成功采集的原样输出摘要（只摘录尺度字段）：

```text
zoom=3.256875276565552 metersPerPoint=17566.83647912258
zoom=3.459919691085815 metersPerPoint=15520.43980688825
zoom=14.34887886047363 metersPerPoint=6.605546350171932
zoom=13.40638542175293 metersPerPoint=12.75084264532981
```

一次审批服务用量错误在用户要求继续后经正常审批重试成功；没有绕过审批。早期表达式编译错误、一次采集过程的SIGKILL终止和被自身断点打断的重发尝试均未当作成功结果；详情及原始日志保留在报告。重启后轻量采集稳定复现，关闭断点并退出未完成表达式后才成功完成同参对照。没有把调试时终止判为产品崩溃。

```sh
git diff --check
git diff --name-only HEAD -- object/ios/SafeOrbit object/ios/SafeOrbitTests
sh object/dev/queue.sh check > /private/tmp/safeorbit-map-live-queue-check.json
```

以上均退出码0。前两条原样输出为空，队列原样输出：

```json
{"ok": true, "protection": "ready", "seq": 588, "tasks": 17, "protocol": 2}
```

无业务代码变更，本轮未重复运行不能覆盖真实高德初始化的模拟器计算测试。没有新增依赖、构建、签名、安装、账号或密钥配置、保存安全区、推送或发布。结束时process detach并退出LLDB，App继续运行；当前地图正确仅来自临时对照。

## 验证边界与后续

执行者自验，未独立验证。只完成用户要求的两页首次范围复现及同参时机对照，未覆盖老人首页、全新同意、网络恢复、全部手势和半径矩阵；不代用户通过任务。建议后续实施同时修正两个Coordinator的就绪协调、未完成请求补设和手势保护，以及安全区按实际视图宽高计算比例，并补充相应回归测试。
