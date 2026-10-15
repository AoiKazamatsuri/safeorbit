# T20 交付回执

`LocationPreviewData` 的示例轨迹由 7 个手放的点换成苹果地图步行路线的几何点：沿北京西路向东，在路口右转进宁海路，再进入南京大学一侧到老人位置。首尾保留原坐标，“Campus”安全区中心与老人当前位置因此不变；中间 9 个点全部取自路线返回值。注释写明来源、坐标系与取数日期。只改 `object/ios/SafeOrbit/LocationModels.swift`，未改测试，无新增依赖。验证由执行者完成，未独立验证，尚未由用户验收。

## 取数（经用户同意联网一次）

一次性脚本放在会话临时目录（不入库），以原示例起点 (32.0600471, 118.7665265) 与终点 (32.0564731, 118.7718559) 为两端，用 MapKit `MKDirections` 请求步行路线，打印路线概况与全部折点：

```sh
swift fetch_route.swift
```

退出码 0，原样输出：

```text
routes=1 points=10 distance=703m time=699s
start->first=3.2m last->end=24.7m
step: Start on Beijing West Road
step: Take a right onto Ninghai Road
step: Take a slight left turn
step: The destination is on your right
32.0600752,118.7665327
32.0596075,118.7695238
32.0595431,118.7700819
32.0595270,118.7701677
32.0594706,118.7701946
32.0576495,118.7709991
32.0568178,118.7713961
32.0567159,118.7715947
32.0566731,118.7717071
32.0566797,118.7717591
```

路线起点距原起点 3.2 米，说明路线与原示例同在 MapKit（国内为 GCJ-02）坐标系，没有整体偏移。写入时第 1 个折点换成原起点（相差 3.2 米），其后接第 2–10 个折点，最后接原终点（距路线末点 24.7 米，即进入校园的一段）。

## 验证

A1：在模拟器里打开 Debug 版位置页，放大到街区级别（比例尺约 125/250 英尺）截图核对：轨迹压在北京西路上，在路口右转后沿宁海路走，路名标注就在轨迹线上，转角处不再斜穿；最后一小段离开宁海路进入校园到老人位置。默认比例下的截图测试 `location-normal.png` 同样显示轨迹在宁海路上。

A2：新旧起点、终点用球面距离计算，原样输出 `start moved 0.0 m, end moved 0.0 m`。

A3：全部测试见 T19 回执同一次运行（三件改动合并后）：`Executed 96 tests, with 2 tests skipped and 12 failures (1 unexpected)`，退出码 65；失败的 4 个用例都与登录和钥匙串有关，在未改动的提交 93fba58 上同样失败，与本改动无关。`LocationTests.testCaregiverTrailUsesTheSameVisibleStyleForBothMapBackends` 等使用示例轨迹的用例全部通过。高德 SDK 的恢复见 T19 回执，属于项目已有依赖。

A4：

```sh
git diff --check
```

退出码 0，输出为空。

## 未覆盖

真机高德底图上的效果未看，由用户安排复看。Recording 等其他页面的示例轨迹不在本任务内，未改。
