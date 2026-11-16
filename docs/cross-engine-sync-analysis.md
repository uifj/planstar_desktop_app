# 企划星桌面端：跨 Engine 数据同步根因分析与改造方案

> 分析对象：`planstar_desktop_app`（Flutter 3.41.9 / Dart 3.11.5，Windows 桌面端）
> 触发问题：在桌面 overlay 的日历格子内编辑后，主窗口数据不刷新；前序修复（`6af037f` 增加 `ref.keepAlive()`）后问题仍存在。
> 方法：Dart 层全链路审查 + Windows 原生层审查 + 插件源码核查 + 运行时取证（进程 / 窗口 / 磁盘 / revision）。

---

## 0. 结论摘要

**上一轮修复只解决了「订阅被取消」，没有解决「刷新动作本身是空操作」。**

决定性发现：`SharedPreferences.reload()` 在当前 Windows 实现上是**无效的**。
`shared_preferences 2.5.6` 的 legacy `reload()` 只是重新调用 `_store.getAll()`，而
`shared_preferences_windows 2.4.1` 的 `getAll()` 返回的是**每个 isolate 自己的
`_cachedPreferences`**；该缓存通过 `??=` 只在首次读一次磁盘，之后**永不清空、永不重读**。
`shared_preferences_platform_interface` 里也**根本不存在 `reload()` 方法**可供转发。

因此，即使 revision 轮询正常、`CrossEngineSyncController` 保活、`_reload()` 被调用，
`storageReloader.reload()` 也只是把主窗口自己的旧内存缓存重新灌了一遍——**桌面窗口写到
磁盘的数据永远进不来**。这才是「仍存在同步问题」的第一根因。

在此之上还叠加了六类缺陷：整表 read-modify-write 的丢失更新、非原子写与半截 JSON、
时间戳 revision 的通知丢失/自反馈、700ms 全量重载的中间态、领域事件不跨 engine、
隐藏窗口不销毁 engine 导致的缓存累积。它们共同造成「看起来偶尔能同步、但不可靠」。

推荐方案：**原生进程级 DataHub（单一真相源）**——所有写通过 MethodChannel 汇聚到同进程
的原生单例串行化，成功后用 EventChannel 向所有 engine 广播带单调 revision 的增量；Dart
侧用 `DataHubStore` 实现现有 `KeyValueStore` 端口，领域层零改动。

---

## 1. 现状链路还原

```
桌面 overlay engine B                          磁盘                         主窗口 engine A
─────────────────────                        ────                         ─────────────────
TextField.onChanged
  → CalendarController.saveCellLines
  → LocalCalendarRepository.saveCell
      → JsonListStore.readAll()      ← 读 B 的 _cachedPreferences（旧快照）
      → writeAll(next)               ← 整表覆盖
  → SharedPreferences.setString
      → _cachedPreferences[key]=...  （B 内存）
      → writeAsStringSync(整份 JSON) ──────► shared_preferences.json（非原子）
  → onWrite: FileCrossEngineSync.signalChange()
      → 写 planstar_revision.txt（微秒时间戳，截断写、非原子）
  → _bus.dispatch(DayCellChanged)   ← 只在 B 的 DomainEventBus 内
                                          │
                      700ms Timer.poll  ◄───┘（每个 engine 都轮询）
                                          │
                        A: value != _lastValue → _changes.add(null)
                        A: CrossEngineSyncController._reload()
                             → storageReloader.reload()   ← ❌ 空操作（仍读 A 的旧缓存）
                             → Future.wait(7 个 controller.load())  ← 仍读 A 的旧缓存
                             → UI 不变
```

运行时取证（本次会话）：

| 项目 | 观测值 | 含义 |
|---|---|---|
| 进程 | 单进程 `planstar_desktop_app` PID 23016 | 所有 engine 同进程，进程级单例可行 |
| Flutter 窗口 | 2 个（主窗口 + 1 overlay） | 当前未累积，但 hide 不销毁有累积风险 |
| overlay region | `480,16 → 1488,836`（1008×820） | 卡片正常，命中裁剪生效 |
| revision 文件 | 与 `shared_preferences.json` 同在 `%APPDATA%\com.example\planstar_desktop_app` | 两 engine 共享同一目录，路径不是问题 |
| 磁盘 17 日 | 曾出现「主/子窗口内存有、磁盘缺一天」 | 直接证明 RMW 覆盖已发生 |

