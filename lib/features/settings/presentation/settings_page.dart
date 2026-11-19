/// 设置页：七个页签，完整映射 `AppSettings` 的全部开关。
library;

import 'package:core_design_system/core_design_system.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/core_providers.dart';
import '../../../core/ports.dart';
import '../../../core/value_objects.dart';
import '../../../shared/widgets/common.dart';
import '../../desktop/application/desktop_controller.dart';
import '../../reminder/application/reminder_controller.dart';
import '../../sync/application/sync_controller.dart';
import '../application/settings_controller.dart';
import '../domain/app_settings.dart';

final class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final update = ref.read(settingsControllerProvider.notifier).update;
    return DefaultTabController(
      length: 7,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TabBar(
            isScrollable: true,
            labelColor: context.appColors.brand,
            tabs: const <Tab>[
              Tab(text: '日历'),
              Tab(text: '单元格'),
              Tab(text: '字体和颜色'),
              Tab(text: '高级'),
              Tab(text: '壁纸'),
              Tab(text: '便签'),
              Tab(text: '关于'),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: TabBarView(
                children: <Widget>[
                  _scroll(<Widget>[
                    AppSectionCard(
                      title: '日历显示',
                      subtitle: '对应旧版「日历」设置页',
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          SettingDropdown<CalendarDisplayMode>(
                            label: '显示模式',
                            value: settings.displayMode,
                            items: CalendarDisplayMode.values
                                .map(
                                  (CalendarDisplayMode m) =>
                                      DropdownMenuItem<CalendarDisplayMode>(
                                        value: m,
                                        child: Text(m.label),
                                      ),
                                )
                                .toList(),
                            onChanged: (CalendarDisplayMode? value) => update(
                              (AppSettings s) => s.copyWith(displayMode: value),
                            ),
                          ),
                          SettingSlider(
                            label: '显示行数',
                            value: settings.maxRows.toDouble(),
                            min: 1,
                            max: 8,
                            divisions: 7,
                            display: '${settings.maxRows} 行',
                            onChanged: (double v) => update(
                              (AppSettings s) => s.copyWith(maxRows: v.round()),
                            ),
                          ),
                          SettingSlider(
                            label: '显示月份列',
                            value: settings.maxColumns.toDouble(),
                            min: 1,
                            max: 6,
                            divisions: 5,
                            display: '${settings.maxColumns} 列',
                            onChanged: (double v) => update(
                              (AppSettings s) =>
                                  s.copyWith(maxColumns: v.round()),
                            ),
                          ),
                          SettingDropdown<int>(
                            label: '周起始日',
                            value: settings.startOfWeek,
                            items: <DropdownMenuItem<int>>[
                              for (var d = 1; d <= 7; d++)
                                DropdownMenuItem<int>(
                                  value: d,
                                  child: Text('周${_weekLabel(d)}'),
                                ),
                            ],
                            onChanged: (int? value) => update(
                              (AppSettings s) => s.copyWith(startOfWeek: value),
                            ),
                          ),
                          SettingSwitch(
                            label: '显示透明玻璃效果',
                            value: settings.showGlassEffect,
                            onChanged: (bool v) => update(
                              (AppSettings s) => s.copyWith(showGlassEffect: v),
                            ),
                          ),
                          SettingSwitch(
                            label: '显示月间隔 / 周数 / 阴影 / 标题栏',
                            value: settings.showMonthInterval,
                            onChanged: (bool v) => update(
                              (AppSettings s) =>
                                  s.copyWith(showMonthInterval: v),
                            ),
                          ),
                          SettingSwitch(
                            label: '显示法定节假日',
                            value: settings.showHoliday,
                            onChanged: (bool v) => update(
                              (AppSettings s) => s.copyWith(showHoliday: v),
                            ),
                          ),
                          SettingSwitch(
                            label: '显示节日 / 农历 / 节气',
                            value: settings.showFestival,
                            onChanged: (bool v) => update(
                              (AppSettings s) => s.copyWith(showFestival: v),
                            ),
                          ),
                          SettingSwitch(
                            label: '显示农历',
                            value: settings.showLunar,
                            onChanged: (bool v) => update(
                              (AppSettings s) => s.copyWith(showLunar: v),
                            ),
                          ),
                          SettingSwitch(
                            label: '显示节气',
                            value: settings.showSolarTerms,
                            onChanged: (bool v) => update(
                              (AppSettings s) => s.copyWith(showSolarTerms: v),
                            ),
                          ),
                          SettingSwitch(
                            label: '显示黄历宜忌',
                            value: settings.showJiYi,
                            onChanged: (bool v) => update(
                              (AppSettings s) => s.copyWith(showJiYi: v),
                            ),
                          ),
                          SettingSwitch(
                            label: '显示周序号',
                            value: settings.showWeekNumber,
                            onChanged: (bool v) => update(
                              (AppSettings s) => s.copyWith(showWeekNumber: v),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ]),
                  _scroll(<Widget>[
                    AppSectionCard(
                      title: '单元格',
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          SettingDropdown<BulletStyle>(
                            label: '项目符号',
                            value: settings.bulletStyle,
                            items: BulletStyle.values
                                .map(
                                  (BulletStyle b) =>
                                      DropdownMenuItem<BulletStyle>(
                                        value: b,
                                        child: Text(b.label),
                                      ),
                                )
                                .toList(),
                            onChanged: (BulletStyle? value) => update(
                              (AppSettings s) => s.copyWith(bulletStyle: value),
                            ),
                          ),
                          SettingSlider(
                            label: '单元格间距',
                            value: settings.cellGap,
                            min: 0,
                            max: 12,
                            divisions: 12,
                            onChanged: (double v) => update(
                              (AppSettings s) => s.copyWith(cellGap: v),
                            ),
                          ),
                          SettingSlider(
                            label: '行间距',
                            value: settings.lineSpacing,
                            min: 0,
                            max: 16,
                            divisions: 16,
                            onChanged: (double v) => update(
                              (AppSettings s) => s.copyWith(lineSpacing: v),
                            ),
                          ),
                          SettingSwitch(
                            label: '完成项目排到最后',
                            value: settings.completeSort,
                            onChanged: (bool v) => update(
                              (AppSettings s) => s.copyWith(completeSort: v),
                            ),
                          ),
                          SettingSwitch(
                            label: '显示已完成项目',
                            value: settings.showCompleted,
                            onChanged: (bool v) => update(
                              (AppSettings s) => s.copyWith(showCompleted: v),
                            ),
                          ),
                          SettingSwitch(
                            label: '显示提醒时间',
                            value: settings.showReminderDate,
                            onChanged: (bool v) => update(
                              (AppSettings s) =>
                                  s.copyWith(showReminderDate: v),
                            ),
                          ),
                          SettingSwitch(
                            label: '未完成任务 30 天内自动顺延',
                            value: settings.autoDelay,
                            onChanged: (bool v) => update(
                              (AppSettings s) => s.copyWith(autoDelay: v),
                            ),
                          ),
                          SettingDropdown<SoundTone>(
                            label: '完成提示音',
                            value: settings.taskCompleteTone,
                            items: SoundTone.values
                                .map(
                                  (SoundTone t) => DropdownMenuItem<SoundTone>(
                                    value: t,
                                    child: Text(t.label),
                                  ),
                                )
                                .toList(),
                            onChanged: (SoundTone? value) => update(
                              (AppSettings s) =>
                                  s.copyWith(taskCompleteTone: value),
                            ),
                          ),
                          SettingDropdown<SoundTone>(
                            label: '提醒提示音',
                            value: settings.reminderTone,
                            items: SoundTone.values
                                .map(
                                  (SoundTone t) => DropdownMenuItem<SoundTone>(
                                    value: t,
                                    child: Text(t.label),
                                  ),
                                )
                                .toList(),
                            onChanged: (SoundTone? value) => update(
                              (AppSettings s) =>
                                  s.copyWith(reminderTone: value),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ]),
                  _scroll(<Widget>[
                    AppSectionCard(
                      title: '字体和颜色',
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          SettingSlider(
                            label: '日历字号',
                            value: settings.calendarFontSize,
                            min: 10,
                            max: 28,
                            divisions: 18,
                            onChanged: (double v) => update(
                              (AppSettings s) =>
                                  s.copyWith(calendarFontSize: v),
                            ),
                          ),
                          SettingSlider(
                            label: '内容字号',
                            value: settings.contentFontSize,
                            min: 10,
                            max: 24,
                            divisions: 14,
                            onChanged: (double v) => update(
                              (AppSettings s) => s.copyWith(contentFontSize: v),
                            ),
                          ),
                          SettingSlider(
                            label: '日历透明度',
                            value: settings.calendarTransparency,
                            min: 0.1,
                            max: 1,
                            divisions: 9,
                            onChanged: (double v) => update(
                              (AppSettings s) =>
                                  s.copyWith(calendarTransparency: v),
                            ),
                          ),
                          SettingSlider(
                            label: '倒数日透明度',
                            value: settings.countdownTransparency,
                            min: 0.1,
                            max: 1,
                            divisions: 9,
                            onChanged: (double v) => update(
                              (AppSettings s) =>
                                  s.copyWith(countdownTransparency: v),
                            ),
                          ),
                          SettingSlider(
                            label: '便签透明度',
                            value: settings.noteTransparency,
                            min: 0.1,
                            max: 1,
                            divisions: 9,
                            onChanged: (double v) => update(
                              (AppSettings s) =>
                                  s.copyWith(noteTransparency: v),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.sm,
                            ),
                            child: ColorSwatchPicker(
                              selected: EventColor(
                                settings.calendarBackgroundColor,
                              ),
                              onSelected: (EventColor color) => update(
                                (AppSettings s) => s.copyWith(
                                  calendarBackgroundColor: color.argb,
                                  calendarFontColor: color.argb,
                                  todayBorderColor: color.argb,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ]),
                  _scroll(<Widget>[
                    AppSectionCard(
                      title: '高级设置',
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          SettingDropdown<AppThemeMode>(
                            label: '主题',
                            value: settings.themeMode,
                            items: AppThemeMode.values
                                .map(
                                  (AppThemeMode m) =>
                                      DropdownMenuItem<AppThemeMode>(
                                        value: m,
                                        child: Text(m.label),
                                      ),
                                )
                                .toList(),
                            onChanged: (AppThemeMode? value) => update(
                              (AppSettings s) => s.copyWith(themeMode: value),
                            ),
                          ),
                          SettingDropdown<String>(
                            label: '语言',
                            value: settings.language,
                            items: const <DropdownMenuItem<String>>[
                              DropdownMenuItem<String>(
                                value: 'zh_CN',
                                child: Text('简体中文'),
                              ),
                              DropdownMenuItem<String>(
                                value: 'zh_TW',
                                child: Text('繁體中文'),
                              ),
                              DropdownMenuItem<String>(
                                value: 'en',
                                child: Text('English'),
                              ),
                            ],
                            onChanged: (String? value) => update(
                              (AppSettings s) => s.copyWith(language: value),
                            ),
                          ),
                          SettingDropdown<String>(
                            label: '搜索引擎',
                            value: settings.searchEngine,
                            items: const <DropdownMenuItem<String>>[
                              DropdownMenuItem<String>(
                                value: 'bing',
                                child: Text('必应'),
                              ),
                              DropdownMenuItem<String>(
                                value: 'baidu',
                                child: Text('百度'),
                              ),
                              DropdownMenuItem<String>(
                                value: 'google',
                                child: Text('Google'),
                              ),
                            ],
                            onChanged: (String? value) => update(
                              (AppSettings s) =>
                                  s.copyWith(searchEngine: value),
                            ),
                          ),
                          SettingSwitch(
                            label: '开机自启（随 Windows 启动）',
                            value: settings.startWithWindow,
                            onChanged: (bool v) => update(
                              (AppSettings s) => s.copyWith(startWithWindow: v),
                            ),
                          ),
                          SettingSwitch(
                            label: '自动检查更新',
                            value: settings.autoCheckUpdate,
                            onChanged: (bool v) => update(
                              (AppSettings s) => s.copyWith(autoCheckUpdate: v),
                            ),
                          ),
                          SettingSwitch(
                            label: '使用 IE 代理设置',
                            value: settings.useProxy,
                            onChanged: (bool v) => update(
                              (AppSettings s) => s.copyWith(useProxy: v),
                            ),
                          ),
                          SettingSwitch(
                            label: '显示热搜 / 浮动按钮',
                            value: settings.showHotSearch,
                            onChanged: (bool v) => update(
                              (AppSettings s) => s.copyWith(
                                showHotSearch: v,
                                showFloatingButton: v,
                              ),
                            ),
                          ),
                          SettingSwitch(
                            label: 'Crtl+H 显示隐藏 / 快捷键开关',
                            value: settings.showHideHotKey,
                            onChanged: (bool v) => update(
                              (AppSettings s) => s.copyWith(
                                showHideHotKey: v,
                                contentHotKey: v,
                                noteHotKey: v,
                                editCompleteHotKey: v,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ]),
                  _scroll(<Widget>[
                    AppSectionCard(
                      title: '桌面',
                      subtitle: '可编辑月历组件常驻桌面层；静态壁纸快照仅作可选备份',
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          SettingSwitch(
                            label: '在桌面上显示可编辑月历（真·桌面层）',
                            value: settings.desktopWidgetEnabled,
                            onChanged: (bool v) => update(
                              (AppSettings s) =>
                                  s.copyWith(desktopWidgetEnabled: v),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.sm,
                            ),
                            child: Text(
                              '组件常驻所有窗口下面，卡片内可直接输入/勾选/拖动，'
                              '卡片外点击穿透到桌面图标。',
                              style: TextStyle(
                                fontSize: AppTypography.caption,
                                color: context.appColors.textTertiary,
                              ),
                            ),
                          ),
                          SettingSwitch(
                            label: '（可选）生成静态壁纸快照',
                            value: settings.wallpaperAutoRender,
                            onChanged: (bool v) => update(
                              (AppSettings s) =>
                                  s.copyWith(wallpaperAutoRender: v),
                            ),
                          ),
                          SettingDropdown<WallpaperMode>(
                            label: '壁纸底图',
                            value: settings.wallpaperMode,
                            items: WallpaperMode.values
                                .map(
                                  (WallpaperMode m) =>
                                      DropdownMenuItem<WallpaperMode>(
                                        value: m,
                                        child: Text(m.label),
                                      ),
                                )
                                .toList(),
                            onChanged: (WallpaperMode? value) => update(
                              (AppSettings s) =>
                                  s.copyWith(wallpaperMode: value),
                            ),
                          ),
                          SettingDropdown<String>(
                            label: '图片适配',
                            value: settings.wallpaperFit,
                            items: const <DropdownMenuItem<String>>[
                              DropdownMenuItem<String>(
                                value: 'fill',
                                child: Text('填充（裁切铺满）'),
                              ),
                              DropdownMenuItem<String>(
                                value: 'fit',
                                child: Text('适应（完整显示）'),
                              ),
                              DropdownMenuItem<String>(
                                value: 'stretch',
                                child: Text('拉伸'),
                              ),
                            ],
                            onChanged: (String? value) => update(
                              (AppSettings s) =>
                                  s.copyWith(wallpaperFit: value),
                            ),
                          ),
                          SettingSlider(
                            label: '切换间隔（分钟）',
                            value: settings.wallpaperIntervalMinutes.toDouble(),
                            min: 5,
                            max: 120,
                            divisions: 23,
                            display: '${settings.wallpaperIntervalMinutes} 分钟',
                            onChanged: (double v) => update(
                              (AppSettings s) => s.copyWith(
                                wallpaperIntervalMinutes: v.round(),
                              ),
                            ),
                          ),
                          SettingSwitch(
                            label: '循环目录下全部图片',
                            value: settings.wallpaperShowAll,
                            onChanged: (bool v) => update(
                              (AppSettings s) =>
                                  s.copyWith(wallpaperShowAll: v),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  settings.wallpaperImageDirectory.isEmpty
                                      ? '未选择图片目录'
                                      : settings.wallpaperImageDirectory,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: AppTypography.caption,
                                    color: context.appColors.textTertiary,
                                  ),
                                ),
                              ),
                              OutlinedButton(
                                onPressed: () async {
                                  final directory = await ref
                                      .read(fileGatewayProvider)
                                      .pickDirectory();
                                  if (directory == null) return;
                                  await update(
                                    (AppSettings s) => s.copyWith(
                                      wallpaperImageDirectory: directory,
                                      wallpaperMode: WallpaperMode.rotation,
                                    ),
                                  );
                                },
                                child: const Text('选择图片目录'),
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              IconButton(
                                tooltip: '清除图片目录',
                                icon: const Icon(LucideIcons.x, size: 16),
                                onPressed: () => update(
                                  (AppSettings s) =>
                                      s.copyWith(wallpaperImageDirectory: ''),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Wrap(
                            spacing: AppSpacing.xs,
                            children: <Widget>[
                              FilledButton.icon(
                                onPressed: () => ref
                                    .read(desktopControllerProvider.notifier)
                                    .refreshWallpaper(),
                                icon: const Icon(LucideIcons.image, size: 16),
                                label: const Text('立即应用到桌面'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => ref
                                    .read(desktopControllerProvider.notifier)
                                    .restoreSystemWallpaper(),
                                icon: const Icon(LucideIcons.undo2, size: 16),
                                label: const Text('恢复系统原壁纸'),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            _wallpaperStatus(ref),
                            style: TextStyle(
                              fontSize: AppTypography.caption,
                              color: context.appColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ]),
                  _scroll(<Widget>[
                    AppSectionCard(
                      title: '便签',
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          SettingSlider(
                            label: '行间距',
                            value: settings.noteLineSpacing,
                            min: 0,
                            max: 16,
                            divisions: 16,
                            onChanged: (double v) => update(
                              (AppSettings s) => s.copyWith(noteLineSpacing: v),
                            ),
                          ),
                          SettingSwitch(
                            label: '显示所有便签',
                            value: settings.showAllNotes,
                            onChanged: (bool v) => update(
                              (AppSettings s) => s.copyWith(showAllNotes: v),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ]),
                  _scroll(<Widget>[
                    AppSectionCard(
                      title: '关于 / 数据',
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          ListTile(
                            leading: const Icon(LucideIcons.info),
                            title: const Text('企划星 · 桌面日历清单 1.0.0'),
                            subtitle: Text(
                              'Clean DDD + Riverpod · 本地存储：${ref.watch(appConfigProvider).getString('appName') ?? '默认'}',
                            ),
                          ),
                          ListTile(
                            leading: const Icon(LucideIcons.bell),
                            title: Text(
                              '已排程提醒 ${ref.watch(reminderControllerProvider).scheduled} 条',
                            ),
                            trailing: OutlinedButton(
                              onPressed: () => ref
                                  .read(reminderControllerProvider.notifier)
                                  .rescheduleAll(),
                              child: const Text('重排提醒'),
                            ),
                          ),
                          ListTile(
                            leading: const Icon(LucideIcons.cloudSync),
                            title: const Text('云同步'),
                            trailing: OutlinedButton(
                              onPressed: () => ref
                                  .read(syncControllerProvider.notifier)
                                  .syncNow(),
                              child: const Text('立即同步'),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          OutlinedButton(
                            onPressed: () => ref
                                .read(settingsControllerProvider.notifier)
                                .restoreDefaults(),
                            child: const Text('恢复默认设置'),
                          ),
                        ],
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _wallpaperStatus(WidgetRef ref) {
    final state = ref.watch(desktopControllerProvider);
    final parts = <String>[
      state.widgetActive ? '桌面组件：已显示（可编辑）' : '桌面组件：已隐藏',
      state.wallpaperApplied ? '静态壁纸：已生成' : '静态壁纸：未启用',
    ];
    if (state.wallpaperPath.isNotEmpty) parts.add(state.wallpaperPath);
    return parts.join(' · ');
  }

  Widget _scroll(List<Widget> children) => ListView(
    padding: const EdgeInsets.only(bottom: AppSpacing.huge),
    children: children,
  );

  String _weekLabel(int day) =>
      const <String>['一', '二', '三', '四', '五', '六', '日'][day - 1];
}
