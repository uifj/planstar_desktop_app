# 企划星 · 桌面日历清单（Flutter 桌面端重写版）

基于 `.archive` 中解包的旧版桌面日历应用（`xdiarys-unpacked` / `dkappcal`、
`dkappnote`、`dkappthirdcal`）完整重写。**完全复用** `packages/infras/core`
（领域原语 / `Result` / 存储端口 / 配置加载 / 日志 / 网络 / 事件总线）与
`packages/infras/core_design_system`（三层设计令牌、亮/暗主题）的能力与样式，
不引入任何第二套颜色、字号或状态管理方案。

技术栈：Clean DDD + 六边形架构 + Riverpod 3 + go_router 17 +
`flutter_local_notifications` / `window_manager` / `desktop_multi_window` /
`tray_manager` / `launch_at_startup` / `audioplayers` / `file_picker` /
`shared_preferences` / `flutter_secure_storage` / `path_provider` / `lunar` /
`lucide_icons_flutter`（全项目图标统一使用 Lucide，不再使用 Material Icons）；
字体统一为 `assets/fonts` 中的 ChillRoundGothic。

---

## 1. 运行

```powershell
flutter pub get          # Pub Workspace：packages/infras/* 由根工程统一解析
flutter run -d windows   # 开发调试
flutter test             # 领域层纯 Dart 单测
flutter analyze
```

**安装到本机**（用户级，无需管理员权限）：

```powershell
flutter build windows --release
powershell -NoProfile -ExecutionPolicy Bypass -File windows\installer\install.ps1 -Launch
```

安装内容：`%LOCALAPPDATA%\Programs\PlanstarDesktopApp`（32 MB Release 产物）、
开始菜单与桌面快捷方式（写入 `System.AppUserModel.ID`，保证 Windows 原生通知可用）、
HKCU「应用和功能」卸载项。重跑脚本即为覆盖升级，会自动停止旧实例。
卸载：设置 → 应用 → 应用和功能，或运行安装目录下的 `uninstall.ps1`
（会恢复系统原壁纸；默认保留用户数据，加 `-RemoveData` 才清除）。

已验证：Flutter 3.41.9 / Dart 3.11.5，`flutter build windows --debug` 通过。
依赖版本按当前 SDK 精确锁定（见 `pubspec.yaml` 注释）：
`flutter_local_notifications 22.3.3`（23+ 要 Flutter 3.44）、
`flutter_riverpod 3.3.2`（3.4+ 要 Dart 3.12）、
`audioplayers 6.7.1`、`file_picker 11.0.3`、
`flutter_secure_storage 10.3.4`（统一 win32 5.x，避免与开机自启插件冲突）。

---

## 2. 架构分层

```
Flutter 插件（只在 lib/infrastructure 与 lib/bootstrap 出现）
        ▲ 注入（overrideWithValue）
        │
┌───────┴──────────────────────────────────────────────────────┐
│ Presentation  lib/app, lib/features/*/presentation, lib/shared │  ← 只读 Riverpod
├───────────────────────────────────────────────────────────────┤
│ Application   lib/features/*/application                        │  ← Notifier / 用例
├───────────────────────────────────────────────────────────────┤
│ Domain        lib/features/*/domain, lib/core                   │  ← 纯 Dart 聚合/值对象/端口
├───────────────────────────────────────────────────────────────┤
│ Infrastructure lib/features/*/infrastructure, lib/infrastructure│  ← 适配器 / DTO
└───────────────────────────────────────────────────────────────┘
```

数据流（单向，写侧不直接调用读侧）：

```
UI 交互 → Notifier(用例) → 仓储端口(Result) → 聚合记录领域事件
        → 落盘成功后 DomainEventBus.dispatch
        → ReminderController 重排通知 / HistoryController 留痕 / SyncController 标脏
        → monthDataProvider（纯函数读模型）→ 月历网格重绘
```