---

## 2. 根因分析

### 2.1 【决定性】`SharedPreferences.reload()` 在 Windows 上是空操作

证据链：

- `lib/infrastructure/storage_adapters.dart:52` → `Future<void> reload() => _prefs.reload();`
- `shared_preferences-2.5.6/lib/src/shared_preferences_legacy.dart:248-252`
  ```dart
  Future<void> reload() async {
    final Map<String, Object> preferences =
        await SharedPreferences._getSharedPreferencesMap();
    _preferenceCache.clear();
    _preferenceCache.addAll(preferences);
  }
  ```
  `_getSharedPreferencesMap()` 最终调到 `_store.getAll()`（同文件 `:277`）。
- `shared_preferences_platform_interface-2.4.2`：**全包无 `reload()` 声明**，无法向平台实现转发「丢弃缓存」。
- `shared_preferences_windows-2.4.1/lib/shared_preferences_windows.dart:38,50-57`
  ```dart
  Map<String, Object>? _cachedPreferences;          // per-instance / per-isolate
  Future<Map<String, Object>> _readPreferences() async {
    _cachedPreferences ??= await _readFromFile(...); // 只在首次读盘
    return _cachedPreferences!;
  }
  ```
  `getAll()` (`:91-114`) 返回 `Map.from(await _readPreferences())` — **永远是同一份内存 Map**。
  只有 `SharedPreferencesAsyncWindows.reload()` (`:288-292`) 会重置缓存，但它是**另一个类的另一个字段**，
  与 legacy API 无关。

**影响**：跨 engine 的整条「reload → load」链路在 Windows 上从设计起就不可能生效。
前序 `6af037f` 让订阅恢复后，只是让这个空操作每 700ms 被稳定地执行一次。

### 2.2 【数据一致性】整表 RMW 造成后写覆盖先写

- `lib/features/calendar/infrastructure/local_calendar_repository.dart:126-138`（`saveCell`）、
  `:74-87`、`:90-103`；`lib/infrastructure/json_entity_store.dart:54-89`：
  全部是 `readAll()` → `removeWhere/add` → `writeAll(next)`。
- `lib/features/calendar/application/calendar_controllers.dart:201-206` `_cellOf()` 从
  `state.cells`（内存快照）取，不读盘。
- `lib/windows/desktop_widget_app.dart:745-746`：`_updateLineText` 每次按键即 `saveCellLines`。
- `shared_preferences_windows.dart:393-394`：`writeAsStringSync(json.encode(preferences))` —
  把**整份 Map** 覆盖写回。

两个 engine 各持一份 `_cachedPreferences`。A 改 16 日、B 改 17 日，各自基于自己的旧快照
写整份文件，后写者抹掉先写者。无锁、无版本号、无 CAS、无按 key 粒度。
本次取证已观察到「磁盘少一天」的实际后果。

### 2.3 【事件时序】写盘、通知、重载之间没有屏障

- `storage_adapters.dart:31-34`：`await _prefs.setString(...)` 返回即 `signalChange()`。
  Windows 实现是同步 `writeAsStringSync`，**顺序本身没问题**，但：
- `shared_preferences_windows.dart:393-394` 是**截断直写**，非 `tmp + rename`；另一 engine
  的 `_readFromFile()` (`:349-370`) 用 `readAsStringSync()` + `json.decode()` 且**无 try/catch**。
  并发时读到半截 JSON 会抛异常，令 `reload()`/`load()` 整批失败，且没有任何重试补偿。
- `cross_engine_sync.dart:48-51` revision 用 `microsecondsSinceEpoch`：
  - 无单调计数器；同值写入会让 `:64` 的 `value != _lastValue` 判不出变化，通知丢失；
  - 无来源 id → **写入方自己也收到通知并 reload**（自反馈），引发一次无意义的全量重载；
  - `writeAsString(..., flush:true)` 仍是截断写，与 `:63` 的 `readAsString` 并发可产生伪变更。
