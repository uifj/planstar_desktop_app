// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get accountAutoSyncHourly => '每个整点自动同步';

  @override
  String get accountCloudSyncSubtitle => '记录变更 → 手动 / 自动同步 → 状态回写';

  @override
  String get accountCloudSyncTitle => '云同步';

  @override
  String accountLastSyncAt(String dateTime) {
    return '上次同步：$dateTime';
  }

  @override
  String get accountLoginOrRegister => '登录 / 注册';

  @override
  String get accountLogout => '退出登录';

  @override
  String get accountManualSync => '手动同步';

  @override
  String get accountNeverSynced => '从未同步';

  @override
  String accountPendingChanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '待同步变更 $count 条',
      one: '待同步变更 1 条',
      zero: '没有待同步变更',
    );
    return '$_temp0';
  }

  @override
  String get accountStatusFailure => '同步失败';

  @override
  String get accountStatusIdle => '空闲';

  @override
  String get accountStatusSuccess => '同步成功';

  @override
  String get accountStatusSyncing => '同步中';

  @override
  String get accountSubtitle => '登录后可以同步和备份日历清单';

  @override
  String get accountTitle => '账号';

  @override
  String get appTitle => '企划星 · 桌面日历清单';

  @override
  String get bulletStyleDot => '圆点';

  @override
  String get bulletStyleNone => '无';

  @override
  String get bulletStyleNumber => '数字编号';

  @override
  String get calendarAddCountdown => '添加倒数日';

  @override
  String get calendarAddLine => '添加一行';

  @override
  String get calendarAllColors => '全部颜色';

  @override
  String get calendarCellColor => '单元格颜色';

  @override
  String get calendarCellEditorEmptyHint => '双击单元格或直接添加一行开始记录';

  @override
  String get calendarClearAction => '清空';

  @override
  String calendarClearConfirmMessage(String target) {
    return '将清空 $target 的全部内容，此操作不可撤销。';
  }

  @override
  String get calendarClearConfirmTitle => '确认清空';

  @override
  String get calendarClearDayContent => '清空本日内容';

  @override
  String get calendarColorLabel => '颜色';

  @override
  String get calendarColorPickerDescription => '文字颜色 / 单元格颜色';

  @override
  String get calendarColorPickerTitle => '选择颜色';

  @override
  String calendarColorValue(String color) {
    return '颜色 $color';
  }

  @override
  String get calendarContentHint => '输入任务或提醒内容';

  @override
  String get calendarContentLabel => '内容';

  @override
  String get calendarCopyDayContent => '复制本日内容';

  @override
  String get calendarCountdownAdded => '已添加倒数日';

  @override
  String calendarDateWithWeekday(String date, String weekday) {
    return '$date $weekday';
  }

  @override
  String get calendarDayContent => '本日内容';

  @override
  String get calendarDayContentCopied => '已复制本日内容';

  @override
  String get calendarDeleteRecurringEvent => '删除重复任务…';

  @override
  String get calendarDeleteRecurringEventTitle => '删除重复任务';

  @override
  String get calendarDeleteScopeAll => '删除所有事件';

  @override
  String get calendarDeleteScopeCurrent => '仅删除当前事件';

  @override
  String get calendarDeleteScopeCurrentAndFuture => '删除当前及未来全部事件';

  @override
  String get calendarDeleteScopeRememberChoice => '所有冲突都选择该方法';

  @override
  String get calendarDisplayModeFixedSingleLine => '固定单行';

  @override
  String get calendarDisplayModeFloatingMonth => '浮动月份';

  @override
  String get calendarDisplayModeFloatingSingleLine => '浮动单行';

  @override
  String get calendarDisplayModeFullMonth => '完整月份';

  @override
  String get calendarEditDayContent => '编辑本日内容';

  @override
  String get calendarEditTaskOrReminder => '编辑任务 / 提醒';

  @override
  String get calendarEventTypeCountdown => '倒数纪念日';

  @override
  String get calendarEventTypeReminder => '提醒';

  @override
  String get calendarEventTypeSubscription => '订阅推送';

  @override
  String get calendarEventTypeTask => '重复任务';

  @override
  String get calendarIntervalLabel => '间隔';

  @override
  String get calendarLineTextColor => '行文字颜色';

  @override
  String get calendarMakeRecurringTask => '设为重复任务';

  @override
  String get calendarMakeupWorkdayBadge => '班';

  @override
  String get calendarMarkEventComplete => '标记任务为已完成';

  @override
  String get calendarMarkEventIncomplete => '标记任务为未完成';

  @override
  String get calendarMarkLineComplete => '标记为已完成';

  @override
  String get calendarMarkLineIncomplete => '标记为未完成';

  @override
  String get calendarNewTask => '新建任务';

  @override
  String get calendarNewTaskOrReminder => '新建任务 / 提醒';

  @override
  String get calendarNextMonth => '下个月';

  @override
  String get calendarNoTasksOnDay => '本日没有任务';

  @override
  String get calendarOpenCountdownCard => '点击打开桌面卡片';

  @override
  String get calendarOpenDesktopNote => '打开桌面便签';

  @override
  String get calendarPasteToDay => '粘贴到本日';

  @override
  String get calendarPreviousMonth => '上个月';

  @override
  String get calendarRecurrenceCustomDay => '自定义日重复';

  @override
  String get calendarRecurrenceCustomMonthDay => '自定义月重复（按日期）';

  @override
  String get calendarRecurrenceCustomMonthWeek => '自定义月重复（按星期）';

  @override
  String get calendarRecurrenceCustomWeek => '自定义周重复';

  @override
  String get calendarRecurrenceCustomYear => '自定义年重复';

  @override
  String get calendarRecurrenceDaily => '日重复';

  @override
  String get calendarRecurrenceEbbinghaus => '艾宾浩斯记忆曲线';

  @override
  String get calendarRecurrenceLegalWorkday => '法定工作日重复';

  @override
  String get calendarRecurrenceLunarYearly => '农历年重复';

  @override
  String get calendarRecurrenceMonthLastDay => '每月最后一天';

  @override
  String get calendarRecurrenceMonthly => '月重复';

  @override
  String get calendarRecurrenceNone => '不重复';

  @override
  String get calendarRecurrenceQuarterly => '每季度';

  @override
  String get calendarRecurrenceRule => '重复规则';

  @override
  String get calendarRecurrenceWeekly => '周重复';

  @override
  String get calendarRecurrenceWorkday => '工作日重复';

  @override
  String get calendarRecurrenceYearly => '年重复';

  @override
  String get calendarReminderCustom => '自定义';

  @override
  String calendarReminderDaysBefore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# 天前',
    );
    return '$_temp0';
  }

  @override
  String get calendarReminderLabel => '提醒';

  @override
  String get calendarReminderSameDay => '当天';

  @override
  String get calendarRestDayBadge => '休';

  @override
  String get calendarSetCellColor => '设置单元格颜色';

  @override
  String get calendarTextColor => '文字颜色';

  @override
  String get calendarToday => '今天';

  @override
  String get calendarTransparentColor => '透明';

  @override
  String get calendarTypeLabel => '类型';

  @override
  String get calendarWechatNotification => '微信通知';

  @override
  String calendarWeekNumberAccessibility(int week) {
    return '第 $week 周';
  }

  @override
  String get calendarWeekdayFriday => '五';

  @override
  String get calendarWeekdayLongFriday => '星期五';

  @override
  String get calendarWeekdayLongMonday => '星期一';

  @override
  String get calendarWeekdayLongSaturday => '星期六';

  @override
  String get calendarWeekdayLongSunday => '星期日';

  @override
  String get calendarWeekdayLongThursday => '星期四';

  @override
  String get calendarWeekdayLongTuesday => '星期二';

  @override
  String get calendarWeekdayLongWednesday => '星期三';

  @override
  String get calendarWeekdayMonday => '一';

  @override
  String get calendarWeekdaySaturday => '六';

  @override
  String get calendarWeekdaySunday => '日';

  @override
  String get calendarWeekdayThursday => '四';

  @override
  String get calendarWeekdayTuesday => '二';

  @override
  String get calendarWeekdayWednesday => '三';

  @override
  String get commonAdd => '添加';

  @override
  String get commonAllColors => '全部颜色';

  @override
  String get commonCancel => '取消';

  @override
  String get commonClose => '关闭';

  @override
  String get commonColorPickerHint => '文字颜色 / 单元格颜色';

  @override
  String get commonCountdowns => '倒数日';

  @override
  String get commonDelete => '删除';

  @override
  String get commonMaximize => '最大化';

  @override
  String get commonMinimize => '最小化';

  @override
  String get commonNoCountdowns => '暂无倒数日';

  @override
  String get commonNotes => '便签';

  @override
  String get commonRecentColors => '最近使用';

  @override
  String get commonRetry => '重试';

  @override
  String get commonSave => '保存';

  @override
  String get commonSettings => '设置';

  @override
  String get commonSyncNow => '手动同步';

  @override
  String get commonToday => '今天';

  @override
  String countdownBirthdayAge(int age) {
    return '$age岁生日';
  }

  @override
  String get countdownCreate => '新建倒数日';

  @override
  String get countdownCreated => '创建';

  @override
  String countdownDaysRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '还有$count天',
    );
    return '$_temp0';
  }

  @override
  String countdownDaysSince(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已过$count天',
    );
    return '$_temp0';
  }

  @override
  String countdownDeleteTooltip(String title) {
    return '删除倒数日：$title';
  }

  @override
  String get countdownEmptyHint => '支持倒计时、累计日、生日、纪念日';

  @override
  String get countdownEmptyTitle => '暂无倒数日';

  @override
  String countdownExpiredDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '过期$count天',
    );
    return '$_temp0';
  }

  @override
  String countdownLoadFailed(String message) {
    return '加载倒数日失败：$message';
  }

  @override
  String get countdownNameField => '名称';

  @override
  String get countdownOpenDesktopCard => '打开桌面卡片';

  @override
  String get countdownShowTypeBoth => '两者都显示';

  @override
  String get countdownShowTypeCalendarBottom => '日历底部';

  @override
  String get countdownShowTypeDesktopCard => '桌面卡片';

  @override
  String get countdownShowTypeField => '显示位置';

  @override
  String countdownTargetDateValue(String date) {
    return '目标日期：$date';
  }

  @override
  String countdownTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '倒数日（$count）',
    );
    return '$_temp0';
  }

  @override
  String get countdownTypeBirthday => '生日';

  @override
  String get countdownTypeCustom => '倒计时';

  @override
  String get countdownTypeExam => '考试';

  @override
  String get countdownTypeFestival => '节日';

  @override
  String get countdownTypeField => '类型';

  @override
  String get countdownTypeMemorial => '纪念日';

  @override
  String get countdownWindowTitle => '倒数日';

  @override
  String desktopWidgetFailed(String message) {
    return '桌面小组件启动失败：$message';
  }

  @override
  String get desktopWidgetHidden => '桌面可编辑月历已隐藏';

  @override
  String get desktopWidgetShown => '桌面可编辑月历已显示';

  @override
  String get desktopWidgetTitle => '桌面日历清单';

  @override
  String get exportCancelled => '已取消导出';

  @override
  String get exportCellType => '日历清单';

  @override
  String get exportColumnColor => '颜色';

  @override
  String get exportColumnContent => '内容';

  @override
  String get exportColumnDate => '日期';

  @override
  String get exportColumnStatus => '状态';

  @override
  String get exportColumnType => '类型';

  @override
  String get exportCompleted => '已完成';

  @override
  String exportFailed(String message) {
    return '导出失败：$message';
  }

  @override
  String get exportIncomplete => '未完成';

  @override
  String get exportPreparing => '正在准备导出…';

  @override
  String exportSuccess(String path) {
    return '导出成功：$path';
  }

  @override
  String exportTextTitle(String date) {
    return '企划星日历清单 · 导出于 $date';
  }

  @override
  String get failureGeneric => '操作未能完成，请稍后重试。';

  @override
  String get failureNetwork => '网络连接失败，请检查网络后重试。';

  @override
  String get failureOffline => '当前处于离线状态，请检查网络后重试。';

  @override
  String get failureTimeout => '请求超时，请稍后重试。';

  @override
  String get failureAuthentication => '登录状态无效，请重新登录。';

  @override
  String get failureSessionExpired => '登录已过期，请重新登录。';

  @override
  String get failureForbidden => '没有执行此操作的权限。';

  @override
  String get failureBadRequest => '请求内容有误，请检查后重试。';

  @override
  String get failureNotFound => '未找到所需内容，它可能已被删除。';

  @override
  String get failureConflict => '数据状态已变化，请刷新后重试。';

  @override
  String get failureRateLimit => '操作过于频繁，请稍后再试。';

  @override
  String get failureServer => '服务暂时不可用，请稍后重试。';

  @override
  String get failureData => '数据读取失败，请稍后重试。';

  @override
  String get failureValidation => '输入内容不符合要求，请检查后重试。';

  @override
  String get failureCancelled => '操作已取消。';

  @override
  String get failureCertificate => '安全连接校验失败，请检查网络或证书。';

  @override
  String get failureLocalData => '本地数据读取失败，请稍后重试。';

  @override
  String get failureFile => '文件操作失败，请检查文件后重试。';

  @override
  String get failurePlatform => '当前设备操作失败，请稍后重试。';

  @override
  String get historyAuthorLocal => '本机';

  @override
  String get historyClearAction => '清空历史';

  @override
  String get historyClearConfirmMessage => '将永久删除所有历史记录，此操作不可撤销。';

  @override
  String get historyClearConfirmTitle => '清空历史记录？';

  @override
  String get historyClearedContent => '（清空内容）';

  @override
  String historyDateAt(String date, String time) {
    return '$date $time';
  }

  @override
  String get historyDeleteConfirmMessage => '删除后无法恢复这条历史记录。';

  @override
  String get historyDeleteConfirmTitle => '删除这条历史记录？';

  @override
  String get historyDeleteRecordTooltip => '删除这条记录';

  @override
  String get historyEmptyHint => '编辑日历格子或便签会自动留痕';

  @override
  String get historyEmptyTitle => '暂无历史记录';

  @override
  String historyEntryMetadata(String relativeTime, String kind, String target) {
    return '$relativeTime · $kind · $target';
  }

  @override
  String get historyFilterAll => '全部';

  @override
  String get historyJustNow => '刚刚';

  @override
  String get historyKindCell => '日历格子';

  @override
  String get historyKindNote => '便签';

  @override
  String historyLoadFailed(String message) {
    return '加载失败：$message';
  }

  @override
  String historyMinutesAgo(int count, String time) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 分钟前 · $time',
    );
    return '$_temp0';
  }

  @override
  String historyNewerContentMessage(String date) {
    return '$date 的当前内容比这条历史更新，恢复会覆盖较新内容。确定继续吗？';
  }

  @override
  String get historyNewerContentTitle => '当前内容更新';

  @override
  String get historyNoMatchesHint => '换个关键词或筛选条件试试';

  @override
  String get historyNoMatchesTitle => '没有匹配的历史';

  @override
  String get historyNoteRemoved => '删除便签';

  @override
  String historyNoteRemovedWithTitle(String title) {
    return '删除便签：$title';
  }

  @override
  String historyNoteWithSummary(String title, String summary) {
    return '$title：$summary';
  }

  @override
  String get historyRestoreAction => '恢复';

  @override
  String get historyRestoreCancelled => '当前内容更新，已取消恢复';

  @override
  String get historyRestoreFailed => '恢复失败，请稍后重试';

  @override
  String get historyRestoreInvalid => '这条记录无法恢复';

  @override
  String historyRestoreMessage(String date) {
    return '将 $date 的格子内容恢复为这条历史快照？';
  }

  @override
  String get historyRestoreTitle => '恢复历史内容';

  @override
  String historyRestoredMessage(String date) {
    return '已恢复到 $date';
  }

  @override
  String get historySearchHint => '搜索历史内容…';

  @override
  String historyTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '历史记录（$count）',
    );
    return '$_temp0';
  }

  @override
  String historyTodayAt(String time) {
    return '今天 $time';
  }

  @override
  String historyVisibleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '显示 $count 条',
    );
    return '$_temp0';
  }

  @override
  String get historyYesterday => '昨天';

  @override
  String historyYesterdayAt(String time) {
    return '昨天 $time';
  }

  @override
  String get importCancelled => '已取消导入';

  @override
  String get importChoosing => '请选择要导入的文件…';

  @override
  String importFailed(String message) {
    return '导入失败：$message';
  }

  @override
  String get importInvalidFormat => '导入失败：文件格式不正确';

  @override
  String importSummary(int imported, int conflicts) {
    return '导入完成，共 $imported 条记录，发现 $conflicts 个日期冲突。';
  }

  @override
  String get languageChinese => '简体中文';

  @override
  String get languageEnglish => '英语';

  @override
  String get navAccountSync => '账号同步';

  @override
  String get navAnonymousAccount => '未登录';

  @override
  String ideaCreatedAt(String date) {
    return '创建于 $date';
  }

  @override
  String ideaCreator(String name) {
    return '由 $name 发起';
  }

  @override
  String get ideaDetailTitle => '企划详情';

  @override
  String get ideaEmptyHint => '下拉刷新或稍后重试';

  @override
  String get ideaEmptyTitle => '暂时没有新的企划';

  @override
  String get ideaGallery => '企划图片';

  @override
  String get ideaLoadMore => '加载更多';

  @override
  String get ideaNav => '企划';

  @override
  String get ideaNoDescription => '发起人暂未填写详细介绍';

  @override
  String get ideaNoReasonStats => '暂无反对理由统计';

  @override
  String ideaOpposeCount(int count) {
    return '反对 $count';
  }

  @override
  String get ideaOpposeReasonHint => '补充说明（选填，最多 100 字）';

  @override
  String get ideaOpposeReasonNotEnoughInfo => '信息不够充分';

  @override
  String get ideaOpposeReasonNotExecutable => '方案难以执行';

  @override
  String get ideaOpposeReasonNotInterested => '不感兴趣';

  @override
  String get ideaOpposeReasonOther => '其他原因';

  @override
  String get ideaOpposeReasonTooManySimilar => '同类企划太多';

  @override
  String get ideaOpposeReasonUnreasonablePricing => '预期定价不合理';

  @override
  String get ideaOpposeSubmit => '提交反对';

  @override
  String get ideaOpposeSubtitle => '请选择主要原因，帮助发起人了解你的顾虑';

  @override
  String get ideaOpposeSuccess => '已提交你的反对意见';

  @override
  String get ideaOtherReasonRequired => '选择“其他原因”时请填写说明';

  @override
  String get ideaReasonCountsTitle => '反对理由';

  @override
  String get ideaRefresh => '刷新';

  @override
  String get ideaSubtitle => '发现新创意，表达你的支持或顾虑；投票不产生扣费';

  @override
  String get ideaSupport => '支持';

  @override
  String ideaSupportCount(int count) {
    return '支持 $count';
  }

  @override
  String get ideaSupportDisclaimer => '档位仅记录未来支持意愿，不会扣除星币，也不会创建订单。';

  @override
  String ideaSupportRate(int percent) {
    return '支持率 $percent%';
  }

  @override
  String get ideaSupportReasonHint => '说说你的期待（选填，最多 60 字）';

  @override
  String get ideaSupportReasonCreative => '创意很棒';

  @override
  String get ideaSupportReasonJoin => '愿意参与';

  @override
  String get ideaSupportReasonLaunch => '期待上线';

  @override
  String get ideaSupportSubmit => '提交支持';

  @override
  String get ideaSupportSubtitle => '选择未来愿意支持的档位，仅表达意愿';

  @override
  String get ideaSupportSuccess => '已记录你的支持意愿';

  @override
  String ideaTierCount(int tier, int count) {
    return '$tier 星币意愿：$count 人';
  }

  @override
  String get ideaTierDistributionTitle => '支持意愿分布';

  @override
  String get ideaTitle => '创意企划';

  @override
  String get ideaUntitled => '未命名企划';

  @override
  String get ideaUnknownCreator => '匿名发起人';

  @override
  String get ideaViewDetail => '查看详情';

  @override
  String get ideaVoteAlready => '已记录你的表态';

  @override
  String get ideaVoteLoginRequired => '请先登录后再表态';

  @override
  String get ideaVoteMyOppose => '我已提交反对意见';

  @override
  String ideaVoteMySupport(int tier) {
    return '我已支持：$tier 星币意愿';
  }

  @override
  String get ideaVoting => '提交中…';

  @override
  String get navCalendar => '日历';

  @override
  String get navGoToToday => '返回今天';

  @override
  String get navHideToTray => '隐藏到托盘（右键托盘图标可退出）';

  @override
  String get navHistory => '历史';

  @override
  String get navNextMonth => '下个月';

  @override
  String get navPreviousMonth => '上个月';

  @override
  String navReminderStatus(int count) {
    return '提醒（已安排 $count 条）';
  }

  @override
  String get navSearch => '搜索';

  @override
  String get navSearchAction => '搜索日历与清单';

  @override
  String get navToggleTheme => '切换主题';

  @override
  String get navTransfer => '导入导出';

  @override
  String get noteTitle => '便签';

  @override
  String get notesAddLine => '添加一行';

  @override
  String get notesBackgroundColor => '背景颜色';

  @override
  String get notesDeleteLine => '删除此行';

  @override
  String get notesEditNote => '编辑便签';

  @override
  String get notesEditorMissing => '便签不存在或已被删除';

  @override
  String get notesEditorTitle => '便签';

  @override
  String get notesEmpty => '（空便签）';

  @override
  String get notesEmptyHint => '点击右上角新建，便签可以独立窗口置顶显示';

  @override
  String get notesEmptyTitle => '暂无便签';

  @override
  String notesHeading(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '便签（$count）',
      one: '便签（$count）',
    );
    return '$_temp0';
  }

  @override
  String get notesHide => '隐藏';

  @override
  String get notesLineColor => '此行文字颜色';

  @override
  String get notesMarkLineComplete => '标记此行完成';

  @override
  String get notesNewNote => '新建便签';

  @override
  String get notesOpenWindow => '打开独立窗口';

  @override
  String get notesPinWindow => '窗口置顶';

  @override
  String get notesPinned => '置顶';

  @override
  String get notesShow => '显示';

  @override
  String get notesStandaloneWindow => '独立窗口';

  @override
  String get notesTitleField => '标题';

  @override
  String get notesUnavailable => '暂无便签';

  @override
  String get notificationChannel => '任务提醒';

  @override
  String get notificationChannelDescription => '日历任务与纪念日提醒';

  @override
  String get notificationOpenCalendar => '打开日历';

  @override
  String get reminderAcknowledge => '知道了';

  @override
  String get reminderDismissTooltip => '关闭提醒';

  @override
  String get reminderDontShowAgain => '不再显示窗口';

  @override
  String reminderLogCancelFailed(String notificationId) {
    return '取消提醒失败：$notificationId';
  }

  @override
  String get reminderLogClearFailed => '清空提醒失败';

  @override
  String get reminderLogInitializeFailed => '本地通知初始化失败，改用应用内提醒';

  @override
  String get reminderLogInitialized => '本地通知插件初始化完成';

  @override
  String reminderLogScheduleFailed(String eventId) {
    return '提醒调度失败：$eventId';
  }

  @override
  String reminderNotificationBody(String date, String time) {
    return '$date $time';
  }

  @override
  String reminderRescheduleFailed(String message) {
    return '重新安排提醒失败：$message';
  }

  @override
  String get reminderTaskTitle => '任务提醒';

  @override
  String get searchChooseCustomRange => '选择自定义范围';

  @override
  String get searchClearQueryTooltip => '清空搜索';

  @override
  String searchCourseSubtitle(String course, String weekday, int period) {
    return '$course · 周$weekday 第$period节';
  }

  @override
  String searchCustomRangeLabel(String start, String end) {
    return '$start 至 $end';
  }

  @override
  String get searchEmptyHint => '输入关键词后即时检索全部模块';

  @override
  String get searchEmptyTitle => '没有匹配内容';

  @override
  String searchEventSubtitle(String date, String recurrence) {
    return '$date · $recurrence';
  }

  @override
  String get searchFieldHint => '内容、任务、便签、倒数日、订阅、课程';

  @override
  String get searchFieldLabel => '搜日历清单';

  @override
  String get searchKindCell => '单元格';

  @override
  String get searchKindCountdown => '倒数日';

  @override
  String get searchKindCourse => '课程';

  @override
  String get searchKindNote => '便签';

  @override
  String get searchKindSubscription => '订阅';

  @override
  String get searchRangeAll => '全部';

  @override
  String get searchRangeCustom => '自定义';

  @override
  String get searchRangeOneMonth => '近一月';

  @override
  String get searchRangeOneYear => '近一年';

  @override
  String get searchRangeThreeMonths => '近三月';

  @override
  String searchResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '共找到 $count 条结果',
    );
    return '$_temp0';
  }

  @override
  String searchSubscriptionSubtitle(String name, String date) {
    return '$name · $date';
  }

  @override
  String settingsAboutAppVersion(String appTitle, String version) {
    return '$appTitle $version';
  }

  @override
  String get settingsAboutData => '关于 / 数据';

  @override
  String get settingsAdvanced => '高级设置';

  @override
  String get settingsApplyToDesktop => '立即应用到桌面';

  @override
  String get settingsAutoCheckUpdates => '自动检查更新';

  @override
  String get settingsAutoDelay => '未完成任务 30 天内自动顺延';

  @override
  String get settingsBulletStyle => '项目符号';

  @override
  String get settingsCalendarColors => '日历颜色';

  @override
  String get settingsCalendarDisplay => '日历显示';

  @override
  String get settingsCalendarFontSize => '日历字号';

  @override
  String get settingsCalendarOpacity => '日历透明度';

  @override
  String get settingsCellGap => '单元格间距';

  @override
  String get settingsCellSection => '单元格';

  @override
  String get settingsCheckNow => '立即检查';

  @override
  String get settingsCheckUpdates => '检查更新';

  @override
  String get settingsChooseImageDirectory => '选择图片目录';

  @override
  String get settingsClearImageDirectory => '清除图片目录';

  @override
  String get settingsCloudSync => '云同步';

  @override
  String get settingsCompletedLast => '完成项目排到最后';

  @override
  String get settingsContentFontSize => '内容字号';

  @override
  String get settingsCountdownOpacity => '倒数日透明度';

  @override
  String get settingsDesktop => '桌面';

  @override
  String get settingsDesktopBehavior => '组件常驻所有窗口下面，卡片内可直接输入/勾选/拖动，卡片外点击穿透到桌面图标。';

  @override
  String get settingsDesktopDescription => '可编辑月历组件常驻桌面层；静态壁纸快照仅作可选备份';

  @override
  String get settingsDesktopWidgetHidden => '桌面组件：已隐藏';

  @override
  String get settingsDesktopWidgetVisible => '桌面组件：已显示（可编辑）';

  @override
  String get settingsDisplayMode => '显示模式';

  @override
  String get settingsEditableDesktopCalendar => '在桌面上显示可编辑月历（真·桌面层）';

  @override
  String get settingsFestivalInfo => '显示节日 / 农历 / 节气';

  @override
  String get settingsFontColors => '字体和颜色';

  @override
  String get settingsGlassEffect => '显示透明玻璃效果';

  @override
  String get settingsHideHotkey => 'Crtl+H 显示隐藏 / 快捷键开关';

  @override
  String get settingsHolidays => '显示法定节假日';

  @override
  String get settingsHotSearchFloating => '显示热搜 / 浮动按钮';

  @override
  String get settingsIeProxy => '使用 IE 代理设置';

  @override
  String get settingsJiyi => '显示黄历宜忌';

  @override
  String get settingsLanguage => '语言';

  @override
  String get settingsLegacyCalendarHint => '对应旧版「日历」设置页';

  @override
  String get settingsLineSpacing => '行间距';

  @override
  String get settingsLunar => '显示农历';

  @override
  String get settingsMonthDetails => '显示月间隔 / 周数 / 阴影 / 标题栏';

  @override
  String get settingsNoImageDirectory => '未选择图片目录';

  @override
  String get settingsNotesLineSpacing => '行间距';

  @override
  String get settingsNotesOpacity => '便签透明度';

  @override
  String get settingsNotesSection => '便签';

  @override
  String get settingsReminderTone => '提醒提示音';

  @override
  String get settingsRescheduleReminders => '重排提醒';

  @override
  String get settingsRestoreDefaults => '恢复默认设置';

  @override
  String get settingsSaveFailed => '设置保存失败，请检查本地存储后重试';

  @override
  String get settingsRestoreSystemWallpaper => '恢复系统原壁纸';

  @override
  String settingsScheduledReminders(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已排程提醒 $count 条',
      one: '已排程提醒 $count 条',
    );
    return '$_temp0';
  }

  @override
  String get settingsSearchEngine => '搜索引擎';

  @override
  String get settingsSearchEngineBaidu => '百度';

  @override
  String get settingsSearchEngineBing => '必应';

  @override
  String get settingsShowAllNotes => '显示所有便签';

  @override
  String get settingsShowCompleted => '显示已完成项目';

  @override
  String get settingsShowReminderTime => '显示提醒时间';

  @override
  String get settingsSolarTerms => '显示节气';

  @override
  String get settingsStartOfWeek => '周起始日';

  @override
  String get settingsStartWithWindows => '开机自启（随 Windows 启动）';

  @override
  String get settingsStaticWallpaperGenerated => '静态壁纸：已生成';

  @override
  String get settingsStaticWallpaperNotEnabled => '静态壁纸：未启用';

  @override
  String get settingsStaticWallpaperSnapshot => '（可选）生成静态壁纸快照';

  @override
  String settingsStorageName(String storageName) {
    return 'Clean DDD + Riverpod · 本地存储：$storageName';
  }

  @override
  String get settingsSyncNow => '立即同步';

  @override
  String get settingsTabAbout => '关于';

  @override
  String get settingsTabAdvanced => '高级';

  @override
  String get settingsTabCalendar => '日历';

  @override
  String get settingsTabCell => '单元格';

  @override
  String get settingsTabFontColors => '字体和颜色';

  @override
  String get settingsTabNotes => '便签';

  @override
  String get settingsTabWallpaper => '壁纸';

  @override
  String get settingsTaskCompleteTone => '完成提示音';

  @override
  String get settingsTheme => '主题';

  @override
  String settingsVisibleColumns(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 列',
      one: '$count 列',
    );
    return '$_temp0';
  }

  @override
  String get settingsVisibleColumnsLabel => '显示月份列';

  @override
  String settingsVisibleRows(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 行',
      one: '$count 行',
    );
    return '$_temp0';
  }

  @override
  String get settingsVisibleRowsLabel => '显示行数';

  @override
  String get settingsWallpaperFit => '图片适配';

  @override
  String get settingsWallpaperFitFill => '填充（裁切铺满）';

  @override
  String get settingsWallpaperFitFit => '适应（完整显示）';

  @override
  String get settingsWallpaperFitStretch => '拉伸';

  @override
  String get settingsWallpaperImage => '壁纸底图';

  @override
  String get settingsWallpaperIntervalLabel => '切换间隔（分钟）';

  @override
  String settingsWallpaperIntervalMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 分钟',
      one: '$count 分钟',
    );
    return '$_temp0';
  }

  @override
  String get settingsWallpaperShowAll => '循环目录下全部图片';

  @override
  String get settingsWeekNumbers => '显示周序号';

  @override
  String settingsWeekday(String weekday) {
    return '周$weekday';
  }

  @override
  String get soundToneDing => '滴答';

  @override
  String get soundToneDing2 => '叮当';

  @override
  String get soundToneDing3 => '叮咚';

  @override
  String get soundToneDong => '咚';

  @override
  String get soundToneLittleStar => '小星星';

  @override
  String get soundToneNone => '无';

  @override
  String subWindowCommand(String command) {
    return '子窗口指令：$command';
  }

  @override
  String get subscriptionAdd => '添加订阅';

  @override
  String get subscriptionCopyLink => '复制分享链接';

  @override
  String get subscriptionCreateTitle => '添加订阅日历';

  @override
  String get subscriptionDelete => '删除订阅';

  @override
  String get subscriptionEmptyHint => '支持本地订阅与 Google / Outlook / iCloud / CalDAV';

  @override
  String get subscriptionEmptyTitle => '暂无订阅日历';

  @override
  String get subscriptionEnabled => '启用此订阅';

  @override
  String subscriptionFetchFailed(String name) {
    return '订阅拉取失败，保留本地缓存：$name';
  }

  @override
  String subscriptionHeading(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '订阅日历（$count）',
      one: '订阅日历（$count）',
    );
    return '$_temp0';
  }

  @override
  String subscriptionLastSyncedAt(String date, String time) {
    return '最近同步：$date $time';
  }

  @override
  String get subscriptionName => '订阅名称';

  @override
  String get subscriptionNeverSynced => '尚未同步';

  @override
  String get subscriptionShareLinkHint => '分享链接（留空则生成本地订阅）';

  @override
  String get subscriptionSource => '订阅来源';

  @override
  String get subscriptionSourceCaldav => 'CalDAV';

  @override
  String get subscriptionSourceGoogle => 'Google 日历';

  @override
  String get subscriptionSourceIcloud => 'iCloud 日历';

  @override
  String get subscriptionSourceLocal => '本地订阅';

  @override
  String get subscriptionSourceOutlook => 'Outlook 日历';

  @override
  String subscriptionSummary(String source, int count, String lastSync) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 条推送',
      one: '$count 条推送',
    );
    return '$source · $_temp0 · $lastSync';
  }

  @override
  String get subscriptionSync => '同步';

  @override
  String get subscriptionSyncAll => '同步全部';

  @override
  String syncFailed(String message) {
    return '同步失败：$message';
  }

  @override
  String get syncLoginRequired => '请先登录账号后再同步';

  @override
  String syncSummary(int uploaded, int downloaded) {
    return '上传 $uploaded 条记录，下载 $downloaded 条记录。';
  }

  @override
  String get themeModeDark => '深色';

  @override
  String get themeModeLight => '浅色';

  @override
  String get themeModeSystem => '跟随系统';

  @override
  String get timetableAdd => '添加';

  @override
  String timetableAddLessonTitle(String weekday, int period) {
    return '添加课程（$weekday 第$period节）';
  }

  @override
  String timetableAddLessonTooltip(String weekday, int period) {
    return '添加课程（$weekday 第$period节）';
  }

  @override
  String get timetableCourseName => '课程名称';

  @override
  String get timetableEmptyHint => '支持单双周、节次时间与课程冲突检测';

  @override
  String get timetableEmptyTitle => '暂无课程表';

  @override
  String get timetableHideWeekend => '隐藏周末';

  @override
  String get timetableLessonConflict => '新增课程与其他课程有时间冲突';

  @override
  String get timetableNewName => '新建课程表';

  @override
  String get timetableParityAll => '全选';

  @override
  String get timetableParityEven => '双周';

  @override
  String get timetableParityOdd => '单周';

  @override
  String get timetablePeriod => '节次';

  @override
  String get timetablePeriodsPerDay => '每天节次';

  @override
  String timetablePeriodsPerDayCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 节',
      one: '1 节',
    );
    return '$_temp0';
  }

  @override
  String timetableRemoveLessonTooltip(String name) {
    return '删除课程$name';
  }

  @override
  String timetableRemoveTooltip(String name) {
    return '删除$name';
  }

  @override
  String get timetableSemesterWeeks => '学期周数';

  @override
  String get timetableSettings => '课程表设置';

  @override
  String timetableSettingsTitle(String name) {
    return '课程表设置：$name';
  }

  @override
  String get timetableStartDate => '开学日期';

  @override
  String timetableSummary(String startDate, int weeks) {
    String _temp0 = intl.Intl.pluralLogic(
      weeks,
      locale: localeName,
      other: '$weeks 周',
      one: '1 周',
    );
    return '$startDate 开学 · $_temp0';
  }

  @override
  String get timetableTitle => '课程表';

  @override
  String timetableWeeksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 周',
      one: '1 周',
    );
    return '$_temp0';
  }

  @override
  String get transferChooseAndImport => '选择文件并导入';

  @override
  String get transferExportSubtitle => '支持再次导入的数据库文件、可打印文本、Excel 兼容 CSV';

  @override
  String get transferExportTitle => '导出日历清单';

  @override
  String get transferExportToFile => '导出到文件';

  @override
  String get transferFormatCsv => 'Excel 文件（CSV）';

  @override
  String get transferFormatDatabase => '数据库文件（可再导入）';

  @override
  String get transferFormatText => '文本文件';

  @override
  String get transferImportSubtitle => '从 `*.json` 数据库文件恢复单元格与任务';

  @override
  String get transferImportTitle => '导入日历清单';

  @override
  String get transferRangeAllTime => '所有时间';

  @override
  String get transferRangeCustom => '自定义';

  @override
  String get transferRangeSixMonths => '近半年';

  @override
  String get transferReplaceConflicts => '所有冲突都替换为导入内容';

  @override
  String get trayAbout => '关于';

  @override
  String get trayExit => '退出';

  @override
  String get trayHide => '隐藏主窗口';

  @override
  String get trayHideWidget => '隐藏桌面日历窗口';

  @override
  String get trayNotes => '便签';

  @override
  String get trayRefreshWallpaper => '刷新壁纸';

  @override
  String get traySettings => '设置';

  @override
  String get trayShow => '显示主窗口';

  @override
  String get trayShowWidget => '显示桌面日历窗口';

  @override
  String get traySync => '手动同步';

  @override
  String get wallpaperFailed => '壁纸生成失败';

  @override
  String wallpaperFooter(String date, String weekday) {
    return '今天 $date · 周$weekday    数据来自本地日历清单';
  }

  @override
  String get wallpaperModeDesktopCapture => '从桌面抓取图片';

  @override
  String get wallpaperModeRotation => '循环显示选择的图片';

  @override
  String get wallpaperModeSolidColor => '设置桌面背景颜色';

  @override
  String get wallpaperRejected => '系统拒绝设置壁纸';

  @override
  String get wallpaperRestored => '已恢复系统原壁纸';

  @override
  String get wallpaperSelectDirectory => '选择壁纸图片目录';

  @override
  String get wallpaperUpdated => '壁纸已更新';

  @override
  String get widgetAddLine => '添加一行';

  @override
  String get widgetAddLineTooltip => '添加一行';

  @override
  String widgetAddToDate(String date) {
    return '添加到 $date';
  }

  @override
  String get widgetCellColor => '单元格颜色';

  @override
  String get widgetCellColorTooltip => '选择单元格颜色';

  @override
  String get widgetClearDay => '清空本日';

  @override
  String get widgetClearTooltip => '清空本日内容';

  @override
  String get widgetClosePalette => '关闭调色板';

  @override
  String get widgetMoveHint => '拖动以移动桌面日历';

  @override
  String get widgetResizeLeft => '调整左边缘大小';

  @override
  String get widgetResizeRight => '调整右边缘大小';

  @override
  String get widgetResizeTop => '调整上边缘大小';

  @override
  String get widgetResizeBottom => '调整下边缘大小';

  @override
  String get widgetResizeTopLeft => '调整左上角大小';

  @override
  String get widgetResizeTopRight => '调整右上角大小';

  @override
  String get widgetResizeBottomLeft => '调整左下角大小';

  @override
  String get widgetResizeBottomRight => '调整右下角大小';

  @override
  String get widgetCollapse => '收起桌面组件';

  @override
  String get widgetCompleteTooltip => '标记完成';

  @override
  String get widgetConfirmClear => '确认清空';

  @override
  String widgetEditingDate(String date) {
    return '正在编辑 $date';
  }

  @override
  String get widgetFinishEditing => '完成编辑';

  @override
  String get widgetFinishEditingTooltip => '保存并完成编辑';

  @override
  String get widgetMarkComplete => '标记完成';

  @override
  String get widgetNewLineHint => '回车新增一行…';

  @override
  String get widgetPopupEditor => '浮层编辑';

  @override
  String get widgetPopupEditorTooltip => '打开完整编辑器';

  @override
  String get widgetPromote => '转为任务';

  @override
  String get widgetPromoteTooltip => '将这一行转为重复任务';

  @override
  String get widgetQuickInputHint => '输入内容，回车添加';

  @override
  String get widgetTextColor => '文字颜色';

  @override
  String get widgetTextColorTooltip => '选择文字颜色';

  @override
  String get authLoginTitle => '登录 / 注册';

  @override
  String get authLoginSubtitle => '使用手机号验证码登录，首次登录将自动创建账号。';

  @override
  String get authPhoneHint => '手机号';

  @override
  String get authCodeHint => '6 位验证码';

  @override
  String get authPasswordHint => '密码（6–20 位）';

  @override
  String get authSendCode => '获取验证码';

  @override
  String get authSendingCode => '发送中';

  @override
  String authResendCode(int seconds) {
    return '$seconds 秒后重发';
  }

  @override
  String get authLoggingIn => '登录中';

  @override
  String get authLoginAction => '登录 / 注册';

  @override
  String get authSwitchToPassword => '使用密码登录';

  @override
  String get authSwitchToCode => '使用验证码登录';

  @override
  String get authAgreementText => '我已阅读并同意注册协议和隐私政策';

  @override
  String get authAgreementRequired => '请先阅读并同意注册协议和隐私政策';

  @override
  String get authPhoneInvalid => '请输入有效的 11 位手机号';

  @override
  String get authCodeInvalid => '请输入 6 位短信验证码';

  @override
  String get authPasswordInvalid => '密码长度需为 6–20 位';

  @override
  String get authCodeSent => '验证码已发送';

  @override
  String get authNetworkError => '网络连接失败，请检查网络后重试';

  @override
  String get authTimeoutError => '请求超时，请稍后重试';

  @override
  String get authStorageError => '无法安全保存登录状态，请检查系统钥匙串';

  @override
  String get authSessionExpired => '登录状态已失效，请重新登录';

  @override
  String get authUnknownError => '操作失败，请稍后重试';

  @override
  String get authAccountLockedTitle => '账号已被锁定';

  @override
  String get authAccountLockedConfirm => '我知道了';

  @override
  String get authCaptchaTitle => '图形验证码';

  @override
  String get authCaptchaHint => '输入图中字符';

  @override
  String get authCaptchaRefresh => '换一张';

  @override
  String get authCaptchaCancel => '取消';

  @override
  String get authCaptchaConfirm => '确定';

  @override
  String get authCaptchaLoadFailed => '图形验证码加载失败，请点击重试';

  @override
  String get authNewUserWelcome => '账号已创建，欢迎使用企划星';

  @override
  String get authBackToAccount => '返回账号页';

  @override
  String get authRefreshProfile => '刷新资料';

  @override
  String get authProfileRefreshing => '刷新中';

  @override
  String get authSignIn => '每日签到';

  @override
  String get authSigningIn => '签到中';

  @override
  String authSignInReward(int reward) {
    return '今日奖励：$reward 星币';
  }

  @override
  String authWalletBalance(String balance) {
    return '星币余额：$balance';
  }

  @override
  String authUserId(int id) {
    return '用户 ID：$id';
  }

  @override
  String get authProfileEmpty => '暂无个人简介';

  @override
  String get authSignedToday => '今日已签到';

  @override
  String get authLoginPrompt => '登录后可同步账号资料并每日签到。';

  @override
  String get authGuestName => '未登录';

  @override
  String get catalogTitle => '企划库';

  @override
  String get catalogSubtitle => '浏览企划筹资进度、回报档位与项目动态';

  @override
  String get catalogAllCategories => '全部';

  @override
  String get catalogSortRecommended => '推荐';

  @override
  String get catalogSortNewest => '最新';

  @override
  String get catalogSortEnding => '即将结束';

  @override
  String get catalogSortAchievement => '筹资最高';

  @override
  String get catalogLoadMore => '加载更多';

  @override
  String get catalogEnd => '没有更多企划';

  @override
  String get catalogEmptyTitle => '暂无企划';

  @override
  String get catalogEmptyHint => '试试其他分类或刷新企划库。';

  @override
  String get catalogCredits => '星币';

  @override
  String catalogSupporters(int count) {
    return '$count 位支持者';
  }

  @override
  String catalogAchievement(int percent) {
    return '已筹 $percent%';
  }

  @override
  String get catalogDetailTitle => '企划详情';

  @override
  String get catalogDetailEmpty => '企划暂不可用';

  @override
  String get catalogReadOnlyNotice => '当前为只读预览，桌面端暂不支持支付、选座和创建订单。';

  @override
  String get catalogStatusPreheating => '预热中';

  @override
  String get catalogStatusAchieved => '已达成';

  @override
  String get catalogStatusDelivered => '已交付';

  @override
  String get catalogStatusFailed => '筹资结束';

  @override
  String get catalogStatusOngoing => '筹资中';

  @override
  String get catalogProgressTitle => '筹资进度';

  @override
  String catalogDaysLeft(int count) {
    return '剩余 $count 天';
  }

  @override
  String get catalogEnded => '已结束';

  @override
  String get catalogGoalAmount => '目标金额';

  @override
  String get catalogRaisedAmount => '已筹金额';

  @override
  String get catalogDeadline => '截止时间';

  @override
  String get catalogInfoTitle => '企划信息';

  @override
  String catalogDuration(String duration) {
    return '时长：$duration';
  }

  @override
  String get catalogSoldOut => '已售罄';

  @override
  String get catalogRewardsTitle => '回报档位';

  @override
  String catalogDelivery(String date) {
    return '预计交付：$date';
  }

  @override
  String get catalogUpdatesTitle => '项目动态';

  @override
  String get catalogRiskTitle => '风险与履约';

  @override
  String get catalogRiskNote => '风险说明';

  @override
  String get catalogDeliveryPlan => '交付计划';

  @override
  String get catalogFundUsage => '资金用途';

  @override
  String get catalogRefundRule => '退款规则';

  @override
  String catalogReviewsTitle(int count) {
    return '支持者评价（$count）';
  }

  @override
  String get catalogAnonymous => '匿名支持者';

  @override
  String get catalogFaqTitle => '常见问题';

  @override
  String get catalogCreatorTitle => '关于创作者';

  @override
  String catalogCreator(String name) {
    return '创作者：$name';
  }

  @override
  String get catalogCreatorVerified => '认证创作者';

  @override
  String catalogCreatorStats(int projects, int successful, int rate) {
    return '$projects 个项目 · $successful 个成功 · 履约率 $rate%';
  }

  @override
  String get catalogStoryTitle => '企划故事';

  @override
  String get catalogGalleryTitle => '项目图片';

  @override
  String get catalogNoticeTitle => '支持须知';
}