聚合是**不可变**的：`changed()` 返回新实例并 `raiseDomainEvent()`；
仓储在 `JsonListStore.writeAll` 成功后才 `pullDomainEvents()` 分发，
避免「事件发了但没落盘」。

---

## 3. 完整目录结构

```
lib/
├── main.dart                                    # 双入口（主窗口 / 多窗口子 engine）
├── bootstrap/
│   ├── bootstrap.dart                          # 组合根：创建适配器 + Provider 覆盖
│   └── core_providers.dart                     # 全部端口的 Provider 声明
├── app/
│   ├── planstar_app.dart                       # MaterialApp.router + AppTheme + 提醒浮层
│   ├── router.dart                            # go_router StatefulShellRoute（10 个页面）
│   └── shell/
│       ├── app_shell.dart                     # 标题栏 + 侧边导航 + 全局快捷键
│       └── window_title_bar.dart              # 无边框窗口标题栏 / 月份导航 / 同步 / 主题
├── core/                                      # 共享内核（纯 Dart）
│   ├── value_objects.dart                     # DateKey / DateRange / EventColor / RichLine
│   ├── ports.dart                             # 所有驱动侧端口 + SoundTone / WindowRect 等 DTO
│   ├── app_events.dart                        # 跨上下文领域事件
│   ├── calendar_math.dart                     # 网格计算 + 农历/节气/节日/法定假日
│   ├── result_x.dart                          # guardAsync（异常边界收敛为 Result）
│   └── list_state.dart                        # AsyncListState<T> 列表页状态壳
├── infrastructure/
│   ├── storage_adapters.dart                  # SharedPreferences / SecureStorage → core 端口 + 跨 engine reload
│   ├── desktop_adapters.dart                  # window_manager / tray / multi_window / 自启 / 音效
│   ├── desktop_wallpaper_gateway.dart         # 桌面 overlay 通道适配器
│   ├── wallpaper_image_gateway.dart           # 壁纸 PNG 落盘 / 底图读取
│   ├── data_hub.dart                          # 跨 engine 单一真相源（MethodChannel/EventChannel + 降级）
│   └── cross_engine_sync.dart                 # 旧文件标记实现（仅作非 Windows 参考）
│   ├── file_gateway.dart                      # file_picker + dart:io + path_provider
│   └── json_entity_store.dart                 # 通用 JSON 聚合仓储骨架
├── shared/widgets/common.dart                 # AppSectionCard / Setting* / 调色板 / 弹窗骨架
├── windows/
│   ├── sub_window_app.dart                    # 子窗口分发（便签 / 倒数日 / 桌面组件）
│   └── desktop_widget_app.dart                # 桌面可编辑月历 overlay（格子内直接编辑 + 底部工具栏）
└── features/
    ├── calendar/                              # ★ 核心限界上下文
    │   ├── domain/
    │   │   ├── calendar_event.dart            #   事件聚合（4 类型 / 完成态 / 例外 / 截断）
    │   │   ├── day_cell.dart                  #   单元格聚合（逐行富文本）
    │   │   ├── recurrence.dart                #   16 种重复规则值对象
    │   │   ├── reminder_spec.dart             #   提前量多选 + 触发时刻
    │   │   ├── recurrence_policy.dart         #   重复展开领域服务
    │   │   └── repositories.dart              #   仓储端口 + 导入导出快照
    │   ├── application/calendar_controllers.dart
    │   │                                      #   CalendarController / MonthNavigation /
    │   │                                      #   SelectedDate / monthDataProvider 读模型
    │   ├── infrastructure/local_calendar_repository.dart
    │   └── presentation/
    │       ├── calendar_page.dart             #   主页面（含右键菜单）
    │       ├── widgets/month_grid.dart        #   多列月份网格
    │       ├── widgets/day_cell_widget.dart   #   单元格渲染（农历/节气/休班/任务/订阅/课程）
    │       ├── widgets/calendar_title_bar.dart
    │       ├── widgets/cell_editor_panel.dart #   逐行编辑、颜色、完成、提升为事件
    │       ├── widgets/countdown_bar.dart
    │       └── dialogs/
    │           ├── event_editor_dialog.dart   #   事件完整编辑（重复/提醒/颜色）
    │           └── context_dialogs.dart       #   23 色调色板 / 删除范围三态 / 清空确认
    ├── settings/                              # 7 个页签、50+ 配置项
    │   ├── domain/app_settings.dart
    │   ├── application/settings_controller.dart
    │   ├── infrastructure/settings_repository.dart
    │   └── presentation/settings_page.dart
    ├── notes/                                 # 便签（独立窗口 / 置顶 / 显隐 / 富文本）
    │   ├── domain/note.dart
    │   ├── application/notes_controller.dart
    │   ├── infrastructure/local_note_repository.dart
    │   └── presentation/{notes_page.dart,note_editor_dialog.dart}
    ├── countdown/                             # 倒数日 / 生日 / 纪念日 / 桌面卡片
    │   ├── domain/countdown.dart
    │   ├── application/countdown_controller.dart
    │   ├── infrastructure/local_countdown_repository.dart
    │   └── presentation/countdown_page.dart
    ├── timetable/                             # 课程表（单双周、节次、冲突检测）
    │   ├── domain/timetable.dart
    │   ├── application/timetable_controller.dart
    │   ├── infrastructure/local_timetable_repository.dart
    │   └── presentation/timetable_page.dart
    ├── subscription/                          # 本地 / Google / Outlook / iCloud / CalDAV
    │   ├── domain/subscription.dart
    │   ├── application/subscription_controller.dart
    │   ├── infrastructure/local_subscription_repository.dart  # ApiClient 远端
    │   └── presentation/subscription_page.dart
    ├── reminder/                              # 通知调度 + 应用内提醒弹窗
    │   ├── application/reminder_controller.dart
    │   ├── infrastructure/local_notification_gateway.dart    # flutter_local_notifications
    │   └── presentation/reminder_overlay.dart
    ├── search/                                # 全模块搜索 + 5 种范围
    │   ├── application/search_controller.dart
    │   └── presentation/search_page.dart
    ├── history/                               # 自动留痕 + 恢复
    │   ├── domain/history_entry.dart
    │   ├── application/history_controller.dart
    │   ├── infrastructure/local_history_repository.dart
    │   └── presentation/history_page.dart
    ├── transfer/                              # 数据库 / 文本 / CSV 导入导出
    │   ├── application/transfer_controller.dart
    │   └── presentation/transfer_page.dart
    ├── sync/                                  # 账号 / 登录 / VIP / 手动与自动同步
    │   ├── domain/sync_models.dart
    │   ├── application/sync_controller.dart
    │   ├── application/cross_engine_sync_controller.dart  # 多 engine 数据同步
    │   ├── infrastructure/sync_remote_data_source.dart
    │   └── presentation/account_page.dart
    └── desktop/                               # 托盘 / 窗口 / 开机自启 / 多窗口 / 桌面层
        └── application/
            ├── desktop_controller.dart        #   设置 → 打开桌面组件 / 可选静态壁纸
            ├── wallpaper_service.dart         #   （可选）底图 → 渲染 → 落盘 → 换壁纸
            └── wallpaper_renderer.dart        #   （可选）dart:ui 离屏绘制月历 PNG

assets/
├── config/default_config.json                # ConfigLoader 的 JSON 配置源
├── audio/                                     # 归档中的 5 个提示音
├── fonts/                                     # ChillRoundGothic（全局字体）
└── app_icons/                                 # 应用图标唯一源图（1024 透明底 + 满版）
    ├── planstar_icon_1024_transparent.png     #   Windows ICO / macOS / Web / 托盘
    ├── planstar_icon_1024_fullbleed.png       #   Web maskable 图标
    └── android/                               #   Android 启动器与商店图标

各平台图标均由 `assets/app_icons` 生成：
`windows/runner/resources/app_icon.ico`（16/24/32/48/64/128/256 多尺寸，
快捷方式与卸载项共用）、`macos/Runner/Assets.xcassets/AppIcon.appiconset/`、
`web/favicon.png` 与 `web/icons/`。

windows/runner/flutter_window.cpp              # 多窗口子 engine 插件注册 + 桌面壁纸插件注册
windows/runner/desktop_wallpaper_plugin.cpp    # WorkerW 嵌入 / SPI_SETDESKWALLPAPER
windows/runner/main.cpp                        # 显式 AppUserModelID（Win32 toast 通知）
windows/CMakeLists.txt                        # MSVC <experimental/coroutine> 兼容宏
windows/installer/install.ps1                  # 用户级安装：文件 + 快捷方式 + 卸载项
windows/installer/uninstall.ps1                # 卸载（默认保留用户数据 / 还原壁纸）
windows/installer/ShortcutAumid.cs             # 快捷方式 IPropertyStore 写入 AUMID
windows/installer/verify_desktop_widget.ps1     # 桌面层自检：样式 / 裁剪 / Z 序 / 命中穿透
test/widget_test.dart                          # 重复规则 / 提醒 / 设置序列化单测
```