- `cross_engine_sync_controller.dart:30-33`：`_reload()` 未 await、无重入保护、无 revision 比对。
  700ms 内多次变化会并发多组 `load()`，慢的旧结果可能覆盖快的新结果。

### 2.4 【线程调度】多 engine 回调不在同一线程

- `desktop_multi_window/windows/flutter_window.cc:23` 子 engine 设置
  `set_ui_thread_policy(RunOnSeparateThread)`；各 engine 的 `BinaryMessenger` 与 channel 回调
  可能落在不同线程。
- `desktop_multi_window/windows/window_channel_plugin.cc:159` 的 `ChannelRegistry` 用
  `std::mutex` 保护，但本项目 `windows/runner/desktop_wallpaper_plugin.cpp:98-99,403`
  的三个全局容器（`g_original_procs` / `g_overlay_windows` / `g_plugins`）**完全无锁**。
- `desktop_multi_window` 的 `window_channel_plugin.cc:84-86,244-268`：unidirectional 只允许
  1 个 handler、bidirectional 最多 2 个 peer，**N>2 窗口广播会受限**。
- Dart 侧 `Timer.poll` 跑在各 engine 的 UI isolate；`dart:io` 文件 IO 走平台线程池。
  轮询与写入在不同线程交错，进一步放大 2.2 / 2.3。

### 2.5 【生命周期】隐藏窗口不销毁 engine，且无退出钩子

- `desktop_adapters.dart:258-265` `hideCurrentWindow()` → `WindowController.hide()`；
  `:291-293` `closeWindow(id)` **名不副实，也只 hide**。
- `desktop_controller.dart:153-157` 隐藏时 `_widgetWindowIds.clear()`，再次打开 `:134-138`
  会新建**又一个 engine**；旧 engine 继续 700ms 轮询、继续持有自己的缓存 → 多份写入源。
- `cross_engine_sync.dart:75-78` 的 `dispose()` 全项目零调用。
- `desktop_widget_app.dart:90-97` 的 `dispose()` 只取消位置去抖 timer；全项目无
  `didChangeAppLifecycleState` / detached 钩子 → 退出前不强制 flush。
- 原生 `desktop_wallpaper_plugin.cpp:407-411` 只 `push_back` 不注销，窗口销毁后
  plugin 实例与 HWND 悬留。

### 2.6 【副作用一致性】领域事件不跨 engine

- `bootstrap.dart:80-84` 每个 engine 独立 `DomainEventBus`。
- `local_calendar_repository.dart:179-185`、`json_entity_store.dart:107-110` 只向本 engine dispatch。
- `cross_engine_sync_controller.dart:38-50` 的 reload 路径**只调 `load()`，不 dispatch 任何事件**。
- 订阅者只在 `planstar_app.dart:30-36` 创建（主窗口）；`sub_window_app.dart:33-44`
  根本没有 Reminder / Sync / Desktop controller。

结果：桌面编辑产生的 `DayCellChanged` 不会让主窗口重排提醒、增加 dirtyCount、刷新壁纸。
README:298 声称「领域事件、历史留痕、提醒重排、同步标脏与主窗口编辑完全一致」**与实际不符**。

### 2.7 【死代码】refresh 指令链路从未被使用

- `desktop_adapters.dart:296-304` 定义了 `sendTo()`，`desktop_adapters.dart:220` 是
  `MultiWindowCommand` 的唯一构造点（入站解码）；**`sendTo()` 全项目零调用**。
- `sub_window_app.dart:36-43` 的 `refresh` 分支只 `load()` 便签与倒数日，且未保存
  `StreamSubscription`、无 dispose；`desktop_controller.dart:238-240` 收到指令只改提示文案。
- README:284/304 描述的「立即同步」实际全部依赖 700ms 文件轮询。

### 2.8 前序修复有效性评估

