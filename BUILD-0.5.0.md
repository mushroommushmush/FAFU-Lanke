# 0.5.0 当前交付状态

- 应用功能源码提交：77aee9a1a1b8e9c2cb1c8d689de58f4ccd6fea96。
- 构建环境提交：70edc1ba228509a3dd3f6e4bdf2f81265956265c。
- 云端验证：https://github.com/mushroommushmush/FAFU-Lanke/actions/runs/41490906524
- 当前build和layout任务均为queued，尚未执行测试或编译；没有新版IPA。旧macOS15队列长时间未分配机器，已改用macOS26、保持Xcode26.3。
- 本地1241项项目结构检查通过；新增5项专业课表测试尚未执行。不能声称50项测试通过。
- 没有使用真实教务账号验证六级选项、实际HTML及表单回传，没有实体设备交互或截图验证。
- 安装前必须等待构建成功；如失败，需读取日志并修复源码。
