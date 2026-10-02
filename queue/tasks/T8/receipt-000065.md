# T8 Location 首页与应用内步行导航交付

## 实际完成

- 已绑定家属路由到 Location；未登记手机号、未建立老人档案和未完成绑定仍在原流程。基于 Apple MapKit 绘制老人位置与朝向、轨迹和安全区；底部人物卡显示姓名、Normal、电量、地址、老人档案照片、呼叫和 Navigate。无位置时显示英文空状态；刷新失败保留上次成功快照。
- Location、Agent、Records 共用 294 pt 浮动底栏，后两页为简洁空状态；智能体快捷按钮切到 Agent。头像保持视觉外观但不响应点击，新增安全区按钮只保留外观并禁用。右侧可刷新。SF Symbols 图标按二倍参考尺寸换算，触控区域至少 44 pt。
- Navigate 在 App 内请求家属使用 App 期间定位，以五分钟内有效的老人位置为终点，经 MKDirections 请求步行路线；展示折线、距离、预计时间、文字步骤和结束按钮。拒绝权限、老人位置缺失/过期或路线失败均显示英文原因，不伪造路线。呼叫只有档案国际号码有效才打开系统 tel 链接。中国大陆 WGS-84 到 GCJ-02 在 MapKit 边界换算；服务数据仍为 WGS-84。
- 仅新增前端使用的 `GET /v1/location` JSON 约定和模型，未修改后端；现有服务尚无该接口，正式运行会显示不可用，不注入演示位置。测试数据只在预览/测试中。无新增 npm/Swift 依赖。
- 视觉记录在 object/ios/location-qa.md。截图保存于被忽略的 object/ios/DerivedData/FrontendSnapshots/location-v1/，包括首页、空状态、大字首页、导航成功与错误。参考路径继续为 reference/ui/。

## 验证事实（未独立验证）

最终命令：`xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- -testLanguage en -testRegion US test > /private/tmp/safeorbit-location-final-test.log 2>&1`；退出码 0。原样输出摘录：`Executed 18 tests, with 0 failures (0 unexpected) in 6.995 (7.002) seconds`、`** TEST SUCCEEDED **`。覆盖绑定后首页路由、真实位置请求、刷新失败保留旧值、坐标与过期判断、缺失与过期终点、模拟权限拒绝、路线成功与失败、成功与错误页截图。真实 Apple 路线服务未在测试中调用。

`git diff --check`、`git diff --exit-code -- object/server reference truth` 退出码 0，无输出。`sh object/dev/queue.sh check` 退出码 0，输出 `{"ok": true, "protection": "ready", "seq": 64, "tasks": 8, "protocol": 2}`。这些读数是本执行者自验，不是独立验收。

## 实际限制

当前后端仅有健康检查，登录、绑定及位置接口未实现；因此真实绑定用户与位置数据不能在现有服务上贯通。模拟器截图的地图街道底图只显示方格，图层和控件已出现，但未能核对实际地图瓦片。真机定位、拨号、苹果步行路线、国内坐标是否由具体 MapKit 接口自动转换仍需后续验证；持续语音、自动推进与偏离重算属于后续版本。T7 共用文件已在 T7 重交记录中更新指纹；本件尚待用户验收。本轮未暂存、未提交、未推送。