| 前序改动 | 解决的问题 | 未解决 |
|---|---|---|
| `6af037f` 五个后台控制器加 `ref.keepAlive()` | Riverpod 3 自动 dispose 导致 revision 订阅被取消 | reload 无效、RMW、时序、副作用、生命周期 |
| `ce6f45c` 桌面组件放大 + 格子内编辑 | 编辑体验 | 每按键一次整表 RMW，反而**加剧** 2.2 |
| 初始 `FileCrossEngineSync` 文件轮询 | 提供了「有变化」的概念 | 700ms 延迟、时间戳易碰撞、非原子、自反馈、无来源 |

---

## 3. 关键事实依据（决定方案可行性）

### 3.1 所有 engine 共享同一 Win32 进程 → 进程级单例可行

| 证据 | 位置 |
|---|---|
| 单 `wWinMain` + 唯一 `GetMessage` 循环，无 `CreateProcess` | `windows/runner/main.cpp:8,47-51` |
| 子窗口由 `CreateWindow` + `new FlutterViewController` 创建 | `desktop_multi_window/windows/multi_window_manager.cc:45-86` |
| `MultiWindowManager::Instance()` / `ChannelRegistry::GetInstance()` 进程级单例 | `multi_window_manager.cc:38-41`、`window_channel_plugin.cc:27-32` |
| 子 engine 创建回调直接把 `void*` 还原成本进程 `FlutterViewController*` | `windows/runner/flutter_window.cpp:36-53` |
| 安装脚本按单一进程名过滤；一次 Stop-Process 连带所有 engine | `windows/installer/install.ps1:49` |

### 3.2 通道基础设施现状

- Dart 侧**唯一的裸通道**：`lib/infrastructure/desktop_wallpaper_gateway.dart:17`
  `OptionalMethodChannel('planstar/desktop_wallpaper')`。
- 原生侧 `desktop_wallpaper_plugin.cpp:160-168`：每 engine 一份 `MethodChannel` +
  `SetMethodCallHandler`；**无 `EventChannel` / `EventSink` / `SetStreamHandler`**。
- SDK 头文件 `windows/flutter/ephemeral/.../event_channel.h` 存在但业务未 include。
- 已有「原生 → Dart 主动推送」范式可复用：
  - `desktop_multi_window` 的 `NotifyWindowEvent()` → `InvokeMethod`（`flutter_window_wrapper.h:32-38`）；
  - 归档 `.archive/vectra/windows/runner/flutter_window.cpp:793,826,928` 大量 `InvokeMethod` 反推，
    且 `vectra/lib/native/native_bridge.dart:75-76` 明确注释「两个引擎不共享 isolate，
    只能由侧边栏喊 native、native 再喊这边」。
- `DesktopMultiWindowSetWindowCreatedCallback` 只给 `FlutterViewController*`，**不带 windowId**；
  可用 `GetAncestor(view->GetNativeWindow(), GA_ROOT)` 拿 HWND 反查（现有代码已这么做）。

### 3.3 归档参考的边界

- `.archive/vectra/windows/runner/view_window.h:11-30` 给出最有价值的方向：
  控制面板/插件市场**共用同一个 Flutter engine、同一 isolate，只是多一个 View**
  （`FlutterDesktopEngineCreateViewController`），并直言若跑在另一个引擎
  「得改成二十几个字段的双向同步协议，两边各持一份状态必然互相覆盖」。
- `.archive/xdiarys-unpacked` 中「同步」全部是**云端/VIP 同步**语义；未发现共享内存、
  文件锁、命名管道、单实例等本地多进程 IPC 线索，无法直接复用其实现。

---

## 4. 同步解决方案

### 4.1 方案 A（推荐）：原生进程级 DataHub —— 单一真相源 + EventChannel 广播

**核心思想**：既然所有 engine 在同一进程，就让**原生层持有唯一一份权威数据**，
Dart 侧不再各自持有可写的缓存；写操作串行化，读操作走同一份镜像；变更通过
EventChannel 主动推送，去掉轮询。

