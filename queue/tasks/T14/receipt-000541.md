# 老人当前位置蓝点扇形回执

未独立验证。按用户指令，老人首页当前位置箭头改为与家属首页完全相同的蓝色圆点及渐变扇形，直接复用 CurrentLocationDot。仅改 ElderHomeUI.swift 和 LocationUI.swift 的组件可见性，保留位置、既有方向回退和无障碍标签；地图旋转时扣除相机方向。家属样式定义保持，未新增依赖。四尺寸老人首页及导航截图见 object/ios/Verification/T14/elder-location-dot；标准尺寸和小屏大字截图已目检。

原样验证命令与输出见 object/ios/Verification/T14/elder-location-dot/observations.md。完整 iOS 测试退出码0，原样输出：Executed 86 tests, with 0 failures (0 unexpected) in 154.709 (154.739) seconds；** TEST SUCCEEDED **。Release 构建退出码0，原样输出：** BUILD SUCCEEDED **。git diff --check 退出码0，无输出。模拟器截图使用现有样例位置，未实测高德真机定位及方向；既有真机验证余项保留。共享交付仅更新文件指纹，不构成用户验收。不提交或推送。


```sh
/Users/idesign/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3 tool/shell.py check
# 退出码 0
```

```text
{"ok": true, "protection": "ready", "seq": 540, "tasks": 15, "protocol": 2}
```
