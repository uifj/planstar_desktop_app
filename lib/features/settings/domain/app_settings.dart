/// 设置聚合（值对象）：完整对齐旧版「日历 / 单元格 / 字体和颜色 / 高级 /
/// 壁纸 / 便签 / 关于」七个页签里的全部可配置项。
library;

import 'package:core/domain.dart';

import '../../../core/ports.dart' show SoundTone;

enum CalendarDisplayMode {
  floatingMonth('浮动月份'),
  fullMonth('完整月份'),
  fixedSingleLine('固定单行'),
  floatingSingleLine('浮动单行');

  const CalendarDisplayMode(this.label);

  final String label;

  bool get isSingleLine => this == fixedSingleLine || this == floatingSingleLine;

  static CalendarDisplayMode fromName(String? name) =>
      CalendarDisplayMode.values.firstWhere(
        (CalendarDisplayMode m) => m.name == name,
        orElse: () => CalendarDisplayMode.floatingMonth,
      );
}

enum BulletStyle {
  none('无'),
  number('数字编号'),
  dot('圆点');

  const BulletStyle(this.label);

  final String label;

  static BulletStyle fromName(String? name) => BulletStyle.values.firstWhere(
        (BulletStyle s) => s.name == name,
        orElse: () => BulletStyle.dot,
      );
}

enum AppThemeMode {
  system('跟随系统'),
  light('浅色'),
  dark('深色');

  const AppThemeMode(this.label);

  final String label;

  static AppThemeMode fromName(String? name) => AppThemeMode.values.firstWhere(
        (AppThemeMode m) => m.name == name,
        orElse: () => AppThemeMode.system,
      );
}

enum WallpaperMode {
  rotation('循环显示选择的图片'),
  desktopCapture('从桌面抓取图片'),
  solidColor('设置桌面背景颜色');

  const WallpaperMode(this.label);

  final String label;

  static WallpaperMode fromName(String? name) =>
      WallpaperMode.values.firstWhere(
        (WallpaperMode m) => m.name == name,
        orElse: () => WallpaperMode.solidColor,
      );
}

final class AppSettings extends ValueObject {
  const AppSettings({
    this.displayMode = CalendarDisplayMode.floatingMonth,
    this.maxRows = 6,
    this.maxColumns = 1,
    this.passedWeeks = 0,
    this.showGlassEffect = true,
    this.showMonthInterval = true,
    this.showWeekNumber = true,
    this.showShadow = false,
    this.showTitleBar = true,
    this.showHoliday = true,
    this.showFestival = true,
    this.showLunar = true,
    this.showSolarTerms = true,
    this.showJiYi = false,
    this.holidayArea = 'CN',
    this.bulletStyle = BulletStyle.dot,
    this.cellGap = 2,
    this.lineSpacing = 4,
    this.completeSort = false,
    this.showCompleted = true,
    this.showReminderDate = true,
    this.autoDelay = false,
    this.taskCompleteTone = SoundTone.ding,
    this.reminderTone = SoundTone.dong,
    this.calendarFontSize = 16,
    this.contentFontSize = 14,
    this.calendarFontColor = 0xFF1F2024,
    this.contentFontColor = 0xFF1F2024,
    this.calendarBackgroundColor = 0xFFFFFFFF,
    this.todayBorderColor = 0xFF1C66E5,
    this.titleButtonColor = 0xFF1C66E5,
    this.holidayTextColor = 0xFFE54545,
    this.lunarTextColor = 0xFF0ABF77,
    this.calendarTransparency = 1,
    this.countdownTransparency = 1,
    this.noteTransparency = 1,
    this.startOfWeek = 1,
    this.firstWeekOffset = 0,
    this.showRestDays = true,
    this.restDays = const <int>[6, 7],
    this.showHideHotKey = true,
    this.contentHotKey = true,
    this.noteHotKey = true,
    this.editCompleteHotKey = true,
    this.language = 'zh_CN',
    this.timezone = 'Asia/Shanghai',
    this.searchEngine = 'bing',
    this.showHotSearch = false,
    this.showFloatingButton = false,
    this.useProxy = false,
    this.startWithWindow = false,
    this.autoCheckUpdate = true,
    this.themeMode = AppThemeMode.system,
    this.wallpaperMode = WallpaperMode.solidColor,
    this.wallpaperIntervalMinutes = 30,
    this.wallpaperFit = 'fill',
    this.wallpaperShowAll = false,
    this.wallpaperImageDirectory = '',
    this.wallpaperAutoRender = false,
    this.desktopEmbedded = false,
    this.desktopWidgetEnabled = true,
    this.noteLineSpacing = 4,
    this.showAllNotes = true,
  });