```
                    ┌─────────────────────────────────────────┐
                    │  Win32 进程级单例 DataHub::Instance()    │
                    │  std::mutex + Map<key,value> + uint64 rev│
                    │  原子落盘 tmp→MoveFileEx(REPLACE)        │
                    └──────┬──────────────────────────┬───────┘
      MethodChannel        │                          │  EventChannel
  'planstar/data_hub'      │                          │  'planstar/data_hub_events'
   write/read/snapshot     │                          │  {key,value,rev,origin,events}
        ▲                  │                          ▼
   ┌────┴────┐        ┌────┴────┐              ┌──────────────┐
   │engine A │        │engine B │   ...        │ sink 注册表  │
   │DataHub- │        │DataHub- │              │ 每 engine 1个│
   │ Store   │        │ Store   │              └──────────────┘
   └─────────┘        └─────────┘
```

**通道契约**

| 通道 | 方向 | 方法 | 参数 / 返回 |
|---|---|---|---|
| `planstar/data_hub` (MethodChannel) | Dart → Native | `snapshot` | → `{revision, entries: {key: value}}` |
| | | `read` | `{key}` → `value?` |
| | | `write` | `{key, value, origin, events}` → `{revision, ok}` |
| | | `delete` | `{key, origin, events}` → `{revision, ok}` |
| `planstar/data_hub_events` (EventChannel) | Native → Dart | broadcast | `{key, value|null, revision, origin, events, eventId}` |

**原生实现要点**

1. `windows/runner/data_hub.h/.cpp`：函数内 static 单例；`std::mutex` 保护
   `entries_` / `revision_` / `sinks_`。C++17、`_HAS_EXCEPTIONS=0`（`windows/CMakeLists.txt:46-52`），
   不得抛异常，全部用返回值/错误码。
2. 写入顺序（在锁内串行）：`revision_++` → 更新 `entries_` → 写临时文件 →
   `MoveFileExW(..., MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH)` 原子替换 →
   构造广播 payload → 解锁 → 广播。
3. `EventChannel<flutter::EncodableValue>` + `SetStreamHandler`；每个 engine 注册时
   把 `EventSink` 登记进 `sinks_`，注销时移除。
4. **线程**：子 engine 为 `RunOnSeparateThread`，`EventSink::Success()` 必须在该 sink
   所属 engine 的平台线程调用。统一用 `PostMessage(hwnd_main, WM_APP_DATA_HUB_BROADCAST, ...)`
   把广播派发到主消息循环线程串行执行（`windows/runner/main.cpp:47-51` 的循环所在线程）。
5. `windows/runner/flutter_window.cpp:30`（主 engine）与 `:36-53`（子 engine 回调）
   各注册一次 MethodChannel + EventChannel，并把 sink 登记到单例。
   `windows/runner/CMakeLists.txt:9-18` 把新 `.cpp` 加入 `add_executable`。
6. **不要改** `generated_plugin_registrant.cc` / `generated_plugins.cmake`（自动生成会被覆盖）。
7. 顺带给 `desktop_wallpaper_plugin.cpp` 的三个全局容器补 `std::mutex`（当前无锁）。

**Dart 侧改造点（保持 Clean DDD）**

- `lib/core/ports.dart`：`CrossEngineSync` / `StorageReloader` 语义保持不变（可新增
  `DataHubPort` 或扩展方法），领域层零改动。
- `lib/infrastructure/data_hub_store.dart`：新增 `DataHubStore implements KeyValueStore,
  StorageReloader`；`read/write/delete` 走 MethodChannel；订阅 EventChannel，
  收到广播后更新本地只读镜像 + 递增 revision。
- `lib/bootstrap/bootstrap.dart:51-57,141-143`：不再 `SharedPreferences.getInstance()`，
  改用 `DataHubStore` 并为它注入 `onChange` → `CrossEngineSyncController`；
  保留 `domainEventBusProvider` 每 engine 一份，但广播里的 `events` 在每个 engine
  本地 `bus.dispatch()`（由写入方在调用 `write` 时把本次领域事件序列化随 payload 带上）。
- `CrossEngineSyncController._reload()`：改为「按广播的 `key` 精准 reload 对应 controller」
  + revision 单调比对（丢弃 `revision <= lastApplied` 的旧广播）；不再 7 个全量 `load()`。
- 写入方：**不再乐观更新 state**，统一等待自己那条广播回来后更新，保证因果顺序唯一；
  往返成本约 1 次 channel（`≤16ms`）。