---

## 4. 状态管理清单（Riverpod）

| Provider | 类型 | 职责 |
|---|---|---|
| `core_providers.dart` | `Provider` × 18 | 组合根注入：时钟、ID 生成器、KV/安全存储、`AppStore`、日志、配置、`ApiClient`、事件总线、桌面能力端口 |
| `calendarControllerProvider` | `Notifier<CalendarState>` | 事件 / 单元格 CRUD、删除三态、完成态、自动顺延、逐行编辑 |
| `monthNavigationProvider` | `Notifier<DateTime>` | 上/下月、回到今天 |
| `selectedDateProvider` | `Notifier<DateKey?>` | 编辑面板开合 |
| `monthDataProvider` | `Provider<MonthData>` | 纯函数读模型：网格 + 重复展开 + 农历 + 订阅 + 课程 + 倒数日 |
| `settingsControllerProvider` | `Notifier<AppSettings>` | 全局设置单一真相源 |
| `notesControllerProvider` 等 5 个 | `Notifier<AsyncListState<T>>` | 便签 / 倒数日 / 课程表 / 订阅 / 历史 |
| `searchControllerProvider` | `Notifier<SearchState>` | 关键词 + 范围 + 跨模块命中 |
| `reminderControllerProvider` | `Notifier<ReminderState>` | 领域事件 → 重排通知；通知点击 → 置顶弹窗 |
| `syncControllerProvider` | `Notifier<SyncState>` | 账号、脏数据计数、同步状态机 |
| `transferControllerProvider` | `Notifier<TransferState>` | 导入导出进度与结果 |
| `desktopControllerProvider` | `Notifier<DesktopState>` | 托盘动作、窗口透明度、开机自启、多窗口 |
| `routerProvider` | `Provider<GoRouter>` | `StatefulShellRoute.indexedStack` 保留各页面状态 |