  // ── 日历 ────────────────────────────────────────────────────────────────
  final CalendarDisplayMode displayMode;
  final int maxRows;
  final int maxColumns;
  final int passedWeeks;
  final bool showGlassEffect;
  final bool showMonthInterval;
  final bool showWeekNumber;
  final bool showShadow;
  final bool showTitleBar;
  final bool showHoliday;
  final bool showFestival;
  final bool showLunar;
  final bool showSolarTerms;
  final bool showJiYi;
  final String holidayArea;

  // ── 单元格 ──────────────────────────────────────────────────────────────
  final BulletStyle bulletStyle;
  final double cellGap;
  final double lineSpacing;
  final bool completeSort;
  final bool showCompleted;
  final bool showReminderDate;
  final bool autoDelay;
  final SoundTone taskCompleteTone;
  final SoundTone reminderTone;

  // ── 字体和颜色 ──────────────────────────────────────────────────────────
  final double calendarFontSize;
  final double contentFontSize;
  final int calendarFontColor;
  final int contentFontColor;
  final int calendarBackgroundColor;
  final int todayBorderColor;
  final int titleButtonColor;
  final int holidayTextColor;
  final int lunarTextColor;
  final double calendarTransparency;
  final double countdownTransparency;
  final double noteTransparency;

  // ── 高级 ────────────────────────────────────────────────────────────────
  final int startOfWeek;
  final int firstWeekOffset;
  final bool showRestDays;
  final List<int> restDays;
  final bool showHideHotKey;
  final bool contentHotKey;
  final bool noteHotKey;
  final bool editCompleteHotKey;
  final String language;
  final String timezone;
  final String searchEngine;
  final bool showHotSearch;
  final bool showFloatingButton;
  final bool useProxy;
  final bool startWithWindow;
  final bool autoCheckUpdate;
  final AppThemeMode themeMode;

  // ── 壁纸 / 便签 ─────────────────────────────────────────────────────────
  final WallpaperMode wallpaperMode;
  final int wallpaperIntervalMinutes;
  final String wallpaperFit;
  final bool wallpaperShowAll;

  /// 壁纸轮播目录（旧版「显示全部图片 / 循环显示选择的图片」）。
  final String wallpaperImageDirectory;

  /// 是否把月历渲染进系统壁纸（关掉后桌面恢复为普通壁纸）。
  final bool wallpaperAutoRender;

  /// 旧版 WorkerW 嵌入（已由桌面小组件取代，保留字段兼容旧配置）。
  final bool desktopEmbedded;

  /// 是否显示「贴在桌面上的可编辑月历小组件」（Vectra 式 overlay）。
  final bool desktopWidgetEnabled;
  final double noteLineSpacing;
  final bool showAllNotes;

  static const AppSettings defaults = AppSettings();