- `sync_controller.dart` / `reminder_controller.dart` / `history_controller.dart`：
  收到广播后执行幂等副作用（提醒重排、dirty 计数、留痕），用 `eventId` 去重。
- **数据迁移**：首次启动若 `shared_preferences.json` 存在且 hub 为空，一次性导入
  `flutter.*` / `planstar.*` 键到 hub，保留 `planstar.*.v1` 键名不变。

**跨平台降级**

| 平台 | 实现 |
|---|---|
| Windows | 原生 C++ DataHub（MethodChannel + EventChannel），完整实时性与一致性 |
| Linux / macOS | Dart 层 `FileDataHub`：原子写 + 文件变更监听（`dart:io` / `Stream`），单 writer 串行队列；不依赖 `SharedPreferences.reload()` |
| Web | 单 engine，`InMemoryDataHub` 直通 |
| 单元测试 | `FakeDataHub`（`InMemorySharedPreferencesStore` 风格）注入，可测并发/乱序/重放 |

端口抽象统一为 `DataHubPort`，`bootstrap.dart` 按 `defaultTargetPlatform` 选择实现。

### 4.2 方案 B（过渡 / 低风险）：Dart 层权威 writer + 定向广播

不改原生 C++，用现成的 `desktop_multi_window` 通道：

1. **指定主窗口为唯一 writer**：子窗口的 `KeyValueStore.write` 通过
   `sendTo(mainWindowId, 'write', {...})` 转发给主窗口，由主窗口串行写盘；
   主窗口写成功后 `openWindowIds()` 逐个 `sendTo(..., 'dataChanged', {key, rev})`。
2. 每个 engine 收到 `dataChanged` 后**直接读文件**（`dart:io` 读 JSON，绕开
   `SharedPreferences` 的内存缓存），更新本地 state。
3. 用单调 `uint64` revision 替代时间戳；按 key 粒度 reload。

- 优点：改动全在 Dart 层，一轮可落地，实时性 ~50ms。
- 缺点：`ChannelRegistry` 有 1 handler / 2 peer 上限（N>2 窗口受限）；仍是
  「文件 + 消息」双通道，非原子写竞态仍在；依赖主窗口存活；领域事件仍需单独处理。
- 适用：作为方案 A 落地前的止血，或 Linux/macOS 的降级实现。

### 4.3 方案 C（长期方向）：共享单 engine + 多 View

参考 `.archive/vectra/windows/runner/view_window.h:11-30`：桌面 overlay 不再是独立
engine，而是主 engine 的第二个 `FlutterViewController`（同 isolate、同 Riverpod 容器）。
此时数据天然共享，**同步问题消失**，但需重写窗口创建、插件按 view 注册、`main.dart`
双入口、overlay 原生通道归属，改动面最大，建议作为下一阶段架构演进，不与本次修复混合。

### 4.4 不推荐：继续修补文件轮询

修 `reload()`（改为直接读文件）+ 换单调 revision + 原子写 + 加文件锁，
可以缓解症状，但 Dart 层无法可靠做跨 isolate 文件锁（Windows 上 `dart:io` 无
`flock` 等价物），且轮询延迟与全量重载的结构性缺陷无法消除。**不建议**。

---

## 5. 修复目标（可度量）

| 编号 | 目标 | 当前 | 目标值 |
|---|---|---|---|
| G1 | 端到端可见延迟（桌面编辑 → 主窗口刷新） | ≥700ms 且常常不生效 | P95 ≤ 50ms（方案 A：≤2 次 channel 往返） |
| G2 | 丢失更新 | 存在（整表 RMW） | 并发 N 个 engine 各写不同日期，**0 丢失** |
| G3 | 状态收敛 | 各 engine 缓存可长期分叉 | 广播到达后所有 engine `revision` 一致，最终一致收敛 ≤1 帧 |
| G4 | 落盘可靠性 | 截断直写，可读到半截 JSON | 原子替换；故障注入下 0 次解析异常、0 次静默丢数据 |
| G5 | 副作用一致性 | 只有写入方 engine 有领域事件 | 提醒重排 / 历史留痕 / dirty 计数在所有 engine 一致且幂等 |
| G6 | 生命周期 | hide 不销毁、重复打开累积 engine | 隐藏复用同一 engine；退出前 flush；`sinks_` 无泄漏 |
| G7 | 实时性机制 | 700ms 轮询 | 事件驱动（EventChannel / 定向推送），无常驻轮询 |
| G8 | 跨平台 | 仅 Windows 有（且失效） | Windows 原生 / Linux+macOS Dart fallback / Web 直通，同一端口契约 |

