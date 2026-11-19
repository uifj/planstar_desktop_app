# ADR 索引 — 大规模重构与性能优化方案（2026-11-18）

来源：`docs/arch_optimize.txt` 全量审计。所有论断已逐条对照代码核实
（含行号修正），并结合 Flutter 3.50 / Dart 3.14 官方能力公告与当前依赖
解析版本（pubspec.lock）确认可行边界。模板见 `ADR-NNNN.md`。
实施进度：0001 / 0002（子项 1–7 全部）/ 0003 / 0004 / 0005 / 0006（步骤1–4
已运行时验证；步骤5 桌面拆分已实施+静态验证，overlay 运行时回归受子 engine
启动环境故障阻塞，待健康启动补做）/ 0007 / 0009 / 0010 已实施
待提交；0008 经评估尊重其自身决策门禁、B 暂缓（C 基线已由 0002 落地，
保持 PROPOSED，不写存储代码）。涉及依赖方向/目录结构/公共契约/存储格式的项
（0003/0004/0007/0008）实施前按 AGENTS.md §3 先经用户确认（0003/0004/0007
已获「全部进行实施」确认并落地；0008 用户确认暂缓 B）。

## 路线图（按实施顺序）

| 顺序 | ADR | 主题 | 分类 | 优先级 | 依赖 |
|---|---|---|---|---|---|
| 1 | [ADR-0001](ADR-0001.md) | 重复规则展开反转 + happensOn 补 count + metaOf 缓存 + 删 yi/ji + lunarYearly 外提 | DEBT | P0 | 无（对拍测试先行） |
| 2 | [ADR-0002](ADR-0002.md) | 写路径增量化：JsonListStore 缓存 / saveEvents 批量 / Result 异步组合子 / cells Map / 增量 load / 存储原语统一 / 删 SharedPreferencesStore | DEBT | P1 | 子项 4/5 与 0004 同批 |
| 3 | [ADR-0003](ADR-0003.md) | core/ports.dart 按域拆分 + 键名注册反转 + SoundTone 去 asset 化 | ARC | P1 | 无（越晚越贵，宜早） |
| 4 | [ADR-0004](ADR-0004.md) | TimelineContributor 聚合上移 + calendar 读模型拆层 + copyWith 单开关 | ARC | P1 | 与 0001/0002 同批开刀 |
| 4.1 | [ADR-0010](ADR-0010.md) | 子 engine 插件注册子集（auto_updater 单例 abort）+ runner /utf-8；Intel 驱动间歇 AV 登记为环境风险 | DEF | P0 | 0004 同批冒烟门禁 |
| 5 | [ADR-0007](ADR-0007.md) | DataHub 通道 Pigeon 化（Windows 平台通道模式，非 interop preview） | ARC | P1 | 与 0003 的注册表分发同批评审 |
| 6 | [ADR-0009](ADR-0009.md) | material_ui 迁移，清零 53 条弃用 info，门禁收紧 --fatal-infos | DEBT | P2 | 在 0006 大改 presentation 前 |
| 7 | [ADR-0005](ADR-0005.md) | TaskCompleted 事件 + SoundReaction，命令副作用统一 | ARC | P2 | 0004 拆文件后 |
| 8 | [ADR-0006](ADR-0006.md) | 值相等 / 回调上抛 / .select / provider 拆分 / ClipRect / desktop_widget State 拆分 | DEBT | P2 | 0001/0002/0004 先行 |
| 9 | [ADR-0008](ADR-0008.md) | 存储终态：共享 SQLite（drift_flutter）+ 轻量广播；启动判据来自 0002 基准回填 | DEP | P2 | 0002/0007；须用户确认 |

## 审计论断核实修正摘要（真实数据来源）

- `happensOn` lib/ 零调用属实，但 test/widget_test.dart 有 4 处测试调用。
- core 包 `Result.flatMap` **已存在**（result.dart:61）；缺的是异步组合子，
  `guardAsync` 现居应用层 lib/core/result_x.dart。
- ports.dart 实为 381 行 / 12 端口 / **6 DTO / 2 枚举**；reloadTargetFor 在 :41-53；
  TrayAction 14 成员混合窗口指令与导航，非纯导航。
- 中文星期表头文本在 lib/core/calendar_math.dart:142-160，非 controllers。
- Riverpod `.select((` 全仓 **0 处**（审计的 3 处是业务方法）；ref.watch 72 处/31 文件。
- 行高 96/112 写死在 month_grid.dart:62；desktop_widget_app 共 1813 行，
  空刷新 setState 在 :337/:483（非 328/474）。
- FlutterSecureStorageAdapter 是 SecureStore 适配器，与死代码
  SharedPreferencesStore 无关；后者零实例化，可连同依赖移除。
- Pigeon v30 native interop 为 preview 且仅 Android/iOS/macOS；
  **Windows 走平台通道模式**（官方博客 + 本地 pigeon 30.0.4 指南双重核实）。
- drift_flutter 0.3.1 → drift 2.35.4 + sqlite3 3.9.1（Dart hooks 自动捆绑
  SQLite）；`shareAcrossIsolates` 不跨 engine，多 engine 须各开连接共享文件。

## 外部依据

- https://flutter.dev/blog/whats-new-in-flutter-3-50（2026-11-11）
- https://flutter.dev/blog/stable-native-interop（2026-11-12）
- pub 缓存源码核实：pigeon 30.0.4 / drift_flutter 0.3.1 / sqlite3 3.9.1 /
  window_manager 0.7.0 / tray_manager 0.9.0 / screen_retriever 0.4.0
- 既有验收文档：docs/cross-engine-sync-analysis.md（DataHub 方案 A，2026-11-16）