# AGENTS.md — 企划星 · 桌面日历清单（Flutter 桌面端）

本文件是编码代理的项目约束单一入口（[agents.md](https://agents.md/) 规范）。
人类向的项目介绍、功能对照与架构细节见 `README.md`；本文件只写代理干活必须遵守的
规则、命令与边界。`.agents/skills/` 下的 uf_* 技能均把项目口径委托给本文件，
冲突时以本文件为准。

## 1. 项目概览

- Flutter 桌面端重写版（Windows 为主，保留 macOS/Linux/Web 工程），
  **Clean DDD + 六边形架构 + Riverpod 3 + go_router**。
- 完全复用 `packages/infras/core`（纯 Dart 内核）与
  `packages/infras/core_design_system`（三层设计令牌），
  **不引入第二套颜色、字号、图标或状态管理方案**。
- 旧版解包参考在 `.archive/`（只读，勿改、勿提交其中产物）。

## 2. 环境与命令

- **SDK**：Flutter 3.50.0 / Dart 3.14.0，本机位于
  `D:\devEnv\myflutter\flutter_windows_3.50.0-stable`
  （已写入 `.vscode/settings.json` 的 `dart.flutterSdkPath`）。
  若 PATH 中的 `flutter` 不是该版本，一律用上述完整路径调用。
- **Pub Workspace**：`packages/infras/core`、`packages/infras/core_design_system`
  由根工程统一解析，**禁止在子包目录单独 `pub get`**。

| 目的 | 命令（仓库根目录） |
|---|---|
| 解析依赖 | `flutter pub get` |
| 开发调试 | `flutter run -d windows` |
| 静态分析 | `flutter analyze` |
| 根工程测试 | `flutter test` |
| core 纯 Dart 测试 | `cd packages/infras/core && dart test` |
| 设计系统测试 | `cd packages/infras/core_design_system && flutter test` |
| Windows 构建 | `flutter build windows --debug`（发布用 `--release`） |
| 本机安装/卸载 | `windows/installer/install.ps1` / `uninstall.ps1`（改 HKCU 与系统壁纸，**先经用户确认**） |
| 桌面层自检 | `powershell -File windows/installer/verify_desktop_widget.ps1` |

## 3. 目录归属与依赖方向（Clean DDD，硬规则）

```
Presentation  lib/app, lib/features/*/presentation, lib/shared   ← 只读 Riverpod
Application   lib/features/*/application                         ← Notifier / 用例
Domain        lib/features/*/domain, lib/core                    ← 纯 Dart 聚合/值对象/端口
Infrastructure lib/features/*/infrastructure, lib/infrastructure ← 适配器 / DTO
```

- 依赖方向：Presentation → Application → Domain ← Infrastructure。
  **Domain 不依赖 Flutter 与任何插件**；写侧不直接调用读侧。
- Flutter 插件只允许出现在 `lib/infrastructure` 与 `lib/bootstrap`；
  端口声明集中在 `lib/core/ports.dart`，组合根 `lib/bootstrap/bootstrap.dart`
  创建适配器并以 `overrideWithValue` 注入。
- 新能力按限界上下文落位 `lib/features/<ctx>/{domain,application,infrastructure,presentation}`，
  不按技术形态平铺；跨上下文共享原语放 `lib/core`。
- `packages/infras/core`：零 Flutter 依赖（Result / 领域原语 / 存储端口 /
  配置 / 日志 / 网络 / 缓存 / 上传），改动必须能过 `dart test`。
- `packages/infras/core_design_system`：原始色板 → 语义槽 → 组件令牌 +
  `AppTheme` / `AppTypography`，是全部颜色与字体的唯一来源。
- 改依赖方向、目录结构、公共端口契约、存储格式前**先问用户**。

## 4. 状态管理（Riverpod 3）

- 端口 Provider 声明在 `lib/bootstrap/core_providers.dart`；
  用例用 `Notifier`，纯函数读模型用 `Provider`（如 `monthDataProvider`）。
- UI 只读状态、经 Notifier 用例写入；路由用 `routerProvider`（go_router
  `StatefulShellRoute`，隐藏页面保留分支与路由，仅注释导航入口）。
- 聚合**不可变**：`changed()` 返回新实例并 `raiseDomainEvent()`；
  仓储在落盘成功后才 `pullDomainEvents()` 分发（先落盘后发事件）。
- 异常经 `guardAsync` 收敛为 `Result`；`ApiClient` 永不抛异常，离线降级本地。

## 5. 桌面插件 API 约定（硬规则）

- `window_manager 0.7` / `tray_manager 0.9` / `screen_retriever 0.4`
  均已基于 nativeapi 重写。窗口、托盘、屏幕信息功能**统一使用三个包主入口
  公开的新 API**：

  ```dart
  import 'package:screen_retriever/screen_retriever.dart';
  import 'package:tray_manager/tray_manager.dart';
  import 'package:window_manager/window_manager.dart';
  ```

  **不用 `legacy.dart` 兼容桥，不直接调 nativeapi 底层**；仅当三个包未导出
  所需符号时才退回 nativeapi（当前仅 `Application.quit` 兜底退出一处），
  并在代码注释说明原因。
- **win32 版本互斥**：`launch_at_startup` 依赖 win32_registry 2.x（win32 5），
  因此 `file_picker` 保持 11.x、`flutter_secure_storage` 保持 10.x；
  不得单独升级到要求 win32 6 的新主版本。
- `test` 受 SDK flutter_test 钉扎（test_api 0.7.14）限制，最高 1.32.0。
- 托盘图标必须是 `.ico`（Windows `LoadImage` 只认 ICO，PNG 得 NULL HICON）；
  Windows 原生层不自动弹右键菜单，需监听托盘点击后 `openContextMenu()`
  （左键/右键都弹，见 `TrayManagerGateway`）。
- 主窗口拦截原生关闭（`WindowCloseRequestedEvent.request.cancel()`）隐藏到托盘；
  `WindowGateway.destroy()` 是唯一真正退出路径。
- 跨 engine 数据同步走原生 **DataHub**（MethodChannel/EventChannel）；
  **禁止用 `SharedPreferences.reload()`**（Windows 实现只读 isolate 缓存）。
- 优先使用 Pigeon 跨 engine与平台 进行数据同步，不直接调用 MethodChannel/EventChannel。

## 6. 编码约定

- 颜色/字体走设计令牌（`context.appColors`、`AppTypography`），不硬编码第二套。
- 业务 widget 统一 import `package:material_ui/material_ui.dart`，**不用已弃用的
  `package:flutter/material.dart` / `cupertino.dart`**（Flutter 3.50 解耦设计库，ADR-0009）。
- 图标统一 `lucide_icons_flutter`，不用 Material Icons
  （`uses-material-design` 仅供 DatePicker 等内置控件内部图标）。
- 注释与文档用中文；默认不写注释，只写非显而易见的 WHY（约束/不变量/陷阱）。
- 单一真实源：不复制第二份实现；生成文件改模板/生成器，不手改成品。
- 未实现的能力显式登记为缺口，**禁止用占位实现伪装完成**。
- 提交前对改动文件执行 `dart format`；分析门禁收紧为 `dart analyze --fatal-infos`
  0 告警（对齐 `.agents/dart-editing.md`；ADR-0009 清零弃用 info 后启用），
  `flutter analyze` 保持 0 error / 0 warning（flutter_lints 6）。

## 7. 测试与验证标准

- 测试位置：根 `test/`；`packages/infras/core/test/`（8 个子目录）；
  `packages/infras/core_design_system/test/theme_test.dart`。
- 修 bug 先写**能红**的回归用例，确认失败指向根因，再做最小修复（uf_fixbug）。
- 不得靠放宽断言、排除项或白名单「变绿」。
- 验证矩阵（按改动类别选）：
  - 纯 Dart / 领域 / 应用层：`flutter analyze` + 受影响测试全绿。
  - 插件 / 原生 / 启动链：追加 `flutter build windows --debug` 通过，
    并做运行时冒烟（启动 exe → 用 `tasklist` 核实进程存活 → 清理测试进程；
    Git Bash 的 `kill -0` 对分离的 GUI 进程会误报，以 tasklist 为准）。
  - 桌面 overlay / 命中区域：`verify_desktop_widget.ps1` 自检并附输出。

## 8. 工作流与决策记录

- 技能入口（`.agents/skills/`）：日常开发 `uf_coding`（Plan → Implement →
  自测 → 交接）；只读审查 `uf_findbug`（结论必须带 `文件:行号` + 验证手段）；
  缺陷修复 `uf_fixbug`；提交 `uf_commit`。
- 架构 / 契约 / 流程决策落 `docs/ADR/`，按 `ADR-NNNN.md` 模板编号递增：
  状态 / 分类（SEC|CFG|DEF|ARC|DEP|DEBT|TST）/ 优先级 / 背景证据 / 决策 /
  后果 / 验证 / 关联；**提交后回填真实 commit 号**。
- 文档入口：`README.md`（架构与功能对照）、`docs/cross-engine-sync-analysis.md`
  （跨 engine 同步）、`docs/ADR/`。

## 9. 提交规范

- Conventional Commits：`<type>(<scope>): <中文祈使句摘要>`，首行 ≤72 字符、
  句末无句号；type 用 feat/fix/docs/style/refactor/perf/test/build/ci/chore/revert；
  scope 用模块名（calendar / history / notes / audit / ui 等），
  风格参照 `git log --oneline -10`。
- 提交前必须通过：`flutter analyze` + 受影响范围测试。
- 显式路径 `git add -- <path>`，**严禁 `git add -A` / `git add .`**；
  暂存后用 `git diff --staged --name-only` 复核；不提交敏感文件。
- 不改 Git 配置；未经用户明确要求不 push、不 force push、不改写历史、
  不 `--amend`、不 `--no-verify`。

## 10. 安全边界与已知缺口

- `.archive/` 只读；`assets/config/default_config.json` 的 `apiBaseUrl`
  是占位符，接真实服务前不要假设云端可用。
- 安装/卸载脚本会写 HKCU、改系统壁纸、停旧实例——运行前经用户确认。
- 已声明**尚未接线**的依赖（不要假设其功能已存在）：
  `hotkey_manager`（设置里 4 个热键开关仍是空壳）、
  `drift_flutter`（尚未建表接入存储层）、
  `flutter_app_packager`（打包流程未配置）。
- `auto_updater` 已从 pubspec 摘除（ADR-0012）：其 Windows 实现是进程级单例，
  子 engine 注册即 abort。恢复该依赖前必须先保证只注册在主 engine。
- `pigeon` 已落地：DataHub 跨 engine 通道代码已生成
  （`lib/infrastructure/generated/data_hub.g.dart`、
  `windows/runner/generated/data_hub.g.{h,cpp}`，ADR-0007），改通道契约要改
  pigeon 定义并重新生成，不手改成品。
- 课程表 / 订阅入口暂时隐藏，路由与模块代码保留，恢复方式见 README。