---

## 5. 与旧版功能对照

| 旧版模块 / 资源 | 重写位置 |
|---|---|
| `cal_config.xml` 月历、农历、节气、节日、节假日、周数 | `calendar_math.dart` + `lunar` 包 + `settings` 开关 |
| `cal_event_func.lua` 16 种重复规则 | `recurrence.dart` + `recurrence_policy.dart` |
| 事件编辑、提醒提前量、微信通知 | `event_editor_dialog.dart` + `reminder_spec.dart` |
| 「仅当前 / 当前及未来 / 全部」删除 | `DeleteScope` + `CalendarController.deleteEvent` |
| 单元格富文本、23 色、完成态、完成排序 | `day_cell.dart` / `ColorSwatchPicker` / `CellEditorPanel` |
| 右键菜单（复制、粘贴、颜色、清空、倒数日、便签） | `calendar_page.dart::_contextMenu` |
| `cal_countdown_func.lua` 倒数/累计/生日 | `countdown/` |
| `cal_timetable.lua` 课程表、单双周、冲突 | `timetable/` |
| `cal_subs_func.lua` / `dkappthirdcal` 订阅 | `subscription/` + `ApiClient` |
| `cal_history_func.lua` 历史与恢复 | `history/`（事件驱动自动留痕） |
| `cal_search.lua` 搜索与范围 | `search/` |
| `cal_notify_func.lua` 提醒弹窗/提示音 | `reminder/` + `SoundGateway` |
| `dkappnote` 便签、置顶、独立窗口 | `notes/` + `desktop_multi_window` |
| `cal_setting_frame.xml` 7 页签设置 | `settings/`（50+ 字段全量映射） |
| 登录 / VIP / 云同步 | `sync/` |
| 导入导出（数据库 / 文本 / Excel） | `transfer/` |
| 托盘、开机自启、隐藏热键、透明度 | `desktop/` + `window_manager` / `tray_manager` |