  AppSettings copyWith({
    CalendarDisplayMode? displayMode,
    int? maxRows,
    int? maxColumns,
    int? passedWeeks,
    bool? showGlassEffect,
    bool? showMonthInterval,
    bool? showWeekNumber,
    bool? showShadow,
    bool? showTitleBar,
    bool? showHoliday,
    bool? showFestival,
    bool? showLunar,
    bool? showSolarTerms,
    bool? showJiYi,
    String? holidayArea,
    BulletStyle? bulletStyle,
    double? cellGap,
    double? lineSpacing,
    bool? completeSort,
    bool? showCompleted,
    bool? showReminderDate,
    bool? autoDelay,
    SoundTone? taskCompleteTone,
    SoundTone? reminderTone,
    double? calendarFontSize,
    double? contentFontSize,
    int? calendarFontColor,
    int? contentFontColor,
    int? calendarBackgroundColor,
    int? todayBorderColor,
    int? titleButtonColor,
    int? holidayTextColor,
    int? lunarTextColor,
    double? calendarTransparency,
    double? countdownTransparency,
    double? noteTransparency,
    int? startOfWeek,
    int? firstWeekOffset,
    bool? showRestDays,
    List<int>? restDays,
    bool? showHideHotKey,
    bool? contentHotKey,
    bool? noteHotKey,
    bool? editCompleteHotKey,
    String? language,
    String? timezone,
    String? searchEngine,
    bool? showHotSearch,
    bool? showFloatingButton,
    bool? useProxy,
    bool? startWithWindow,
    bool? autoCheckUpdate,
    AppThemeMode? themeMode,
    WallpaperMode? wallpaperMode,
    int? wallpaperIntervalMinutes,
    String? wallpaperFit,
    bool? wallpaperShowAll,
    String? wallpaperImageDirectory,
    bool? wallpaperAutoRender,
    bool? desktopEmbedded,
    bool? desktopWidgetEnabled,
    double? noteLineSpacing,
    bool? showAllNotes,
  }) =>
      AppSettings(
        displayMode: displayMode ?? this.displayMode,
        maxRows: maxRows ?? this.maxRows,
        maxColumns: maxColumns ?? this.maxColumns,
        passedWeeks: passedWeeks ?? this.passedWeeks,
        showGlassEffect: showGlassEffect ?? this.showGlassEffect,
        showMonthInterval: showMonthInterval ?? this.showMonthInterval,
        showWeekNumber: showWeekNumber ?? this.showWeekNumber,
        showShadow: showShadow ?? this.showShadow,
        showTitleBar: showTitleBar ?? this.showTitleBar,
        showHoliday: showHoliday ?? this.showHoliday,
        showFestival: showFestival ?? this.showFestival,
        showLunar: showLunar ?? this.showLunar,
        showSolarTerms: showSolarTerms ?? this.showSolarTerms,
        showJiYi: showJiYi ?? this.showJiYi,
        holidayArea: holidayArea ?? this.holidayArea,
        bulletStyle: bulletStyle ?? this.bulletStyle,
        cellGap: cellGap ?? this.cellGap,
        lineSpacing: lineSpacing ?? this.lineSpacing,
        completeSort: completeSort ?? this.completeSort,
        showCompleted: showCompleted ?? this.showCompleted,
        showReminderDate: showReminderDate ?? this.showReminderDate,
        autoDelay: autoDelay ?? this.autoDelay,
        taskCompleteTone: taskCompleteTone ?? this.taskCompleteTone,
        reminderTone: reminderTone ?? this.reminderTone,
        calendarFontSize: calendarFontSize ?? this.calendarFontSize,
        contentFontSize: contentFontSize ?? this.contentFontSize,
        calendarFontColor: calendarFontColor ?? this.calendarFontColor,
        contentFontColor: contentFontColor ?? this.contentFontColor,
        calendarBackgroundColor:
            calendarBackgroundColor ?? this.calendarBackgroundColor,
        todayBorderColor: todayBorderColor ?? this.todayBorderColor,
        titleButtonColor: titleButtonColor ?? this.titleButtonColor,
        holidayTextColor: holidayTextColor ?? this.holidayTextColor,
        lunarTextColor: lunarTextColor ?? this.lunarTextColor,
        calendarTransparency:
            calendarTransparency ?? this.calendarTransparency,
        countdownTransparency:
            countdownTransparency ?? this.countdownTransparency,
        noteTransparency: noteTransparency ?? this.noteTransparency,
        startOfWeek: startOfWeek ?? this.startOfWeek,
        firstWeekOffset: firstWeekOffset ?? this.firstWeekOffset,
        showRestDays: showRestDays ?? this.showRestDays,
        restDays: restDays ?? this.restDays,
        showHideHotKey: showHideHotKey ?? this.showHideHotKey,
        contentHotKey: contentHotKey ?? this.contentHotKey,
        noteHotKey: noteHotKey ?? this.noteHotKey,
        editCompleteHotKey: editCompleteHotKey ?? this.editCompleteHotKey,
        language: language ?? this.language,
        timezone: timezone ?? this.timezone,
        searchEngine: searchEngine ?? this.searchEngine,
        showHotSearch: showHotSearch ?? this.showHotSearch,
        showFloatingButton: showFloatingButton ?? this.showFloatingButton,
        useProxy: useProxy ?? this.useProxy,
        startWithWindow: startWithWindow ?? this.startWithWindow,
        autoCheckUpdate: autoCheckUpdate ?? this.autoCheckUpdate,
        themeMode: themeMode ?? this.themeMode,
        wallpaperMode: wallpaperMode ?? this.wallpaperMode,
        wallpaperIntervalMinutes:
            wallpaperIntervalMinutes ?? this.wallpaperIntervalMinutes,
        wallpaperFit: wallpaperFit ?? this.wallpaperFit,
        wallpaperShowAll: wallpaperShowAll ?? this.wallpaperShowAll,
        wallpaperImageDirectory:
            wallpaperImageDirectory ?? this.wallpaperImageDirectory,
        wallpaperAutoRender:
            wallpaperAutoRender ?? this.wallpaperAutoRender,
        desktopEmbedded: desktopEmbedded ?? this.desktopEmbedded,
        desktopWidgetEnabled:
            desktopWidgetEnabled ?? this.desktopWidgetEnabled,
        noteLineSpacing: noteLineSpacing ?? this.noteLineSpacing,
        showAllNotes: showAllNotes ?? this.showAllNotes,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'displayMode': displayMode.name,
        'maxRows': maxRows,
        'maxColumns': maxColumns,
        'passedWeeks': passedWeeks,
        'showGlassEffect': showGlassEffect,
        'showMonthInterval': showMonthInterval,
        'showWeekNumber': showWeekNumber,
        'showShadow': showShadow,
        'showTitleBar': showTitleBar,
        'showHoliday': showHoliday,
        'showFestival': showFestival,
        'showLunar': showLunar,
        'showSolarTerms': showSolarTerms,
        'showJiYi': showJiYi,
        'holidayArea': holidayArea,
        'bulletStyle': bulletStyle.name,
        'cellGap': cellGap,
        'lineSpacing': lineSpacing,
        'completeSort': completeSort,
        'showCompleted': showCompleted,
        'showReminderDate': showReminderDate,
        'autoDelay': autoDelay,
        'taskCompleteTone': taskCompleteTone.name,
        'reminderTone': reminderTone.name,
        'calendarFontSize': calendarFontSize,
        'contentFontSize': contentFontSize,
        'calendarFontColor': calendarFontColor,
        'contentFontColor': contentFontColor,
        'calendarBackgroundColor': calendarBackgroundColor,
        'todayBorderColor': todayBorderColor,
        'titleButtonColor': titleButtonColor,
        'holidayTextColor': holidayTextColor,
        'lunarTextColor': lunarTextColor,
        'calendarTransparency': calendarTransparency,
        'countdownTransparency': countdownTransparency,
        'noteTransparency': noteTransparency,
        'startOfWeek': startOfWeek,
        'firstWeekOffset': firstWeekOffset,
        'showRestDays': showRestDays,
        'restDays': restDays,
        'showHideHotKey': showHideHotKey,
        'contentHotKey': contentHotKey,
        'noteHotKey': noteHotKey,
        'editCompleteHotKey': editCompleteHotKey,
        'language': language,
        'timezone': timezone,
        'searchEngine': searchEngine,
        'showHotSearch': showHotSearch,
        'showFloatingButton': showFloatingButton,
        'useProxy': useProxy,
        'startWithWindow': startWithWindow,
        'autoCheckUpdate': autoCheckUpdate,
        'themeMode': themeMode.name,
        'wallpaperMode': wallpaperMode.name,
        'wallpaperIntervalMinutes': wallpaperIntervalMinutes,
        'wallpaperFit': wallpaperFit,
        'wallpaperShowAll': wallpaperShowAll,
        'wallpaperImageDirectory': wallpaperImageDirectory,
        'wallpaperAutoRender': wallpaperAutoRender,
        'desktopEmbedded': desktopEmbedded,
        'desktopWidgetEnabled': desktopWidgetEnabled,
        'noteLineSpacing': noteLineSpacing,
        'showAllNotes': showAllNotes,
      };

