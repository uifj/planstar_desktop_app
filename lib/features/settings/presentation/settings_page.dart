/// 设置页：七个页签，完整映射 `AppSettings` 的全部开关。
library;

import 'package:core_design_system/core_design_system.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/core_providers.dart';
import '../../../core/ports.dart';
import '../../../core/value_objects.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/common.dart';
import '../../desktop/application/desktop_controller.dart';
import '../../reminder/application/reminder_controller.dart';
import '../../sync/application/sync_controller.dart';
import '../application/settings_controller.dart';
import '../domain/app_settings.dart';

String _localizedStorageName(BuildContext context, String? configured) {
  final l10n = context.l10n;
  if (configured == null ||
      configured == '企划星 · 桌面日历清单' ||
      configured == l10n.appTitle) {
    return l10n.appTitle;
  }
  return configured;
}

final class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);
    Future<void> update(
      AppSettings Function(AppSettings current) transform,
    ) async {
      final result = await controller.update(transform);
      if (!context.mounted || result.isSuccess) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.settingsSaveFailed)));
    }

    return DefaultTabController(
      length: 7,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TabBar(
            isScrollable: true,
            labelColor: context.appColors.brand,
            tabs: <Tab>[
              Tab(text: l10n.settingsTabCalendar),
              Tab(text: l10n.settingsTabCell),
              Tab(text: l10n.settingsTabFontColors),
              Tab(text: l10n.settingsTabAdvanced),
              Tab(text: l10n.settingsTabWallpaper),
              Tab(text: l10n.settingsTabNotes),
              Tab(text: l10n.settingsTabAbout),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: TabBarView(
                children: <Widget>[
                  _scroll(<Widget>[
                    AppSectionCard(
                      title: l10n.settingsCalendarDisplay,
                      subtitle: l10n.settingsLegacyCalendarHint,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          SettingDropdown<CalendarDisplayMode>(
                            label: l10n.settingsDisplayMode,
                            value: settings.displayMode,
                            items: CalendarDisplayMode.values
                                .map(
                                  (CalendarDisplayMode m) =>
                                      DropdownMenuItem<CalendarDisplayMode>(
                                        value: m,
                                        child: Text(m.localizedLabel(l10n)),
                                      ),
                                )
                                .toList(),
                            onChanged: (CalendarDisplayMode? value) => update(
                              (AppSettings s) => s.copyWith(displayMode: value),
                            ),
                          ),
                          SettingSlider(
                            label: l10n.settingsVisibleRowsLabel,
                            value: settings.maxRows.toDouble(),
                            min: 1,
                            max: 8,
                            divisions: 7,
                            display: l10n.settingsVisibleRows(settings.maxRows),
                            onChanged: (double v) => update(
                              (AppSettings s) => s.copyWith(maxRows: v.round()),
                            ),
                          ),
                          SettingSlider(
                            label: l10n.settingsVisibleColumnsLabel,
                            value: settings.maxColumns.toDouble(),
                            min: 1,
                            max: 6,
                            divisions: 5,
                            display: l10n.settingsVisibleColumns(
                              settings.maxColumns,
                            ),
                            onChanged: (double v) => update(
                              (AppSettings s) =>
                                  s.copyWith(maxColumns: v.round()),
                            ),
                          ),
                          SettingDropdown<int>(
                            label: l10n.settingsStartOfWeek,
                            value: settings.startOfWeek,
                            items: <DropdownMenuItem<int>>[
                              for (var d = 1; d <= 7; d++)
                                DropdownMenuItem<int>(
                                  value: d,
                                  child: Text(
                                    l10n.settingsWeekday(weekdayShort(d, l10n)),
                                  ),
                                ),
                            ],
                            onChanged: (int? value) => update(
                              (AppSettings s) => s.copyWith(startOfWeek: value),
                            ),
                          ),
                          SettingSwitch(
                            label: l10n.settingsGlassEffect,
                            value: settings.showGlassEffect,
                            onChanged: (bool v) => update(
                              (AppSettings s) => s.copyWith(showGlassEffect: v),
                            ),
                          ),
                          SettingSwitch(
                            label: l10n.settingsMonthDetails,
                            value: settings.showMonthInterval,
                            onChanged: (bool v) => update(
                              (AppSettings s) =>
                                  s.copyWith(showMonthInterval: v),
                            ),
                          ),
                          SettingSwitch(
                            label: l10n.settingsHolidays,
                            value: settings.showHoliday,
                            onChanged: (bool v) => update(
                              (AppSettings s) => s.copyWith(showHoliday: v),
                            ),
                          ),
                          SettingSwitch(
                            label: l10n.settingsFestivalInfo,
                            value: settings.showFestival,
                            onChanged: (bool v) => update(
                              (AppSettings s) => s.copyWith(showFestival: v),
                            ),
                          ),
                          SettingSwitch(
                            label: l10n.settingsLunar,
                            value: settings.showLunar,
                            onChanged: (bool v) => update(
                              (AppSettings s) => s.copyWith(showLunar: v),
                            ),
                          ),
                          SettingSwitch(
                            label: l10n.settingsSolarTerms,
                            value: settings.showSolarTerms,
                            onChanged: (bool v) => update(
                              (AppSettings s) => s.copyWith(showSolarTerms: v),
                            ),
                          ),
                          SettingSwitch(
                            label: l10n.settingsWeekNumbers,
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
                      title: l10n.settingsCellSection,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          SettingDropdown<BulletStyle>(
                            label: l10n.settingsBulletStyle,
                            value: settings.bulletStyle,
                            items: BulletStyle.values
                                .map(
                                  (BulletStyle b) =>
                                      DropdownMenuItem<BulletStyle>(
                                        value: b,
                                        child: Text(b.localizedLabel(l10n)),
                                      ),
                                )
                                .toList(),
                            onChanged: (BulletStyle? value) => update(
                              (AppSettings s) => s.copyWith(bulletStyle: value),
                            ),
                          ),
                          SettingSlider(
                            label: l10n.settingsCellGap,
                            value: settings.cellGap,
                            min: 0,
                            max: 12,
                            divisions: 12,
                            onChanged: (double v) => update(
                              (AppSettings s) => s.copyWith(cellGap: v),
                            ),
                          ),
                          SettingSlider(
                            label: l10n.settingsLineSpacing,
                            value: settings.lineSpacing,
                            min: 0,
                            max: 16,
                            divisions: 16,
                            onChanged: (double v) => update(
                              (AppSettings s) => s.copyWith(lineSpacing: v),
                            ),
                          ),
                          SettingSwitch(
                            label: l10n.settingsCompletedLast,
                            value: settings.completeSort,
                            onChanged: (bool v) => update(
                              (AppSettings s) => s.copyWith(completeSort: v),
                            ),
                          ),
                          SettingSwitch(
                            label: l10n.settingsShowCompleted,
                            value: settings.showCompleted,
                            onChanged: (bool v) => update(
                              (AppSettings s) => s.copyWith(showCompleted: v),
                            ),
                          ),
                          SettingSwitch(
                            label: l10n.settingsShowReminderTime,
                            value: settings.showReminderDate,
                            onChanged: (bool v) => update(
                              (AppSettings s) =>
                                  s.copyWith(showReminderDate: v),
                            ),
                          ),
                          SettingDropdown<SoundTone>(
                            label: l10n.settingsTaskCompleteTone,
                            value: settings.taskCompleteTone,
                            items: SoundTone.values
                                .map(
                                  (SoundTone t) => DropdownMenuItem<SoundTone>(
                                    value: t,
                                    child: Text(t.localizedLabel(l10n)),
                                  ),
                                )
                                .toList(),
                            onChanged: (SoundTone? value) => update(
                              (AppSettings s) =>
                                  s.copyWith(taskCompleteTone: value),
                            ),
                          ),
                          SettingDropdown<SoundTone>(
                            label: l10n.settingsReminderTone,
                            value: settings.reminderTone,
                            items: SoundTone.values
                                .map(
                                  (SoundTone t) => DropdownMenuItem<SoundTone>(
                                    value: t,
                                    child: Text(t.localizedLabel(l10n)),
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
                      title: l10n.settingsFontColors,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          SettingSlider(
                            label: l10n.settingsCalendarFontSize,
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
                            label: l10n.settingsContentFontSize,
                            value: settings.contentFontSize,
                            min: 10,
                            max: 24,
                            divisions: 14,
                            onChanged: (double v) => update(
                              (AppSettings s) => s.copyWith(contentFontSize: v),
                            ),
                          ),
                          SettingSlider(
                            label: l10n.settingsCalendarOpacity,
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
                            label: l10n.settingsCountdownOpacity,
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
                            label: l10n.settingsNotesOpacity,
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
                            child: Semantics(
                              label: l10n.settingsCalendarColors,
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
                          ),
                        ],
                      ),
                    ),
                  ]),
                  _scroll(<Widget>[
                    AppSectionCard(
                      title: l10n.settingsAdvanced,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          SettingDropdown<AppThemeMode>(
                            label: l10n.settingsTheme,
                            value: settings.themeMode,
                            items: AppThemeMode.values
                                .map(
                                  (AppThemeMode m) =>
                                      DropdownMenuItem<AppThemeMode>(
                                        value: m,
                                        child: Text(m.localizedLabel(l10n)),
                                      ),
                                )
                                .toList(),
                            onChanged: (AppThemeMode? value) => update(
                              (AppSettings s) => s.copyWith(themeMode: value),
                            ),
                          ),
                          SettingDropdown<String>(
                            label: l10n.settingsLanguage,
                            value: localeForLanguage(
                              settings.language,
                            ).toLanguageTag(),
                            items: <DropdownMenuItem<String>>[
                              DropdownMenuItem<String>(
                                value: 'zh',
                                child: Text(l10n.languageChinese),
                              ),
                              DropdownMenuItem<String>(
                                value: 'en',
                                child: Text(l10n.languageEnglish),
                              ),
                            ],
                            onChanged: (String? value) => update(
                              (AppSettings s) => s.copyWith(language: value),
                            ),
                          ),
                          SettingDropdown<String>(
                            label: l10n.settingsSearchEngine,
                            value: settings.searchEngine,
                            items: <DropdownMenuItem<String>>[
                              DropdownMenuItem<String>(
                                value: 'bing',
                                child: Text(l10n.settingsSearchEngineBing),
                              ),
                              DropdownMenuItem<String>(
                                value: 'baidu',
                                child: Text(l10n.settingsSearchEngineBaidu),
                              ),
                              const DropdownMenuItem<String>(
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
                            label: l10n.settingsStartWithWindows,
                            value: settings.startWithWindow,
                            onChanged: (bool v) => update(
                              (AppSettings s) => s.copyWith(startWithWindow: v),
                            ),
                          ),
                          SettingSwitch(
                            label: l10n.settingsAutoCheckUpdates,
                            value: settings.autoCheckUpdate,
                            onChanged: (bool v) => update(
                              (AppSettings s) => s.copyWith(autoCheckUpdate: v),
                            ),
                          ),
                          SettingSwitch(
                            label: l10n.settingsIeProxy,
                            value: settings.useProxy,
                            onChanged: (bool v) => update(
                              (AppSettings s) => s.copyWith(useProxy: v),
                            ),
                          ),
                          SettingSwitch(
                            label: l10n.settingsHotSearchFloating,
                            value: settings.showHotSearch,
                            onChanged: (bool v) => update(
                              (AppSettings s) => s.copyWith(
                                showHotSearch: v,
                                showFloatingButton: v,
                              ),
                            ),
                          ),
                          SettingSwitch(
                            label: l10n.settingsHideHotkey,
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
                      title: l10n.settingsDesktop,
                      subtitle: l10n.settingsDesktopDescription,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          SettingSwitch(
                            label: l10n.settingsEditableDesktopCalendar,
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
                              l10n.settingsDesktopBehavior,
                              style: TextStyle(
                                fontSize: AppTypography.caption,
                                color: context.appColors.textTertiary,
                              ),
                            ),
                          ),
                          SettingSwitch(
                            label: l10n.settingsStaticWallpaperSnapshot,
                            value: settings.wallpaperAutoRender,
                            onChanged: (bool v) => update(
                              (AppSettings s) =>
                                  s.copyWith(wallpaperAutoRender: v),
                            ),
                          ),
                          SettingDropdown<WallpaperMode>(
                            label: l10n.settingsWallpaperImage,
                            value: settings.wallpaperMode,
                            items: WallpaperMode.values
                                .map(
                                  (WallpaperMode m) =>
                                      DropdownMenuItem<WallpaperMode>(
                                        value: m,
                                        child: Text(m.localizedLabel(l10n)),
                                      ),
                                )
                                .toList(),
                            onChanged: (WallpaperMode? value) => update(
                              (AppSettings s) =>
                                  s.copyWith(wallpaperMode: value),
                            ),
                          ),
                          SettingDropdown<String>(
                            label: l10n.settingsWallpaperFit,
                            value: settings.wallpaperFit,
                            items: <DropdownMenuItem<String>>[
                              DropdownMenuItem<String>(
                                value: 'fill',
                                child: Text(l10n.settingsWallpaperFitFill),
                              ),
                              DropdownMenuItem<String>(
                                value: 'fit',
                                child: Text(l10n.settingsWallpaperFitFit),
                              ),
                              DropdownMenuItem<String>(
                                value: 'stretch',
                                child: Text(l10n.settingsWallpaperFitStretch),
                              ),
                            ],
                            onChanged: (String? value) => update(
                              (AppSettings s) =>
                                  s.copyWith(wallpaperFit: value),
                            ),
                          ),
                          SettingSlider(
                            label: l10n.settingsWallpaperIntervalLabel,
                            value: settings.wallpaperIntervalMinutes.toDouble(),
                            min: 5,
                            max: 120,
                            divisions: 23,
                            display: l10n.settingsWallpaperIntervalMinutes(
                              settings.wallpaperIntervalMinutes,
                            ),
                            onChanged: (double v) => update(
                              (AppSettings s) => s.copyWith(
                                wallpaperIntervalMinutes: v.round(),
                              ),
                            ),
                          ),
                          SettingSwitch(
                            label: l10n.settingsWallpaperShowAll,
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
                                      ? l10n.settingsNoImageDirectory
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
                                child: Text(l10n.settingsChooseImageDirectory),
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              IconButton(
                                tooltip: l10n.settingsClearImageDirectory,
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
                                label: Text(l10n.settingsApplyToDesktop),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => ref
                                    .read(desktopControllerProvider.notifier)
                                    .restoreSystemWallpaper(),
                                icon: const Icon(LucideIcons.undo2, size: 16),
                                label: Text(
                                  l10n.settingsRestoreSystemWallpaper,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            _wallpaperStatus(context, ref),
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
                      title: l10n.settingsNotesSection,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          SettingSlider(
                            label: l10n.settingsNotesLineSpacing,
                            value: settings.noteLineSpacing,
                            min: 0,
                            max: 16,
                            divisions: 16,
                            onChanged: (double v) => update(
                              (AppSettings s) => s.copyWith(noteLineSpacing: v),
                            ),
                          ),
                          SettingSwitch(
                            label: l10n.settingsShowAllNotes,
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
                      title: l10n.settingsAboutData,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          ListTile(
                            leading: const Icon(LucideIcons.info),
                            title: Text(
                              l10n.settingsAboutAppVersion(
                                l10n.appTitle,
                                '1.0.0',
                              ),
                            ),
                            subtitle: Text(
                              l10n.settingsStorageName(
                                _localizedStorageName(
                                  context,
                                  ref
                                      .read(appConfigProvider)
                                      .getString('appName'),
                                ),
                              ),
                            ),
                          ),
                          ListTile(
                            leading: const Icon(LucideIcons.bell),
                            title: Text(
                              l10n.settingsScheduledReminders(
                                ref.watch(reminderControllerProvider).scheduled,
                              ),
                            ),
                            trailing: OutlinedButton(
                              onPressed: () => ref
                                  .read(reminderControllerProvider.notifier)
                                  .rescheduleAll(),
                              child: Text(l10n.settingsRescheduleReminders),
                            ),
                          ),
                          ListTile(
                            leading: const Icon(LucideIcons.cloudSync),
                            title: Text(l10n.settingsCloudSync),
                            trailing: OutlinedButton(
                              onPressed: () => ref
                                  .read(syncControllerProvider.notifier)
                                  .syncNow(),
                              child: Text(l10n.settingsSyncNow),
                            ),
                          ),
                          ListTile(
                            leading: const Icon(LucideIcons.refreshCw),
                            title: Text(l10n.settingsCheckUpdates),
                            trailing: OutlinedButton(
                              onPressed: () => ref
                                  .read(appUpdaterGatewayProvider)
                                  .checkForUpdates(),
                              child: Text(l10n.settingsCheckNow),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          OutlinedButton(
                            onPressed: () =>
                                update((_) => AppSettings.defaults),
                            child: Text(l10n.settingsRestoreDefaults),
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

  String _wallpaperStatus(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(desktopControllerProvider);
    final parts = <String>[
      state.widgetActive
          ? l10n.settingsDesktopWidgetVisible
          : l10n.settingsDesktopWidgetHidden,
      state.wallpaperApplied
          ? l10n.settingsStaticWallpaperGenerated
          : l10n.settingsStaticWallpaperNotEnabled,
    ];
    if (state.wallpaperPath.isNotEmpty) parts.add(state.wallpaperPath);
    return parts.join(' · ');
  }

  Widget _scroll(List<Widget> children) => ListView(
    padding: const EdgeInsets.only(bottom: AppSpacing.huge),
    children: children,
  );
}