---

## 6. 桌面可编辑小组件（Vectra 式实现）

参考 [macrostar/Vectra](https://gitcode.com/macrostar/Vectra) 的真实实现
（`windows/runner/win32_window.cpp` / `flutter_window.cpp` / `lib/ui/surface.dart`），
**不用静态壁纸**、也不把窗口 `SetParent` 进 `WorkerW`。桌面月历是一个真正的
可交互组件：

> 覆盖整个虚拟屏的透明 `WS_POPUP` overlay 窗口 +
> `WM_WINDOWPOSCHANGING` 无条件把 `hwndInsertAfter` 改成 `HWND_BOTTOM` +
> `DwmEnableBlurBehindWindow` 空 region 打开逐像素 alpha +
> `SetWindowRgn` 裁成所有卡片圆角矩形的并集。

因此：卡片内点击 / 输入 / 勾选 / 拖动全部由 Flutter 处理；卡片外的像素
完全不存在于窗口区域，点击直接落到桌面图标；窗口永远在所有普通窗口下面，
不会抢焦点也不进任务栏（`WS_EX_TOOLWINDOW`）。Vectra 实测 `WM_NCHITTEST` +
`HTTRANSPARENT` 在 Flutter 窗口结构下无效，故只用 `SetWindowRgn`。

| 层 | 文件 | 职责 |
|---|---|---|
| 原生 | `windows/runner/desktop_wallpaper_plugin.cpp` | `configureOverlay` / `setRegion` / 强制最底 WndProc 子类化 / `WM_DISPLAYCHANGE` 重铺虚拟屏 / 可选 `SPI_SETDESKWALLPAPER` |
| 通道注册 | `windows/runner/flutter_window.cpp` | 每个 engine 注册一份通道（主窗口 + 每个 `desktop_multi_window` 子窗口，HWND 取 `GetAncestor(view, GA_ROOT)`） |
| 端口 | `lib/core/ports.dart` | `DesktopWallpaperGateway.setRegion(DesktopCardRect)`、`MultiWindowGateway.openDesktopWidget()`、`CrossEngineSync` / `StorageReloader` |
| 应用 | `lib/features/desktop/application/desktop_controller.dart` | 设置 → 打开/关闭组件窗口；启动时恢复上一版设置过的系统原壁纸 |
| 表现 | `lib/windows/desktop_widget_app.dart` | 透明全屏 `Stack` + `Listener(HitTestBehavior.translucent)`；可拖动/可缩放的月历卡片（默认 1008×820，格子内直接编辑 + 底部编辑工具栏 + 内嵌调色板 + 8 方向 resize 热区） |
| 同步 | `lib/infrastructure/data_hub.dart` + `windows/runner/data_hub_plugin.cpp` + `lib/features/sync/application/cross_engine_sync_controller.dart` | 所有 engine 经 MethodChannel 把写操作汇聚到同进程的原生 DataHub 单例（mutex 串行 + 原子落盘 + 单调 revision），成功后用 EventChannel 广播增量；各 engine 按 key 精准重载读模型并幂等重放本地副作用 |

**桌面编辑能力（对齐旧版企划星）**：卡片默认 1008×820，格子按可用高度
自适应铺满（约 140×105，比旧版大近一倍）。点击任意日期即**在该格子内**进入
编辑态：每行一个输入框，可直接改文字、用 Lucide 勾选框标记完成、删除本行，
底部输入框回车再新增一行；不再弹出独立编辑卡片（弹窗会被 `SetWindowRgn` 裁掉）。
底部常驻两排：快速输入框 + 编辑工具栏（添加一行／文字颜色／单元格颜色／
标记完成／提升为任务／清空本日／完成编辑），颜色按钮在卡片内嵌一条 23 色调色板
（含「最近使用」与透明色），支持对当前行或整格文字着色、设置单元格背景色。
单元格/文字颜色都走 `EventColor` 值对象，默认文字按背景亮度自动取对比色。
卡片标题栏可拖动；**四条边 + 四个角**各有一条透明 resize 热区（6px / 16px，
右下角带可见握柄与对应鼠标光标），按住拖动即可调整大小，最小 560×420、
最大不超过虚拟屏。左/上方向调整会同步修正卡片左上角坐标以保持对侧不动；
调整期间同拖动一样放开整窗命中，松手后重推 `SetWindowRgn`。
格子由 `LayoutBuilder` 按新的可用宽高重算 `childAspectRatio`，字号与行内编辑
行高按格子宽度等比缩放（0.85×–1.5×），因此放大卡片时格子与文字一起变大。
位置与尺寸都做 8px 网格吸附、按屏幕夹紧，写入
`KVStore.planstar.desktop.card.v2` 的 `{x, y, width, height}`。
写入是**操作结束时立即落盘**（经 DataHub 串行 + 原子替换），并在
`didChangeAppLifecycleState` / `dispose` 再补一次，避免调整后马上退出进程
丢失最后一次操作；启动读取完成前禁止写盘，防止 `hiddenAtLaunch` 的生命周期
回调把默认值覆盖掉已保存的位置。旧数据无 width/height 时回落到默认尺寸。
所有写操作都走原有的 `CalendarController.saveCellLines` / `setLineColor` /
`setCellBackgroundColor` / `toggleLineCompleted` / `removeLine`，
领域事件、历史留痕、提醒重排、同步标脏与主窗口编辑完全一致。

```
桌面点击 → 格子内 TextField / Lucide 勾选框 / 底部颜色工具条
   → CalendarController（用例）→ CalendarRepository → 聚合 + 领域事件
   → DataHubStore.write → MethodChannel('planstar/data_hub')
   → 原生 DataHub 单例：串行化 → 原子落盘 → revision++
   → EventChannel('planstar/data_hub_events') 广播给所有 engine
   → 主窗口按 key 只重载 calendar 读模型 → 月历刷新
```

> Windows 上**不能**用 `SharedPreferences.reload()` 做跨 engine 同步：
> legacy `reload()` 只是重新调用 `getAll()`，而 `shared_preferences_windows`
> 的 `getAll()` 返回每个 isolate 自己的 `_cachedPreferences`，从不重读磁盘。
> 非 Windows / 原生通道不可用时，`DataHubStore` 自动降级为原子写 + 300ms
> 文件轮询（`_LocalBackend`），行为一致但延迟略高。冷启动会把旧的
> `shared_preferences.json`（去掉 `flutter.` 前缀）一次性迁移到
> `planstar_data_hub.json`，原文件保留作为回滚备份。

`desktopWidgetEnabled` 默认开启；托盘「显示 / 隐藏桌面可编辑月历」和设置页
「桌面」页签可切换。拖拽开始时 `setRegion(dragging: true)` 放开整窗命中，
松手后重推区域，避免逐帧 `SetWindowRgn` 造成残影（同 Vectra）。

**可选降级**：`wallpaperAutoRender` 默认**关闭**，仅作为静态快照备份保留
（`WallpaperRenderer` / `WallpaperService` 仍在，可由托盘手动生成）。
上一版若把系统壁纸改成了月历 PNG，新版启动时会依据
`planstar_wallpaper/original_wallpaper.txt` 自动还原。

也可用启动参数 `--planstar-embed-desktop` 单次强制把主窗口挂进 `WorkerW`
（旧模式，仅用于兼容验证，不是桌面组件的默认路径）。

**本机实测**（`powershell -File windows\installer\verify_desktop_widget.ps1`）：

```
overlay: 1 个；style=0x94000000 (WS_POPUP|WS_VISIBLE) ex=0x80 (WS_EX_TOOLWINDOW)
region : COMPLEXREGION，包围盒 128,128 -> 768,636（正好是月历卡片）
Z 序   : 23 / 25 可见窗口（仅 Progman 与系统状态窗在其下）
命中   : (60,60) 穿透 / (300,300) 命中组件 / (448,378) 命中组件 /
         (900,300) 穿透
壁纸   : 已从上一版的月历 PNG 还原为系统原壁纸
```

---

## 7. 关键配置文件

- `pubspec.yaml`：Pub Workspace（`packages/infras/core`、`core_design_system`）、
  全部插件版本、资产声明；`lucide_icons_flutter 4.0.3` 是全项目唯一图标集，
  `uses-material-design` 仅保留给 DatePicker 等 Material 内置控件的内部图标。
  `fonts` 声明 `assets/fonts/` 下的 ChillRoundGothic（Regular 400 / Medium 500）。
- `assets/fonts/`：全局字体 ChillRoundGothic，由 `AppTypography.fontFamily`
  在 `AppTheme` 中注入 `ThemeData.textTheme`，并通过 `AppTheme.withAppFont`
  作为三个 `MaterialApp` 的 `builder` 注入 `DefaultTextStyle`——Flutter 3.41
  的 `MaterialApp` 默认给 `WidgetsApp` 传的是 monospace 错误样式，不补这一层
  普通 `Text` 会回退到等宽字体。数字样式沿用 `FontFeature.tabularFigures()`
  等宽，bold(700) 由 Flutter 合成。
- `assets/config/default_config.json`：`ConfigLoader`（幂等、支持 DotKey 访问）。
- `windows/runner/flutter_window.cpp`：把 `RegisterPlugins` 挂到每个新建子窗口的
  Flutter engine 上，否则子窗口内所有插件都是 no-op。
- `windows/runner/main.cpp`：动态调用 `SetCurrentProcessExplicitAppUserModelID`，
  与快捷方式及 `flutter_local_notifications` 使用同一 AppUserModelID。
- `windows/runner/desktop_wallpaper_plugin.cpp`：按 engine 注册的桌面层通道。
  `configureOverlay` 建 `WS_POPUP` + `WS_EX_TOOLWINDOW` 透明全屏窗口并用
  `WM_WINDOWPOSCHANGING` 强制 `HWND_BOTTOM`；`setRegion` 用
  `CreateRoundRectRgn` 并集裁剪实现点击穿透；另保留可选的
  `SPI_SETDESKWALLPAPER` 静态快照能力。
- `windows/installer/`：用户级安装/卸载脚本与快捷方式属性写入辅助类。
- `windows/CMakeLists.txt`：MSVC 14.5x 下让 `audioplayers_windows` 的
  `<experimental/coroutine>` 可编译。
- `analysis_options.yaml`：`flutter_lints`，`flutter analyze` 零问题。

> 云端同步 / 订阅的默认地址是占位符，修改 `assets/config/default_config.json`
> 中的 `apiBaseUrl` 即可接入真实服务；`ApiClient` 永不抛异常，离线时
> 全部功能降级为本地存储，不影响主流程。