---

## 6. 约束条件

1. **架构不变**：`lib/core`、`lib/features/*/domain|application` 保持纯 Dart；
   插件/通道只允许出现在 `lib/infrastructure` 与 `lib/bootstrap`。
2. **端口兼容**：`KeyValueStore` / `StorageReloader` / `CrossEngineSync`、
   `JsonListStore`、全部 repository 与 controller 的调用签名尽量不改，避免回归。
3. **数据不丢**：保留 `planstar.calendar.cells.v1` 等既有键名；启动时一次性迁移；
   迁移失败必须可回滚（保留原 `shared_preferences.json` 备份）。
4. **离线可用**：不引入网络/云同步；`ApiClient` 的降级语义不变。
5. **状态管理唯一**：仍只用 Riverpod 3，不引入第二套状态容器；不新增跨 engine
   「双份真相源」。
6. **原生侧限制**：C++17、`_HAS_EXCEPTIONS=0`、不得用异常；新增源码必须登记到
   `windows/runner/CMakeLists.txt:9-18`；不动 generated 文件；`dwmapi.lib` 等现有链接项够用。
7. **线程安全**：所有进程级全局状态必须加锁或投递到主线程；`EventSink` 调用遵守
   各 engine 的平台线程约束。
8. **兼容性**：`desktop_wallpaper` 通道、`SetWindowRgn`、`AppUserModelID`、
   安装/卸载脚本、应用图标、字体均不受影响。
9. **可测试性**：Dart 侧能用 fake channel 覆盖并发写、乱序广播、重放、迁移；
   原生侧提供 `resetForTest()` 之类的钩子（仅 debug）。
10. **范围**：不改动桌面组件 UI 交互逻辑，只替换其底层存储与通知链路。

---

## 7. 预期效果与验证方法

### 预期效果

- 桌面格子内逐字输入时，主窗口月历同帧跟随；反向（主窗口 → 桌面）同样即时。
- 两个窗口同时编辑不同日期，双方数据都保留，不再出现「磁盘少一天」。
- 桌面编辑后，主窗口的通知重排 / 历史记录 / 账号同步 dirty 计数同步变化。
- 托盘「隐藏 / 显示桌面月历」反复切换不会累积 engine，不会引入额外写入源。
- 应用异常退出（`Stop-Process -Force`）后重启，最后一次输入不丢（原子落盘）。
- Linux/macOS 走 Dart fallback，行为一致（延迟略高），Web 单窗口直通。

### 验证方法

1. **单元测试（Dart）**：`FakeDataHub` 注入，构造「A 写 key1 / B 写 key2 交错」、
   「乱序广播 revision 回退」、「重复 eventId」、`write` 失败回滚、迁移分支。
2. **集成测试**：`ProviderContainer` 双容器模拟两个 engine，断言 `revision` 收敛一致。
3. **运行时取证**：
   - 在桌面编辑后抓取主窗口截图，用 OCR/目视确认；
   - 监控 `planstar_revision.txt` 与数据文件时间差（方案 A 下该文件可移除）；
   - `windows/installer/verify_desktop_widget.ps1` 扩展：统计 Flutter 窗口数、
     断言隐藏/重开后窗口数不增长。
4. **故障注入**：写盘中途强制结束进程（模拟半截文件），重启后断言 JSON 可解析、
   数据完整。
5. **延迟测量**：`DateTime.now()` 在 `write` 前与「对端 state 更新」后打点，
   统计 P50/P95。

---

## 8. 实施顺序与风险

