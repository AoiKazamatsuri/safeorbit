# T8 导航共享工件重交

用户要求实施T13首页全屏地图实时步行导航。共享LocationUI、LocationTests及README按T13范围更新，原T8业务要求、前一份回执None的实现事实和限制保持；本次只重验共享指纹，不把导航扩展冒充原任务范围，也不自动验收。账号继续冻结直接首页，原设置、安全区、Agent和Records保持。无新增依赖、后端、truth/reference或推送。

执行者自验，未独立验证。最终完整测试46项与Release退出码均0，原样命令及输出摘录见同批T13导航交付回执；测试输出Executed 46 tests, with 0 failures (0 unexpected) in 56.816 (56.848) seconds、** TEST SUCCEEDED **，Release输出** BUILD SUCCEEDED **。git diff --check和后端/truth/reference范围检查退出码0，无输出。原真机地图、真实语音、账号及绑定等限制不变。共享截图和实际模拟GPS路线验证由T13记录。队列暂存检查与正常提交钩子随本批执行，用户验收单独记录。