  factory AppSettings.fromJson(Map<String, Object?> json) => AppSettings(
        displayMode: CalendarDisplayMode.fromName(
          json['displayMode'] as String?,
        ),
        maxRows: (json['maxRows'] as num?)?.toInt() ?? 6,
        maxColumns: (json['maxColumns'] as num?)?.toInt() ?? 1,
        passedWeeks: (json['passedWeeks'] as num?)?.toInt() ?? 0,
        showGlassEffect: json['showGlassEffect'] as bool? ?? true,
        showMonthInterval: json['showMonthInterval'] as bool? ?? true,
        showWeekNumber: json['showWeekNumber'] as bool? ?? true,
        showShadow: json['showShadow'] as bool? ?? false,
        showTitleBar: json['showTitleBar'] as bool? ?? true,
        showHoliday: json['showHoliday'] as bool? ?? true,
        showFestival: json['showFestival'] as bool? ?? true,
        showLunar: json['showLunar'] as bool? ?? true,
        showSolarTerms: json['showSolarTerms'] as bool? ?? true,
        showJiYi: json['showJiYi'] as bool? ?? false,
        holidayArea: json['holidayArea'] as String? ?? 'CN',
        bulletStyle: BulletStyle.fromName(json['bulletStyle'] as String?),
        cellGap: (json['cellGap'] as num?)?.toDouble() ?? 2,
        lineSpacing: (json['lineSpacing'] as num?)?.toDouble() ?? 4,
        completeSort: json['completeSort'] as bool? ?? false,
        showCompleted: json['showCompleted'] as bool? ?? true,
        showReminderDate: json['showReminderDate'] as bool? ?? true,
        autoDelay: json['autoDelay'] as bool? ?? false,
        taskCompleteTone: SoundTone.fromName(
          json['taskCompleteTone'] as String?,
        ),
        reminderTone: SoundTone.fromName(json['reminderTone'] as String?),
        calendarFontSize:
            (json['calendarFontSize'] as num?)?.toDouble() ?? 16,
        contentFontSize:
            (json['contentFontSize'] as num?)?.toDouble() ?? 14,
        calendarFontColor:
            (json['calendarFontColor'] as num?)?.toInt() ?? 0xFF1F2024,
        contentFontColor:
            (json['contentFontColor'] as num?)?.toInt() ?? 0xFF1F2024,
        calendarBackgroundColor:
            (json['calendarBackgroundColor'] as num?)?.toInt() ??
                0xFFFFFFFF,
        todayBorderColor:
            (json['todayBorderColor'] as num?)?.toInt() ?? 0xFF1C66E5,
        titleButtonColor:
            (json['titleButtonColor'] as num?)?.toInt() ?? 0xFF1C66E5,
        holidayTextColor:
            (json['holidayTextColor'] as num?)?.toInt() ?? 0xFFE54545,
        lunarTextColor:
            (json['lunarTextColor'] as num?)?.toInt() ?? 0xFF0ABF77,
        calendarTransparency:
            (json['calendarTransparency'] as num?)?.toDouble() ?? 1,
        countdownTransparency:
            (json['countdownTransparency'] as num?)?.toDouble() ?? 1,
        noteTransparency:
            (json['noteTransparency'] as num?)?.toDouble() ?? 1,
        startOfWeek: (json['startOfWeek'] as num?)?.toInt() ?? 1,
        firstWeekOffset: (json['firstWeekOffset'] as num?)?.toInt() ?? 0,
        showRestDays: json['showRestDays'] as bool? ?? true,
        restDays: (json['restDays'] as List?)?.cast<int>() ??
            const <int>[6, 7],
        showHideHotKey: json['showHideHotKey'] as bool? ?? true,
        contentHotKey: json['contentHotKey'] as bool? ?? true,
        noteHotKey: json['noteHotKey'] as bool? ?? true,
        editCompleteHotKey: json['editCompleteHotKey'] as bool? ?? true,
        language: json['language'] as String? ?? 'zh_CN',
        timezone: json['timezone'] as String? ?? 'Asia/Shanghai',
        searchEngine: json['searchEngine'] as String? ?? 'bing',
        showHotSearch: json['showHotSearch'] as bool? ?? false,
        showFloatingButton: json['showFloatingButton'] as bool? ?? false,
        useProxy: json['useProxy'] as bool? ?? false,
        startWithWindow: json['startWithWindow'] as bool? ?? false,
        autoCheckUpdate: json['autoCheckUpdate'] as bool? ?? true,
        themeMode: AppThemeMode.fromName(json['themeMode'] as String?),
        wallpaperMode: WallpaperMode.fromName(
          json['wallpaperMode'] as String?,
        ),
        wallpaperIntervalMinutes:
            (json['wallpaperIntervalMinutes'] as num?)?.toInt() ?? 30,
        wallpaperFit: json['wallpaperFit'] as String? ?? 'fill',
        wallpaperShowAll: json['wallpaperShowAll'] as bool? ?? false,
        wallpaperImageDirectory:
            json['wallpaperImageDirectory'] as String? ?? '',
        wallpaperAutoRender:
            json['wallpaperAutoRender'] as bool? ?? false,
        desktopEmbedded: json['desktopEmbedded'] as bool? ?? false,
        desktopWidgetEnabled:
            json['desktopWidgetEnabled'] as bool? ?? true,
        noteLineSpacing:
            (json['noteLineSpacing'] as num?)?.toDouble() ?? 4,
        showAllNotes: json['showAllNotes'] as bool? ?? true,
      );

  /// 全部字段参与相等判断：直接用序列化结果做深比较，新增字段不会漏比。
  @override
  List<Object?> get props => <Object?>[toJson()];
}
