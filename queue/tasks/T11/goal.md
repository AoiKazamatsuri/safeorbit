# 修复变量与麦克风权限接口编译警告

## 范围

- 要交付：magic 改为 let；录音权限请求改为 iOS 17 起的 AVAudioApplication 接口，保持原回调及拒绝处理。保持当前直接首页入口及所有业务行为。
- 不包含：新增功能、后端、真机录音验证、账号或证书操作、truth/reference 改动、推送。
- 允许修改的位置：object/ios/SafeOrbit/LocationModels.swift、object/ios/SafeOrbit/SpeechInput.swift。队列记录经工具维护。T10 共享 LocationModels 工件变更后返工重交指纹，不改变验收范围。

## 验收标准与验证方法

| 编号 | 可观察结果 | 验证方法 | 通过条件 |
|---|---|---|---|
| A1 | 两处警告消失 | 完整模拟器测试构建、Release 构建及日志核对 | 无 magic 未修改或 requestRecordPermission 弃用警告 |
| A2 | 现有功能保持 | 既有完整 iOS 测试 | 无测试失败 |

验收安排：执行者代跑并标未独立验证，用户最终验收。
