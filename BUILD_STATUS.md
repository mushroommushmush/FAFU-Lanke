# 0.3.0 验证结果

- 39项核心测试、模拟器编译、iPhone/iPad归档、IPA上传已通过。
- 安装包构建：https://github.com/mushroommushmush/FAFU-Lanke/actions/runs/41202594594 （build任务成功，旧layout任务因模拟器数据迁移失败，不能将整体状态称为全绿）
- 最终设计预览：https://github.com/mushroommushmush/FAFU-Lanke/actions/runs/41204807982 （成功）
- 已检查真实模拟器运行生成的应用内组件视图预览，使用示例数据；小号、中号无裁切。
- 已解析生成IPA的Mach-O签名，确认主应用与扩展包含同一个课程共享组，且扩展未获登录私有组。
- 尚未验证：SpringBoard组件实际添加、真实数据跨进程共享、Sideloadly重签后的权限保留。预览截图与临时ad-hoc签名不等于设备签名验证。
- 最新应用功能源码对应3f740c9ac324403274ef0b9ce117e5820d8a31ef，后续提交仅修复截图流程及文档。