| 阶段 | 内容 | 风险 |
|---|---|---|
| P0 止血 | 把 `storageReloader.reload()` 改成「直接用 `dart:io` 读 JSON 重建仓储」，绕开失效缓存；revision 换单调 uint64、原子写、带 origin 去重 | 低；能立即让同步真正生效，但仍有 RMW 覆盖 |
| P1 方案 A 骨架 | 新增 `data_hub.h/.cpp`、MethodChannel + EventChannel、`sinks_` 注册表、CMake 登记 | 中；需确认 `EventSink` 线程约束与 `PostMessage` 派发 |
| P2 Dart 接入 | `DataHubStore` 实现端口、`bootstrap` 切换、按 key reload、领域事件广播、数据迁移 | 中；迁移需备份 + 回滚开关 |
| P3 生命周期 | `closeWindow` 真正销毁或复用、注销 sink、退出 flush、补全局容器锁 | 中；涉及 `desktop_multi_window` 插件行为 |
| P4 跨平台 | Linux/macOS `FileDataHub`、Web 直通、fake 测试 | 低 |
| P5 验收 | 单元/集成/故障注入/延迟测量，更新 README 与 `verify_desktop_widget.ps1` | 低 |

**主要风险与对策**

- `EventSink` 跨线程调用崩溃 → 统一 `PostMessage` 到主 HWND 串行派发。
- 原生侧解析 JSON 需要库 → 用 `flutter::EncodableValue` + 现有
  `StandardMethodCodec` 传递，原生层只存 `std::string`（value 已是 JSON 字符串），
  **不必在 C++ 解析业务 JSON**。
- 数据迁移破坏现有数据 → 保留原文件只读备份，hub 为空时才导入，导入成功后标记
  `migrated` 键；提供环境变量/开关强制回退。
- `desktop_multi_window` 回调不带 windowId → 用 `GetAncestor(..., GA_ROOT)` 得 HWND，
  或自建 `messenger → sink` 映射，`origin` 用进程内自增 engine 序号即可。

---

## 9. 关键代码位置索引

| 主题 | 位置 |
|---|---|
| 失效的 reload 定义 | `lib/infrastructure/storage_adapters.dart:52` |
| revision 轮询 / 信号 | `lib/infrastructure/cross_engine_sync.dart:26-73` |
| 全量重载 | `lib/features/sync/application/cross_engine_sync_controller.dart:23-51` |
| 前序保活修复 | `lib/features/sync/application/cross_engine_sync_controller.dart:26-29` 等 5 文件 |
| 整表 RMW | `lib/features/calendar/infrastructure/local_calendar_repository.dart:74-158`、`lib/infrastructure/json_entity_store.dart:54-110` |
| 每按键写 | `lib/windows/desktop_widget_app.dart:745-746` |
| 每 engine 独立 bus / prefs | `lib/bootstrap/bootstrap.dart:51-57,80-84,139-166` |
| hide 即 close | `lib/infrastructure/desktop_adapters.dart:258-265,291-293` |
| 死代码 refresh | `lib/windows/sub_window_app.dart:36-43`、`lib/features/desktop/application/desktop_controller.dart:238-240` |
| 唯一 MethodChannel | `lib/infrastructure/desktop_wallpaper_gateway.dart:17` |
| 原生通道注册点 | `windows/runner/flutter_window.cpp:30,34-53` |
| 原生插件全局容器（无锁） | `windows/runner/desktop_wallpaper_plugin.cpp:98-99,403` |
| CMake 源文件登记 | `windows/runner/CMakeLists.txt:9-18` |
| 归档参考：单 engine 多 View | `.archive/vectra/windows/runner/view_window.h:11-30` |
| 归档参考：原生反推范式 | `.archive/vectra/windows/runner/flutter_window.cpp:793,826,928` |

---

## 10. 一句话结论

同步问题的本质是**「每个 engine 各持一份永不失效的 SharedPreferences 内存缓存，
却用一条无效的 reload + 700ms 文件轮询去假装它们共享数据」**；
前序修复只让轮询的订阅活了下来，没改变这个结构。
根治做法是把真相源上移到**同进程的原生单例**：MethodChannel 串行写入、
EventChannel 广播单调 revision 增量、Dart 侧保留 `KeyValueStore` 端口但换成
只读镜像 + 事件驱动更新，并让领域事件随广播在每个 engine 幂等重放。
