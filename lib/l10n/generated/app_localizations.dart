import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh')
  ];

  /// 账号自动登录状态
  ///
  /// In zh, this message translates to:
  /// **'自动登录'**
  String get accountAutoLogin;

  /// 每小时自动同步开关
  ///
  /// In zh, this message translates to:
  /// **'每个整点自动同步'**
  String get accountAutoSyncHourly;

  /// 云同步流程说明
  ///
  /// In zh, this message translates to:
  /// **'记录变更 → 手动 / 自动同步 → 状态回写'**
  String get accountCloudSyncSubtitle;

  /// 云同步区域标题
  ///
  /// In zh, this message translates to:
  /// **'云同步'**
  String get accountCloudSyncTitle;

  /// 已下载记录数量
  ///
  /// In zh, this message translates to:
  /// **'{count, plural, =1{下载 1 条} other{下载 {count} 条}}'**
  String accountDownloadedCount(int count);

  /// 登录邮箱或手机号输入框标签
  ///
  /// In zh, this message translates to:
  /// **'邮箱 / 手机号'**
  String get accountEmailOrPhone;

  /// 已登录账号的显示名称和邮箱
  ///
  /// In zh, this message translates to:
  /// **'{displayName}（{email}）'**
  String accountIdentity(String displayName, String email);

  /// 按当前语言格式化的上次同步时间
  ///
  /// In zh, this message translates to:
  /// **'上次同步：{dateTime}'**
  String accountLastSyncAt(String dateTime);

  /// 登录或注册按钮
  ///
  /// In zh, this message translates to:
  /// **'登录 / 注册'**
  String get accountLoginOrRegister;

  /// 退出登录按钮
  ///
  /// In zh, this message translates to:
  /// **'退出登录'**
  String get accountLogout;

  /// 手动同步按钮
  ///
  /// In zh, this message translates to:
  /// **'手动同步'**
  String get accountManualSync;

  /// 从未同步时的状态
  ///
  /// In zh, this message translates to:
  /// **'从未同步'**
  String get accountNeverSynced;

  /// 登录密码输入框标签
  ///
  /// In zh, this message translates to:
  /// **'密码'**
  String get accountPassword;

  /// 待同步变更数量
  ///
  /// In zh, this message translates to:
  /// **'{count, plural, =0{没有待同步变更} =1{待同步变更 1 条} other{待同步变更 {count} 条}}'**
  String accountPendingChanges(int count);

  /// 账号只读成员状态
  ///
  /// In zh, this message translates to:
  /// **'只读成员'**
  String get accountReadOnlyMember;

  /// 同步失败状态
  ///
  /// In zh, this message translates to:
  /// **'同步失败'**
  String get accountStatusFailure;

  /// 同步空闲状态
  ///
  /// In zh, this message translates to:
  /// **'空闲'**
  String get accountStatusIdle;

  /// 同步成功状态
  ///
  /// In zh, this message translates to:
  /// **'同步成功'**
  String get accountStatusSuccess;

  /// 同步进行中状态
  ///
  /// In zh, this message translates to:
  /// **'同步中'**
  String get accountStatusSyncing;

  /// 账号页面说明
  ///
  /// In zh, this message translates to:
  /// **'登录后可以同步和备份日历清单'**
  String get accountSubtitle;

  /// 账号团队账号状态
  ///
  /// In zh, this message translates to:
  /// **'团队账号'**
  String get accountTeamAccount;

  /// 账号页面标题
  ///
  /// In zh, this message translates to:
  /// **'账号'**
  String get accountTitle;

  /// 已上传记录数量
  ///
  /// In zh, this message translates to:
  /// **'{count, plural, =1{上传 1 条} other{上传 {count} 条}}'**
  String accountUploadedCount(int count);

  /// 账号 VIP 标识
  ///
  /// In zh, this message translates to:
  /// **'VIP'**
  String get accountVip;

  /// Localized desktop text: appTitle
  ///
  /// In zh, this message translates to:
  /// **'企划星 · 桌面日历清单'**
  String get appTitle;

  /// 圆点项目符号
  ///
  /// In zh, this message translates to:
  /// **'圆点'**
  String get bulletStyleDot;

  /// 无项目符号
  ///
  /// In zh, this message translates to:
  /// **'无'**
  String get bulletStyleNone;

  /// 数字编号项目符号
  ///
  /// In zh, this message translates to:
  /// **'数字编号'**
  String get bulletStyleNumber;

  /// Context menu action to add a countdown for the selected day.
  ///
  /// In zh, this message translates to:
  /// **'添加倒数日'**
  String get calendarAddCountdown;

  /// Button label for adding a line to a day cell.
  ///
  /// In zh, this message translates to:
  /// **'添加一行'**
  String get calendarAddLine;

  /// Section heading for the full calendar color palette.
  ///
  /// In zh, this message translates to:
  /// **'全部颜色'**
  String get calendarAllColors;

  /// Label and tooltip for the day-cell background color.
  ///
  /// In zh, this message translates to:
  /// **'单元格颜色'**
  String get calendarCellColor;

  /// Empty-state instructions in the day editor.
  ///
  /// In zh, this message translates to:
  /// **'双击单元格或直接添加一行开始记录'**
  String get calendarCellEditorEmptyHint;

  /// Button label confirming a clear action.
  ///
  /// In zh, this message translates to:
  /// **'清空'**
  String get calendarClearAction;

  /// Warning that clearing the selected content cannot be undone.
  ///
  /// In zh, this message translates to:
  /// **'将清空 {target} 的全部内容，此操作不可撤销。'**
  String calendarClearConfirmMessage(String target);

  /// Title of the clear-content confirmation dialog.
  ///
  /// In zh, this message translates to:
  /// **'确认清空'**
  String get calendarClearConfirmTitle;

  /// Context menu action to clear the selected day's content.
  ///
  /// In zh, this message translates to:
  /// **'清空本日内容'**
  String get calendarClearDayContent;

  /// Section label for event and cell colors.
  ///
  /// In zh, this message translates to:
  /// **'颜色'**
  String get calendarColorLabel;

  /// Description of the colors available in the calendar picker.
  ///
  /// In zh, this message translates to:
  /// **'文字颜色 / 单元格颜色'**
  String get calendarColorPickerDescription;

  /// Title of the calendar color picker dialog.
  ///
  /// In zh, this message translates to:
  /// **'选择颜色'**
  String get calendarColorPickerTitle;

  /// Accessible label and tooltip for a color swatch.
  ///
  /// In zh, this message translates to:
  /// **'颜色 {color}'**
  String calendarColorValue(String color);

  /// Input hint for task or reminder content.
  ///
  /// In zh, this message translates to:
  /// **'输入任务或提醒内容'**
  String get calendarContentHint;

  /// Input label for task or reminder content.
  ///
  /// In zh, this message translates to:
  /// **'内容'**
  String get calendarContentLabel;

  /// Context menu action to copy the selected day's content.
  ///
  /// In zh, this message translates to:
  /// **'复制本日内容'**
  String get calendarCopyDayContent;

  /// Toast confirming that a countdown was added.
  ///
  /// In zh, this message translates to:
  /// **'已添加倒数日'**
  String get calendarCountdownAdded;

  /// Date and weekday heading in the day editor.
  ///
  /// In zh, this message translates to:
  /// **'{date} {weekday}'**
  String calendarDateWithWeekday(String date, String weekday);

  /// Name of the selected day's content in clear confirmations.
  ///
  /// In zh, this message translates to:
  /// **'本日内容'**
  String get calendarDayContent;

  /// Toast confirming that the selected day's content was copied.
  ///
  /// In zh, this message translates to:
  /// **'已复制本日内容'**
  String get calendarDayContentCopied;

  /// Context menu action to delete a recurring task.
  ///
  /// In zh, this message translates to:
  /// **'删除重复任务…'**
  String get calendarDeleteRecurringEvent;

  /// Title of the recurring-event deletion scope dialog.
  ///
  /// In zh, this message translates to:
  /// **'删除重复任务'**
  String get calendarDeleteRecurringEventTitle;

  /// Delete every occurrence of a recurring event.
  ///
  /// In zh, this message translates to:
  /// **'删除所有事件'**
  String get calendarDeleteScopeAll;

  /// Delete only the selected occurrence of a recurring event.
  ///
  /// In zh, this message translates to:
  /// **'仅删除当前事件'**
  String get calendarDeleteScopeCurrent;

  /// Delete the selected occurrence and all future occurrences.
  ///
  /// In zh, this message translates to:
  /// **'删除当前及未来全部事件'**
  String get calendarDeleteScopeCurrentAndFuture;

  /// Option label for applying the same choice to future delete conflicts.
  ///
  /// In zh, this message translates to:
  /// **'所有冲突都选择该方法'**
  String get calendarDeleteScopeRememberChoice;

  /// Calendar display mode label for a fixed single row.
  ///
  /// In zh, this message translates to:
  /// **'固定单行'**
  String get calendarDisplayModeFixedSingleLine;

  /// Calendar display mode label for floating months.
  ///
  /// In zh, this message translates to:
  /// **'浮动月份'**
  String get calendarDisplayModeFloatingMonth;

  /// Calendar display mode label for a floating single row.
  ///
  /// In zh, this message translates to:
  /// **'浮动单行'**
  String get calendarDisplayModeFloatingSingleLine;

  /// Calendar display mode label for full months.
  ///
  /// In zh, this message translates to:
  /// **'完整月份'**
  String get calendarDisplayModeFullMonth;

  /// Context menu action to edit the selected day's content.
  ///
  /// In zh, this message translates to:
  /// **'编辑本日内容'**
  String get calendarEditDayContent;

  /// Dialog title for editing a task or reminder.
  ///
  /// In zh, this message translates to:
  /// **'编辑任务 / 提醒'**
  String get calendarEditTaskOrReminder;

  /// Calendar event type label for countdown anniversaries.
  ///
  /// In zh, this message translates to:
  /// **'倒数纪念日'**
  String get calendarEventTypeCountdown;

  /// Calendar event type label for reminders.
  ///
  /// In zh, this message translates to:
  /// **'提醒'**
  String get calendarEventTypeReminder;

  /// Calendar event type label for subscription notifications.
  ///
  /// In zh, this message translates to:
  /// **'订阅推送'**
  String get calendarEventTypeSubscription;

  /// Calendar event type label for recurring tasks.
  ///
  /// In zh, this message translates to:
  /// **'重复任务'**
  String get calendarEventTypeTask;

  /// Input label for the recurrence interval.
  ///
  /// In zh, this message translates to:
  /// **'间隔'**
  String get calendarIntervalLabel;

  /// Tooltip for changing a cell line's text color.
  ///
  /// In zh, this message translates to:
  /// **'行文字颜色'**
  String get calendarLineTextColor;

  /// Tooltip for converting a cell line into a recurring task.
  ///
  /// In zh, this message translates to:
  /// **'设为重复任务'**
  String get calendarMakeRecurringTask;

  /// Compact badge for a makeup workday.
  ///
  /// In zh, this message translates to:
  /// **'班'**
  String get calendarMakeupWorkdayBadge;

  /// Accessibility action for marking an event complete.
  ///
  /// In zh, this message translates to:
  /// **'标记任务为已完成'**
  String get calendarMarkEventComplete;

  /// Accessibility action for marking a completed event incomplete.
  ///
  /// In zh, this message translates to:
  /// **'标记任务为未完成'**
  String get calendarMarkEventIncomplete;

  /// Accessibility action for marking a cell line complete.
  ///
  /// In zh, this message translates to:
  /// **'标记为已完成'**
  String get calendarMarkLineComplete;

  /// Accessibility action for marking a completed cell line incomplete.
  ///
  /// In zh, this message translates to:
  /// **'标记为未完成'**
  String get calendarMarkLineIncomplete;

  /// Button label for creating a calendar task.
  ///
  /// In zh, this message translates to:
  /// **'新建任务'**
  String get calendarNewTask;

  /// Context menu action and dialog title for a new task or reminder.
  ///
  /// In zh, this message translates to:
  /// **'新建任务 / 提醒'**
  String get calendarNewTaskOrReminder;

  /// Localized desktop text: calendarNextMonth
  ///
  /// In zh, this message translates to:
  /// **'下个月'**
  String get calendarNextMonth;

  /// Toast shown when deleting a task from a day with no tasks.
  ///
  /// In zh, this message translates to:
  /// **'本日没有任务'**
  String get calendarNoTasksOnDay;

  /// Tooltip and hint for opening the countdown desktop card.
  ///
  /// In zh, this message translates to:
  /// **'点击打开桌面卡片'**
  String get calendarOpenCountdownCard;

  /// Context menu action to open a desktop note for the selected day.
  ///
  /// In zh, this message translates to:
  /// **'打开桌面便签'**
  String get calendarOpenDesktopNote;

  /// Context menu action to paste text into the selected day.
  ///
  /// In zh, this message translates to:
  /// **'粘贴到本日'**
  String get calendarPasteToDay;

  /// Localized desktop text: calendarPreviousMonth
  ///
  /// In zh, this message translates to:
  /// **'上个月'**
  String get calendarPreviousMonth;

  /// Recurrence option for a custom daily interval.
  ///
  /// In zh, this message translates to:
  /// **'自定义日重复'**
  String get calendarRecurrenceCustomDay;

  /// Recurrence option for selected days of the month.
  ///
  /// In zh, this message translates to:
  /// **'自定义月重复（按日期）'**
  String get calendarRecurrenceCustomMonthDay;

  /// Recurrence option for a selected ordinal weekday of the month.
  ///
  /// In zh, this message translates to:
  /// **'自定义月重复（按星期）'**
  String get calendarRecurrenceCustomMonthWeek;

  /// Recurrence option for selected weekdays at a custom interval.
  ///
  /// In zh, this message translates to:
  /// **'自定义周重复'**
  String get calendarRecurrenceCustomWeek;

  /// Recurrence option for a custom yearly interval.
  ///
  /// In zh, this message translates to:
  /// **'自定义年重复'**
  String get calendarRecurrenceCustomYear;

  /// Recurrence option to repeat daily.
  ///
  /// In zh, this message translates to:
  /// **'日重复'**
  String get calendarRecurrenceDaily;

  /// Recurrence option for an Ebbinghaus review schedule.
  ///
  /// In zh, this message translates to:
  /// **'艾宾浩斯记忆曲线'**
  String get calendarRecurrenceEbbinghaus;

  /// Recurrence option to repeat on official workdays.
  ///
  /// In zh, this message translates to:
  /// **'法定工作日重复'**
  String get calendarRecurrenceLegalWorkday;

  /// Recurrence option to repeat on the same lunar-calendar date each year.
  ///
  /// In zh, this message translates to:
  /// **'农历年重复'**
  String get calendarRecurrenceLunarYearly;

  /// Recurrence option for the last day of every month.
  ///
  /// In zh, this message translates to:
  /// **'每月最后一天'**
  String get calendarRecurrenceMonthLastDay;

  /// Recurrence option to repeat monthly.
  ///
  /// In zh, this message translates to:
  /// **'月重复'**
  String get calendarRecurrenceMonthly;

  /// Recurrence option for a one-time event.
  ///
  /// In zh, this message translates to:
  /// **'不重复'**
  String get calendarRecurrenceNone;

  /// Recurrence option to repeat quarterly.
  ///
  /// In zh, this message translates to:
  /// **'每季度'**
  String get calendarRecurrenceQuarterly;

  /// Section label for recurrence settings.
  ///
  /// In zh, this message translates to:
  /// **'重复规则'**
  String get calendarRecurrenceRule;

  /// Recurrence option to repeat weekly.
  ///
  /// In zh, this message translates to:
  /// **'周重复'**
  String get calendarRecurrenceWeekly;

  /// Recurrence option to repeat on workdays.
  ///
  /// In zh, this message translates to:
  /// **'工作日重复'**
  String get calendarRecurrenceWorkday;

  /// Recurrence option to repeat yearly.
  ///
  /// In zh, this message translates to:
  /// **'年重复'**
  String get calendarRecurrenceYearly;

  /// Reminder choice for a custom advance period.
  ///
  /// In zh, this message translates to:
  /// **'自定义'**
  String get calendarReminderCustom;

  /// Reminder choice to notify a number of days before the event.
  ///
  /// In zh, this message translates to:
  /// **'{count, plural, other{# 天前}}'**
  String calendarReminderDaysBefore(int count);

  /// Section label for reminder settings.
  ///
  /// In zh, this message translates to:
  /// **'提醒'**
  String get calendarReminderLabel;

  /// Reminder choice to notify on the event day.
  ///
  /// In zh, this message translates to:
  /// **'当天'**
  String get calendarReminderSameDay;

  /// Compact badge for a rest day.
  ///
  /// In zh, this message translates to:
  /// **'休'**
  String get calendarRestDayBadge;

  /// Context menu action to choose a day-cell background color.
  ///
  /// In zh, this message translates to:
  /// **'设置单元格颜色'**
  String get calendarSetCellColor;

  /// Label and tooltip for event text color.
  ///
  /// In zh, this message translates to:
  /// **'文字颜色'**
  String get calendarTextColor;

  /// Localized desktop text: calendarToday
  ///
  /// In zh, this message translates to:
  /// **'今天'**
  String get calendarToday;

  /// Accessible label and tooltip for the transparent color swatch.
  ///
  /// In zh, this message translates to:
  /// **'透明'**
  String get calendarTransparentColor;

  /// Input label for the calendar event type.
  ///
  /// In zh, this message translates to:
  /// **'类型'**
  String get calendarTypeLabel;

  /// Checkbox label for WeChat reminder notifications.
  ///
  /// In zh, this message translates to:
  /// **'微信通知'**
  String get calendarWechatNotification;

  /// Accessibility label for an ISO week number shown in a day cell.
  ///
  /// In zh, this message translates to:
  /// **'第 {week} 周'**
  String calendarWeekNumberAccessibility(int week);

  /// Short weekday header for Friday.
  ///
  /// In zh, this message translates to:
  /// **'五'**
  String get calendarWeekdayFriday;

  /// Long weekday label for Friday.
  ///
  /// In zh, this message translates to:
  /// **'星期五'**
  String get calendarWeekdayLongFriday;

  /// Long weekday label for Monday.
  ///
  /// In zh, this message translates to:
  /// **'星期一'**
  String get calendarWeekdayLongMonday;

  /// Long weekday label for Saturday.
  ///
  /// In zh, this message translates to:
  /// **'星期六'**
  String get calendarWeekdayLongSaturday;

  /// Long weekday label for Sunday.
  ///
  /// In zh, this message translates to:
  /// **'星期日'**
  String get calendarWeekdayLongSunday;

  /// Long weekday label for Thursday.
  ///
  /// In zh, this message translates to:
  /// **'星期四'**
  String get calendarWeekdayLongThursday;

  /// Long weekday label for Tuesday.
  ///
  /// In zh, this message translates to:
  /// **'星期二'**
  String get calendarWeekdayLongTuesday;

  /// Long weekday label for Wednesday.
  ///
  /// In zh, this message translates to:
  /// **'星期三'**
  String get calendarWeekdayLongWednesday;

  /// Short weekday header for Monday.
  ///
  /// In zh, this message translates to:
  /// **'一'**
  String get calendarWeekdayMonday;

  /// Short weekday header for Saturday.
  ///
  /// In zh, this message translates to:
  /// **'六'**
  String get calendarWeekdaySaturday;

  /// Short weekday header for Sunday.
  ///
  /// In zh, this message translates to:
  /// **'日'**
  String get calendarWeekdaySunday;

  /// Short weekday header for Thursday.
  ///
  /// In zh, this message translates to:
  /// **'四'**
  String get calendarWeekdayThursday;

  /// Short weekday header for Tuesday.
  ///
  /// In zh, this message translates to:
  /// **'二'**
  String get calendarWeekdayTuesday;

  /// Short weekday header for Wednesday.
  ///
  /// In zh, this message translates to:
  /// **'三'**
  String get calendarWeekdayWednesday;

  /// 通用添加按钮
  ///
  /// In zh, this message translates to:
  /// **'添加'**
  String get commonAdd;

  /// Localized desktop text: commonAllColors
  ///
  /// In zh, this message translates to:
  /// **'全部颜色'**
  String get commonAllColors;

  /// Localized desktop text: commonCancel
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get commonCancel;

  /// Localized desktop text: commonClose
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get commonClose;

  /// Localized desktop text: commonColorPickerHint
  ///
  /// In zh, this message translates to:
  /// **'文字颜色 / 单元格颜色'**
  String get commonColorPickerHint;

  /// Localized desktop text: commonCountdowns
  ///
  /// In zh, this message translates to:
  /// **'倒数日'**
  String get commonCountdowns;

  /// Localized desktop text: commonDelete
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get commonDelete;

  /// Localized desktop text: commonMaximize
  ///
  /// In zh, this message translates to:
  /// **'最大化'**
  String get commonMaximize;

  /// Localized desktop text: commonMinimize
  ///
  /// In zh, this message translates to:
  /// **'最小化'**
  String get commonMinimize;

  /// Localized desktop text: commonNoCountdowns
  ///
  /// In zh, this message translates to:
  /// **'暂无倒数日'**
  String get commonNoCountdowns;

  /// Localized desktop text: commonNotes
  ///
  /// In zh, this message translates to:
  /// **'便签'**
  String get commonNotes;

  /// Localized desktop text: commonRecentColors
  ///
  /// In zh, this message translates to:
  /// **'最近使用'**
  String get commonRecentColors;

  /// Localized desktop text: commonRetry
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get commonRetry;

  /// Localized desktop text: commonSave
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get commonSave;

  /// Localized desktop text: commonSettings
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get commonSettings;

  /// Localized desktop text: commonSyncNow
  ///
  /// In zh, this message translates to:
  /// **'手动同步'**
  String get commonSyncNow;

  /// Localized desktop text: commonToday
  ///
  /// In zh, this message translates to:
  /// **'今天'**
  String get commonToday;

  /// Age at the next birthday occurrence
  ///
  /// In zh, this message translates to:
  /// **'{age}岁生日'**
  String countdownBirthdayAge(int age);

  /// Button and dialog title for creating a countdown
  ///
  /// In zh, this message translates to:
  /// **'新建倒数日'**
  String get countdownCreate;

  /// Confirmation button for creating a countdown
  ///
  /// In zh, this message translates to:
  /// **'创建'**
  String get countdownCreated;

  /// Number of days remaining until a countdown date
  ///
  /// In zh, this message translates to:
  /// **'{count, plural, other{还有{count}天}}'**
  String countdownDaysRemaining(int count);

  /// Number of days since a recurring anniversary or birthday occurrence
  ///
  /// In zh, this message translates to:
  /// **'{count, plural, other{已过{count}天}}'**
  String countdownDaysSince(int count);

  /// Accessibility tooltip for deleting a countdown item
  ///
  /// In zh, this message translates to:
  /// **'删除倒数日：{title}'**
  String countdownDeleteTooltip(String title);

  /// Supported countdown kinds shown in the empty state
  ///
  /// In zh, this message translates to:
  /// **'支持倒计时、累计日、生日、纪念日'**
  String get countdownEmptyHint;

  /// Empty countdown list title
  ///
  /// In zh, this message translates to:
  /// **'暂无倒数日'**
  String get countdownEmptyTitle;

  /// Number of days since a fixed-date countdown expired
  ///
  /// In zh, this message translates to:
  /// **'{count, plural, other{过期{count}天}}'**
  String countdownExpiredDays(int count);

  /// message must be a safe localized category from failureLabel, never raw error details
  ///
  /// In zh, this message translates to:
  /// **'加载倒数日失败：{message}'**
  String countdownLoadFailed(String message);

  /// Countdown name text field label
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String get countdownNameField;

  /// Action for opening the desktop countdown card
  ///
  /// In zh, this message translates to:
  /// **'打开桌面卡片'**
  String get countdownOpenDesktopCard;

  /// Show a countdown in both locations
  ///
  /// In zh, this message translates to:
  /// **'两者都显示'**
  String get countdownShowTypeBoth;

  /// Show a countdown in the calendar bottom bar only
  ///
  /// In zh, this message translates to:
  /// **'日历底部'**
  String get countdownShowTypeCalendarBottom;

  /// Show a countdown on the desktop card only
  ///
  /// In zh, this message translates to:
  /// **'桌面卡片'**
  String get countdownShowTypeDesktopCard;

  /// Countdown display location dropdown field label
  ///
  /// In zh, this message translates to:
  /// **'显示位置'**
  String get countdownShowTypeField;

  /// Selected target date shown in the countdown editor
  ///
  /// In zh, this message translates to:
  /// **'目标日期：{date}'**
  String countdownTargetDateValue(String date);

  /// Countdown page title with the number of countdown items
  ///
  /// In zh, this message translates to:
  /// **'{count, plural, other{倒数日（{count}）}}'**
  String countdownTitle(int count);

  /// Countdown type: birthday
  ///
  /// In zh, this message translates to:
  /// **'生日'**
  String get countdownTypeBirthday;

  /// Countdown type: fixed-date countdown
  ///
  /// In zh, this message translates to:
  /// **'倒计时'**
  String get countdownTypeCustom;

  /// Countdown type: exam
  ///
  /// In zh, this message translates to:
  /// **'考试'**
  String get countdownTypeExam;

  /// Countdown type: festival
  ///
  /// In zh, this message translates to:
  /// **'节日'**
  String get countdownTypeFestival;

  /// Countdown type dropdown field label
  ///
  /// In zh, this message translates to:
  /// **'类型'**
  String get countdownTypeField;

  /// Countdown type: anniversary
  ///
  /// In zh, this message translates to:
  /// **'纪念日'**
  String get countdownTypeMemorial;

  /// Localized desktop text: countdownWindowTitle
  ///
  /// In zh, this message translates to:
  /// **'倒数日'**
  String get countdownWindowTitle;

  /// message must be a safe localized category from caughtErrorLabel, never raw exception details
  ///
  /// In zh, this message translates to:
  /// **'桌面小组件启动失败：{message}'**
  String desktopWidgetFailed(String message);

  /// Localized desktop text: desktopWidgetHidden
  ///
  /// In zh, this message translates to:
  /// **'桌面可编辑月历已隐藏'**
  String get desktopWidgetHidden;

  /// Localized desktop text: desktopWidgetShown
  ///
  /// In zh, this message translates to:
  /// **'桌面可编辑月历已显示'**
  String get desktopWidgetShown;

  /// Localized desktop text: desktopWidgetTitle
  ///
  /// In zh, this message translates to:
  /// **'桌面日历清单'**
  String get desktopWidgetTitle;

  /// Localized desktop text: exportCancelled
  ///
  /// In zh, this message translates to:
  /// **'已取消导出'**
  String get exportCancelled;

  /// Localized desktop text: exportCellType
  ///
  /// In zh, this message translates to:
  /// **'日历清单'**
  String get exportCellType;

  /// Localized desktop text: exportColumnColor
  ///
  /// In zh, this message translates to:
  /// **'颜色'**
  String get exportColumnColor;

  /// Localized desktop text: exportColumnContent
  ///
  /// In zh, this message translates to:
  /// **'内容'**
  String get exportColumnContent;

  /// Localized desktop text: exportColumnDate
  ///
  /// In zh, this message translates to:
  /// **'日期'**
  String get exportColumnDate;

  /// Localized desktop text: exportColumnStatus
  ///
  /// In zh, this message translates to:
  /// **'状态'**
  String get exportColumnStatus;

  /// Localized desktop text: exportColumnType
  ///
  /// In zh, this message translates to:
  /// **'类型'**
  String get exportColumnType;

  /// Localized desktop text: exportCompleted
  ///
  /// In zh, this message translates to:
  /// **'已完成'**
  String get exportCompleted;

  /// message must be a safe localized category from caughtErrorLabel, never raw exception details
  ///
  /// In zh, this message translates to:
  /// **'导出失败：{message}'**
  String exportFailed(String message);

  /// Localized desktop text: exportIncomplete
  ///
  /// In zh, this message translates to:
  /// **'未完成'**
  String get exportIncomplete;

  /// Localized desktop text: exportPreparing
  ///
  /// In zh, this message translates to:
  /// **'正在准备导出…'**
  String get exportPreparing;

  /// Localized desktop text: exportSuccess
  ///
  /// In zh, this message translates to:
  /// **'导出成功：{path}'**
  String exportSuccess(String path);

  /// Localized desktop text: exportTextTitle
  ///
  /// In zh, this message translates to:
  /// **'企划星日历清单 · 导出于 {date}'**
  String exportTextTitle(String date);

  /// Safe fallback for an unclassified failure; never includes diagnostic details.
  ///
  /// In zh, this message translates to:
  /// **'操作未能完成，请稍后重试。'**
  String get failureGeneric;

  /// Safe presentation label for a network connection failure.
  ///
  /// In zh, this message translates to:
  /// **'网络连接失败，请检查网络后重试。'**
  String get failureNetwork;

  /// Safe presentation label for offline or unavailable cached data.
  ///
  /// In zh, this message translates to:
  /// **'当前处于离线状态，请检查网络后重试。'**
  String get failureOffline;

  /// Safe presentation label for a timeout.
  ///
  /// In zh, this message translates to:
  /// **'请求超时，请稍后重试。'**
  String get failureTimeout;

  /// Safe presentation label for an authentication failure.
  ///
  /// In zh, this message translates to:
  /// **'登录状态无效，请重新登录。'**
  String get failureAuthentication;

  /// Safe presentation label for an expired login session.
  ///
  /// In zh, this message translates to:
  /// **'登录已过期，请重新登录。'**
  String get failureSessionExpired;

  /// Safe presentation label for a forbidden operation.
  ///
  /// In zh, this message translates to:
  /// **'没有执行此操作的权限。'**
  String get failureForbidden;

  /// Safe presentation label for an invalid request.
  ///
  /// In zh, this message translates to:
  /// **'请求内容有误，请检查后重试。'**
  String get failureBadRequest;

  /// Safe presentation label for content that cannot be found.
  ///
  /// In zh, this message translates to:
  /// **'未找到所需内容，它可能已被删除。'**
  String get failureNotFound;

  /// Safe presentation label for conflicting data state.
  ///
  /// In zh, this message translates to:
  /// **'数据状态已变化，请刷新后重试。'**
  String get failureConflict;

  /// Safe presentation label for rate limiting.
  ///
  /// In zh, this message translates to:
  /// **'操作过于频繁，请稍后再试。'**
  String get failureRateLimit;

  /// Safe presentation label for a server failure.
  ///
  /// In zh, this message translates to:
  /// **'服务暂时不可用，请稍后重试。'**
  String get failureServer;

  /// Safe presentation label for malformed or unreadable data.
  ///
  /// In zh, this message translates to:
  /// **'数据读取失败，请稍后重试。'**
  String get failureData;

  /// Safe presentation label for input validation failures.
  ///
  /// In zh, this message translates to:
  /// **'输入内容不符合要求，请检查后重试。'**
  String get failureValidation;

  /// Safe presentation label for a cancelled operation.
  ///
  /// In zh, this message translates to:
  /// **'操作已取消。'**
  String get failureCancelled;

  /// Safe presentation label for a TLS certificate failure.
  ///
  /// In zh, this message translates to:
  /// **'安全连接校验失败，请检查网络或证书。'**
  String get failureCertificate;

  /// Safe presentation label for local data access failures.
  ///
  /// In zh, this message translates to:
  /// **'本地数据读取失败，请稍后重试。'**
  String get failureLocalData;

  /// Safe presentation label for file system failures.
  ///
  /// In zh, this message translates to:
  /// **'文件操作失败，请检查文件后重试。'**
  String get failureFile;

  /// Safe presentation label for an uncategorized platform failure.
  ///
  /// In zh, this message translates to:
  /// **'当前设备操作失败，请稍后重试。'**
  String get failurePlatform;

  /// 本机生成的历史记录作者名称
  ///
  /// In zh, this message translates to:
  /// **'本机'**
  String get historyAuthorLocal;

  /// 清空全部历史记录的按钮
  ///
  /// In zh, this message translates to:
  /// **'清空历史'**
  String get historyClearAction;

  /// 清空全部历史记录的确认说明
  ///
  /// In zh, this message translates to:
  /// **'将永久删除所有历史记录，此操作不可撤销。'**
  String get historyClearConfirmMessage;

  /// 清空全部历史记录的确认标题
  ///
  /// In zh, this message translates to:
  /// **'清空历史记录？'**
  String get historyClearConfirmTitle;

  /// 历史快照内容为空时显示的占位文本
  ///
  /// In zh, this message translates to:
  /// **'（清空内容）'**
  String get historyClearedContent;

  /// 较早历史记录的本地化日期及具体时间
  ///
  /// In zh, this message translates to:
  /// **'{date} {time}'**
  String historyDateAt(String date, String time);

  /// 删除单条历史记录的确认说明
  ///
  /// In zh, this message translates to:
  /// **'删除后无法恢复这条历史记录。'**
  String get historyDeleteConfirmMessage;

  /// 删除单条历史记录的确认标题
  ///
  /// In zh, this message translates to:
  /// **'删除这条历史记录？'**
  String get historyDeleteConfirmTitle;

  /// 删除单条历史记录按钮的提示
  ///
  /// In zh, this message translates to:
  /// **'删除这条记录'**
  String get historyDeleteRecordTooltip;

  /// 没有历史记录时的空状态说明
  ///
  /// In zh, this message translates to:
  /// **'编辑日历格子或便签会自动留痕'**
  String get historyEmptyHint;

  /// 没有历史记录时的空状态标题
  ///
  /// In zh, this message translates to:
  /// **'暂无历史记录'**
  String get historyEmptyTitle;

  /// 历史条目的时间、类型和目标摘要
  ///
  /// In zh, this message translates to:
  /// **'{relativeTime} · {kind} · {target}'**
  String historyEntryMetadata(String relativeTime, String kind, String target);

  /// 历史类型筛选的全部选项
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get historyFilterAll;

  /// 一分钟内发生的历史记录相对时间
  ///
  /// In zh, this message translates to:
  /// **'刚刚'**
  String get historyJustNow;

  /// 日历格子历史类型
  ///
  /// In zh, this message translates to:
  /// **'日历格子'**
  String get historyKindCell;

  /// 便签历史类型
  ///
  /// In zh, this message translates to:
  /// **'便签'**
  String get historyKindNote;

  /// message must be a safe localized category from failureLabel, never raw error details
  ///
  /// In zh, this message translates to:
  /// **'加载失败：{message}'**
  String historyLoadFailed(String message);

  /// 一小时内发生的历史记录相对时间及具体时间
  ///
  /// In zh, this message translates to:
  /// **'{count,plural, other{{count} 分钟前 · {time}}}'**
  String historyMinutesAgo(int count, String time);

  /// 覆盖较新内容前的恢复确认说明
  ///
  /// In zh, this message translates to:
  /// **'{date} 的当前内容比这条历史更新，恢复会覆盖较新内容。确定继续吗？'**
  String historyNewerContentMessage(String date);

  /// 历史快照与当前内容冲突时的确认标题
  ///
  /// In zh, this message translates to:
  /// **'当前内容更新'**
  String get historyNewerContentTitle;

  /// 历史搜索或筛选无结果时的说明
  ///
  /// In zh, this message translates to:
  /// **'换个关键词或筛选条件试试'**
  String get historyNoMatchesHint;

  /// 历史搜索或筛选无结果时的标题
  ///
  /// In zh, this message translates to:
  /// **'没有匹配的历史'**
  String get historyNoMatchesTitle;

  /// 无标题便签被删除时生成的历史内容
  ///
  /// In zh, this message translates to:
  /// **'删除便签'**
  String get historyNoteRemoved;

  /// 有标题便签被删除时生成的历史内容
  ///
  /// In zh, this message translates to:
  /// **'删除便签：{title}'**
  String historyNoteRemovedWithTitle(String title);

  /// 便签标题与摘要不同时生成的历史内容
  ///
  /// In zh, this message translates to:
  /// **'{title}：{summary}'**
  String historyNoteWithSummary(String title, String summary);

  /// 恢复历史快照的按钮
  ///
  /// In zh, this message translates to:
  /// **'恢复'**
  String get historyRestoreAction;

  /// 检测到较新内容后取消恢复的提示
  ///
  /// In zh, this message translates to:
  /// **'当前内容更新，已取消恢复'**
  String get historyRestoreCancelled;

  /// 历史快照恢复失败的提示
  ///
  /// In zh, this message translates to:
  /// **'恢复失败，请稍后重试'**
  String get historyRestoreFailed;

  /// 历史记录不是可恢复快照时的提示
  ///
  /// In zh, this message translates to:
  /// **'这条记录无法恢复'**
  String get historyRestoreInvalid;

  /// 恢复历史快照的确认说明
  ///
  /// In zh, this message translates to:
  /// **'将 {date} 的格子内容恢复为这条历史快照？'**
  String historyRestoreMessage(String date);

  /// 恢复历史快照的确认标题
  ///
  /// In zh, this message translates to:
  /// **'恢复历史内容'**
  String get historyRestoreTitle;

  /// 历史快照恢复成功的提示
  ///
  /// In zh, this message translates to:
  /// **'已恢复到 {date}'**
  String historyRestoredMessage(String date);

  /// 历史内容搜索框提示
  ///
  /// In zh, this message translates to:
  /// **'搜索历史内容…'**
  String get historySearchHint;

  /// 历史页标题，包含历史条目总数
  ///
  /// In zh, this message translates to:
  /// **'{count,plural, other{历史记录（{count}）}}'**
  String historyTitle(int count);

  /// 今天发生的历史记录相对时间及具体时间
  ///
  /// In zh, this message translates to:
  /// **'今天 {time}'**
  String historyTodayAt(String time);

  /// 当前筛选条件下可见的历史条目数量
  ///
  /// In zh, this message translates to:
  /// **'{count,plural, other{显示 {count} 条}}'**
  String historyVisibleCount(int count);

  /// 历史按日期分组时的昨天标签
  ///
  /// In zh, this message translates to:
  /// **'昨天'**
  String get historyYesterday;

  /// 昨天发生的历史记录相对时间及具体时间
  ///
  /// In zh, this message translates to:
  /// **'昨天 {time}'**
  String historyYesterdayAt(String time);

  /// Localized desktop text: importCancelled
  ///
  /// In zh, this message translates to:
  /// **'已取消导入'**
  String get importCancelled;

  /// Localized desktop text: importChoosing
  ///
  /// In zh, this message translates to:
  /// **'请选择要导入的文件…'**
  String get importChoosing;

  /// message must be a safe localized category from caughtErrorLabel, never raw exception details
  ///
  /// In zh, this message translates to:
  /// **'导入失败：{message}'**
  String importFailed(String message);

  /// Localized desktop text: importInvalidFormat
  ///
  /// In zh, this message translates to:
  /// **'导入失败：文件格式不正确'**
  String get importInvalidFormat;

  /// Localized desktop text: importSummary
  ///
  /// In zh, this message translates to:
  /// **'导入完成，共 {imported} 条记录，发现 {conflicts} 个日期冲突。'**
  String importSummary(int imported, int conflicts);

  /// Localized desktop text: languageChinese
  ///
  /// In zh, this message translates to:
  /// **'简体中文'**
  String get languageChinese;

  /// Localized desktop text: languageEnglish
  ///
  /// In zh, this message translates to:
  /// **'英语'**
  String get languageEnglish;

  /// Localized desktop text: navAccountSync
  ///
  /// In zh, this message translates to:
  /// **'账号同步'**
  String get navAccountSync;

  /// Localized desktop text: navAnonymousAccount
  ///
  /// In zh, this message translates to:
  /// **'未登录'**
  String get navAnonymousAccount;

  /// Localized desktop text: navCalendar
  ///
  /// In zh, this message translates to:
  /// **'日历'**
  String get navCalendar;

  /// Localized desktop text: navGoToToday
  ///
  /// In zh, this message translates to:
  /// **'返回今天'**
  String get navGoToToday;

  /// Localized desktop text: navHideToTray
  ///
  /// In zh, this message translates to:
  /// **'隐藏到托盘（右键托盘图标可退出）'**
  String get navHideToTray;

  /// Localized desktop text: navHistory
  ///
  /// In zh, this message translates to:
  /// **'历史'**
  String get navHistory;

  /// Localized desktop text: navNextMonth
  ///
  /// In zh, this message translates to:
  /// **'下个月'**
  String get navNextMonth;

  /// Localized desktop text: navPreviousMonth
  ///
  /// In zh, this message translates to:
  /// **'上个月'**
  String get navPreviousMonth;

  /// Localized desktop text: navReminderStatus
  ///
  /// In zh, this message translates to:
  /// **'提醒（已安排 {count} 条）'**
  String navReminderStatus(int count);

  /// Localized desktop text: navSearch
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get navSearch;

  /// Localized desktop text: navSearchAction
  ///
  /// In zh, this message translates to:
  /// **'搜索日历与清单'**
  String get navSearchAction;

  /// Localized desktop text: navToggleTheme
  ///
  /// In zh, this message translates to:
  /// **'切换主题'**
  String get navToggleTheme;

  /// Localized desktop text: navTransfer
  ///
  /// In zh, this message translates to:
  /// **'导入导出'**
  String get navTransfer;

  /// Localized desktop text: noteTitle
  ///
  /// In zh, this message translates to:
  /// **'便签'**
  String get noteTitle;

  /// 添加便签单行按钮
  ///
  /// In zh, this message translates to:
  /// **'添加一行'**
  String get notesAddLine;

  /// 便签背景颜色区域标题
  ///
  /// In zh, this message translates to:
  /// **'背景颜色'**
  String get notesBackgroundColor;

  /// 删除便签单行按钮提示
  ///
  /// In zh, this message translates to:
  /// **'删除此行'**
  String get notesDeleteLine;

  /// 便签编辑弹窗标题
  ///
  /// In zh, this message translates to:
  /// **'编辑便签'**
  String get notesEditNote;

  /// 便签已不存在时的提示
  ///
  /// In zh, this message translates to:
  /// **'便签不存在或已被删除'**
  String get notesEditorMissing;

  /// 便签编辑弹窗标题
  ///
  /// In zh, this message translates to:
  /// **'便签'**
  String get notesEditorTitle;

  /// 便签正文为空时显示的内容
  ///
  /// In zh, this message translates to:
  /// **'（空便签）'**
  String get notesEmpty;

  /// 便签列表为空状态说明
  ///
  /// In zh, this message translates to:
  /// **'点击右上角新建，便签可以独立窗口置顶显示'**
  String get notesEmptyHint;

  /// 便签列表为空状态标题
  ///
  /// In zh, this message translates to:
  /// **'暂无便签'**
  String get notesEmptyTitle;

  /// 便签管理页标题和便签数量
  ///
  /// In zh, this message translates to:
  /// **'{count, plural, =1{便签（{count}）} other{便签（{count}）}}'**
  String notesHeading(int count);

  /// 隐藏便签按钮提示
  ///
  /// In zh, this message translates to:
  /// **'隐藏'**
  String get notesHide;

  /// 修改便签单行文字颜色按钮提示
  ///
  /// In zh, this message translates to:
  /// **'此行文字颜色'**
  String get notesLineColor;

  /// 便签单行完成复选框无障碍标签
  ///
  /// In zh, this message translates to:
  /// **'标记此行完成'**
  String get notesMarkLineComplete;

  /// 新建便签按钮和新便签默认标题
  ///
  /// In zh, this message translates to:
  /// **'新建便签'**
  String get notesNewNote;

  /// 打开便签独立窗口按钮提示
  ///
  /// In zh, this message translates to:
  /// **'打开独立窗口'**
  String get notesOpenWindow;

  /// 切换便签窗口置顶按钮提示
  ///
  /// In zh, this message translates to:
  /// **'窗口置顶'**
  String get notesPinWindow;

  /// 便签已置顶标记
  ///
  /// In zh, this message translates to:
  /// **'置顶'**
  String get notesPinned;

  /// 显示便签按钮提示
  ///
  /// In zh, this message translates to:
  /// **'显示'**
  String get notesShow;

  /// 在独立窗口打开便签按钮
  ///
  /// In zh, this message translates to:
  /// **'独立窗口'**
  String get notesStandaloneWindow;

  /// 便签标题输入框标签
  ///
  /// In zh, this message translates to:
  /// **'标题'**
  String get notesTitleField;

  /// Localized desktop text: notesUnavailable
  ///
  /// In zh, this message translates to:
  /// **'暂无便签'**
  String get notesUnavailable;

  /// Localized desktop text: notificationChannel
  ///
  /// In zh, this message translates to:
  /// **'任务提醒'**
  String get notificationChannel;

  /// Localized desktop text: notificationChannelDescription
  ///
  /// In zh, this message translates to:
  /// **'日历任务与纪念日提醒'**
  String get notificationChannelDescription;

  /// Localized desktop text: notificationOpenCalendar
  ///
  /// In zh, this message translates to:
  /// **'打开日历'**
  String get notificationOpenCalendar;

  /// Acknowledgment action for a reminder
  ///
  /// In zh, this message translates to:
  /// **'知道了'**
  String get reminderAcknowledge;

  /// Accessibility tooltip for dismissing the reminder overlay
  ///
  /// In zh, this message translates to:
  /// **'关闭提醒'**
  String get reminderDismissTooltip;

  /// Action for dismissing the reminder window without showing it again
  ///
  /// In zh, this message translates to:
  /// **'不再显示窗口'**
  String get reminderDontShowAgain;

  /// Log message for a failed reminder cancellation; technical error details are logged separately
  ///
  /// In zh, this message translates to:
  /// **'取消提醒失败：{notificationId}'**
  String reminderLogCancelFailed(String notificationId);

  /// Log message for a failed reminder queue clear; technical error details are logged separately
  ///
  /// In zh, this message translates to:
  /// **'清空提醒失败'**
  String get reminderLogClearFailed;

  /// Log message when falling back to in-app reminders
  ///
  /// In zh, this message translates to:
  /// **'本地通知初始化失败，改用应用内提醒'**
  String get reminderLogInitializeFailed;

  /// Log message after local notification initialization succeeds
  ///
  /// In zh, this message translates to:
  /// **'本地通知插件初始化完成'**
  String get reminderLogInitialized;

  /// Log message for a failed reminder schedule; technical error details are logged separately
  ///
  /// In zh, this message translates to:
  /// **'提醒调度失败：{eventId}'**
  String reminderLogScheduleFailed(String eventId);

  /// Local notification body with localized occurrence date and reminder time
  ///
  /// In zh, this message translates to:
  /// **'{date} {time}'**
  String reminderNotificationBody(String date, String time);

  /// message must be a safe localized category from failureLabel, never raw error details
  ///
  /// In zh, this message translates to:
  /// **'重新安排提醒失败：{message}'**
  String reminderRescheduleFailed(String message);

  /// Title of an in-app or fallback task reminder
  ///
  /// In zh, this message translates to:
  /// **'任务提醒'**
  String get reminderTaskTitle;

  /// 尚未选择自定义日期范围时的按钮
  ///
  /// In zh, this message translates to:
  /// **'选择自定义范围'**
  String get searchChooseCustomRange;

  /// 清空搜索关键词按钮的提示
  ///
  /// In zh, this message translates to:
  /// **'清空搜索'**
  String get searchClearQueryTooltip;

  /// 课程搜索结果所属课表、星期及节次
  ///
  /// In zh, this message translates to:
  /// **'{course} · 周{weekday} 第{period}节'**
  String searchCourseSubtitle(String course, String weekday, int period);

  /// 已选择的自定义日期范围摘要
  ///
  /// In zh, this message translates to:
  /// **'{start} 至 {end}'**
  String searchCustomRangeLabel(String start, String end);

  /// 搜索无结果时的空状态说明
  ///
  /// In zh, this message translates to:
  /// **'输入关键词后即时检索全部模块'**
  String get searchEmptyHint;

  /// 搜索无结果时的空状态标题
  ///
  /// In zh, this message translates to:
  /// **'没有匹配内容'**
  String get searchEmptyTitle;

  /// 日历事件搜索结果的发生日期及重复规则
  ///
  /// In zh, this message translates to:
  /// **'{date} · {recurrence}'**
  String searchEventSubtitle(String date, String recurrence);

  /// 搜索框输入提示
  ///
  /// In zh, this message translates to:
  /// **'内容、任务、便签、倒数日、订阅、课程'**
  String get searchFieldHint;

  /// 搜索框标签
  ///
  /// In zh, this message translates to:
  /// **'搜日历清单'**
  String get searchFieldLabel;

  /// 日历单元格搜索结果类型
  ///
  /// In zh, this message translates to:
  /// **'单元格'**
  String get searchKindCell;

  /// 倒数日搜索结果类型
  ///
  /// In zh, this message translates to:
  /// **'倒数日'**
  String get searchKindCountdown;

  /// 课程搜索结果类型
  ///
  /// In zh, this message translates to:
  /// **'课程'**
  String get searchKindCourse;

  /// 便签搜索结果类型
  ///
  /// In zh, this message translates to:
  /// **'便签'**
  String get searchKindNote;

  /// 订阅搜索结果类型
  ///
  /// In zh, this message translates to:
  /// **'订阅'**
  String get searchKindSubscription;

  /// 搜索全部日期范围
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get searchRangeAll;

  /// 搜索自定义日期范围
  ///
  /// In zh, this message translates to:
  /// **'自定义'**
  String get searchRangeCustom;

  /// 搜索最近一个月
  ///
  /// In zh, this message translates to:
  /// **'近一月'**
  String get searchRangeOneMonth;

  /// 搜索最近一年
  ///
  /// In zh, this message translates to:
  /// **'近一年'**
  String get searchRangeOneYear;

  /// 搜索最近三个月
  ///
  /// In zh, this message translates to:
  /// **'近三月'**
  String get searchRangeThreeMonths;

  /// 搜索结果总数
  ///
  /// In zh, this message translates to:
  /// **'{count,plural, other{共找到 {count} 条结果}}'**
  String searchResultCount(int count);

  /// 订阅搜索结果所属订阅及发生日期
  ///
  /// In zh, this message translates to:
  /// **'{name} · {date}'**
  String searchSubscriptionSubtitle(String name, String date);

  /// 关于页应用名称和版本号
  ///
  /// In zh, this message translates to:
  /// **'{appTitle} {version}'**
  String settingsAboutAppVersion(String appTitle, String version);

  /// 关于和数据设置分组标题
  ///
  /// In zh, this message translates to:
  /// **'关于 / 数据'**
  String get settingsAboutData;

  /// 高级设置分组标题
  ///
  /// In zh, this message translates to:
  /// **'高级设置'**
  String get settingsAdvanced;

  /// 立即应用桌面壁纸按钮
  ///
  /// In zh, this message translates to:
  /// **'立即应用到桌面'**
  String get settingsApplyToDesktop;

  /// 自动检查更新开关
  ///
  /// In zh, this message translates to:
  /// **'自动检查更新'**
  String get settingsAutoCheckUpdates;

  /// 未完成任务自动顺延开关
  ///
  /// In zh, this message translates to:
  /// **'未完成任务 30 天内自动顺延'**
  String get settingsAutoDelay;

  /// 任务项目符号设置标签
  ///
  /// In zh, this message translates to:
  /// **'项目符号'**
  String get settingsBulletStyle;

  /// 日历颜色选择器的无障碍标签
  ///
  /// In zh, this message translates to:
  /// **'日历颜色'**
  String get settingsCalendarColors;

  /// 日历显示设置分组标题
  ///
  /// In zh, this message translates to:
  /// **'日历显示'**
  String get settingsCalendarDisplay;

  /// 日历字号设置标签
  ///
  /// In zh, this message translates to:
  /// **'日历字号'**
  String get settingsCalendarFontSize;

  /// 日历透明度设置标签
  ///
  /// In zh, this message translates to:
  /// **'日历透明度'**
  String get settingsCalendarOpacity;

  /// 单元格间距设置标签
  ///
  /// In zh, this message translates to:
  /// **'单元格间距'**
  String get settingsCellGap;

  /// 单元格设置分组标题
  ///
  /// In zh, this message translates to:
  /// **'单元格'**
  String get settingsCellSection;

  /// 立即检查更新按钮
  ///
  /// In zh, this message translates to:
  /// **'立即检查'**
  String get settingsCheckNow;

  /// 检查更新设置项标题
  ///
  /// In zh, this message translates to:
  /// **'检查更新'**
  String get settingsCheckUpdates;

  /// 选择壁纸图片目录按钮
  ///
  /// In zh, this message translates to:
  /// **'选择图片目录'**
  String get settingsChooseImageDirectory;

  /// 清除壁纸图片目录按钮提示
  ///
  /// In zh, this message translates to:
  /// **'清除图片目录'**
  String get settingsClearImageDirectory;

  /// 云同步设置项标题
  ///
  /// In zh, this message translates to:
  /// **'云同步'**
  String get settingsCloudSync;

  /// 已完成任务排序开关
  ///
  /// In zh, this message translates to:
  /// **'完成项目排到最后'**
  String get settingsCompletedLast;

  /// 内容字号设置标签
  ///
  /// In zh, this message translates to:
  /// **'内容字号'**
  String get settingsContentFontSize;

  /// 倒数日透明度设置标签
  ///
  /// In zh, this message translates to:
  /// **'倒数日透明度'**
  String get settingsCountdownOpacity;

  /// 桌面设置分组标题
  ///
  /// In zh, this message translates to:
  /// **'桌面'**
  String get settingsDesktop;

  /// 可编辑桌面组件交互说明
  ///
  /// In zh, this message translates to:
  /// **'组件常驻所有窗口下面，卡片内可直接输入/勾选/拖动，卡片外点击穿透到桌面图标。'**
  String get settingsDesktopBehavior;

  /// 桌面设置分组说明
  ///
  /// In zh, this message translates to:
  /// **'可编辑月历组件常驻桌面层；静态壁纸快照仅作可选备份'**
  String get settingsDesktopDescription;

  /// 桌面组件已隐藏状态
  ///
  /// In zh, this message translates to:
  /// **'桌面组件：已隐藏'**
  String get settingsDesktopWidgetHidden;

  /// 桌面组件已显示状态
  ///
  /// In zh, this message translates to:
  /// **'桌面组件：已显示（可编辑）'**
  String get settingsDesktopWidgetVisible;

  /// 日历显示模式设置标签
  ///
  /// In zh, this message translates to:
  /// **'显示模式'**
  String get settingsDisplayMode;

  /// 可编辑桌面月历开关
  ///
  /// In zh, this message translates to:
  /// **'在桌面上显示可编辑月历（真·桌面层）'**
  String get settingsEditableDesktopCalendar;

  /// 节日、农历和节气显示开关
  ///
  /// In zh, this message translates to:
  /// **'显示节日 / 农历 / 节气'**
  String get settingsFestivalInfo;

  /// 字体和颜色设置分组标题
  ///
  /// In zh, this message translates to:
  /// **'字体和颜色'**
  String get settingsFontColors;

  /// 透明玻璃效果开关
  ///
  /// In zh, this message translates to:
  /// **'显示透明玻璃效果'**
  String get settingsGlassEffect;

  /// 显示隐藏快捷键开关
  ///
  /// In zh, this message translates to:
  /// **'Crtl+H 显示隐藏 / 快捷键开关'**
  String get settingsHideHotkey;

  /// 法定节假日显示开关
  ///
  /// In zh, this message translates to:
  /// **'显示法定节假日'**
  String get settingsHolidays;

  /// 热搜和浮动按钮显示开关
  ///
  /// In zh, this message translates to:
  /// **'显示热搜 / 浮动按钮'**
  String get settingsHotSearchFloating;

  /// IE 代理设置开关
  ///
  /// In zh, this message translates to:
  /// **'使用 IE 代理设置'**
  String get settingsIeProxy;

  /// 黄历宜忌显示开关
  ///
  /// In zh, this message translates to:
  /// **'显示黄历宜忌'**
  String get settingsJiyi;

  /// 应用语言设置标签
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get settingsLanguage;

  /// 日历显示设置分组说明
  ///
  /// In zh, this message translates to:
  /// **'对应旧版「日历」设置页'**
  String get settingsLegacyCalendarHint;

  /// 日历内容行间距设置标签
  ///
  /// In zh, this message translates to:
  /// **'行间距'**
  String get settingsLineSpacing;

  /// 农历显示开关
  ///
  /// In zh, this message translates to:
  /// **'显示农历'**
  String get settingsLunar;

  /// 月历辅助信息显示开关
  ///
  /// In zh, this message translates to:
  /// **'显示月间隔 / 周数 / 阴影 / 标题栏'**
  String get settingsMonthDetails;

  /// 未选择壁纸图片目录时的提示
  ///
  /// In zh, this message translates to:
  /// **'未选择图片目录'**
  String get settingsNoImageDirectory;

  /// 便签行间距设置标签
  ///
  /// In zh, this message translates to:
  /// **'行间距'**
  String get settingsNotesLineSpacing;

  /// 便签透明度设置标签
  ///
  /// In zh, this message translates to:
  /// **'便签透明度'**
  String get settingsNotesOpacity;

  /// 便签设置分组标题
  ///
  /// In zh, this message translates to:
  /// **'便签'**
  String get settingsNotesSection;

  /// 提醒提示音设置标签
  ///
  /// In zh, this message translates to:
  /// **'提醒提示音'**
  String get settingsReminderTone;

  /// 重新排程全部提醒按钮
  ///
  /// In zh, this message translates to:
  /// **'重排提醒'**
  String get settingsRescheduleReminders;

  /// 恢复默认设置按钮
  ///
  /// In zh, this message translates to:
  /// **'恢复默认设置'**
  String get settingsRestoreDefaults;

  /// 恢复系统原始壁纸按钮
  ///
  /// In zh, this message translates to:
  /// **'恢复系统原壁纸'**
  String get settingsRestoreSystemWallpaper;

  /// 已排程提醒数量
  ///
  /// In zh, this message translates to:
  /// **'{count, plural, =1{已排程提醒 {count} 条} other{已排程提醒 {count} 条}}'**
  String settingsScheduledReminders(int count);

  /// 搜索引擎设置标签
  ///
  /// In zh, this message translates to:
  /// **'搜索引擎'**
  String get settingsSearchEngine;

  /// 百度搜索引擎
  ///
  /// In zh, this message translates to:
  /// **'百度'**
  String get settingsSearchEngineBaidu;

  /// 必应搜索引擎
  ///
  /// In zh, this message translates to:
  /// **'必应'**
  String get settingsSearchEngineBing;

  /// 显示所有便签开关
  ///
  /// In zh, this message translates to:
  /// **'显示所有便签'**
  String get settingsShowAllNotes;

  /// 已完成任务显示开关
  ///
  /// In zh, this message translates to:
  /// **'显示已完成项目'**
  String get settingsShowCompleted;

  /// 提醒时间显示开关
  ///
  /// In zh, this message translates to:
  /// **'显示提醒时间'**
  String get settingsShowReminderTime;

  /// 节气显示开关
  ///
  /// In zh, this message translates to:
  /// **'显示节气'**
  String get settingsSolarTerms;

  /// 每周起始日期设置标签
  ///
  /// In zh, this message translates to:
  /// **'周起始日'**
  String get settingsStartOfWeek;

  /// 开机自启开关
  ///
  /// In zh, this message translates to:
  /// **'开机自启（随 Windows 启动）'**
  String get settingsStartWithWindows;

  /// 静态壁纸已生成状态
  ///
  /// In zh, this message translates to:
  /// **'静态壁纸：已生成'**
  String get settingsStaticWallpaperGenerated;

  /// 静态壁纸未启用状态
  ///
  /// In zh, this message translates to:
  /// **'静态壁纸：未启用'**
  String get settingsStaticWallpaperNotEnabled;

  /// 静态壁纸快照开关
  ///
  /// In zh, this message translates to:
  /// **'（可选）生成静态壁纸快照'**
  String get settingsStaticWallpaperSnapshot;

  /// 应用架构和本地存储名称说明
  ///
  /// In zh, this message translates to:
  /// **'Clean DDD + Riverpod · 本地存储：{storageName}'**
  String settingsStorageName(String storageName);

  /// 立即同步按钮
  ///
  /// In zh, this message translates to:
  /// **'立即同步'**
  String get settingsSyncNow;

  /// 设置页关于页签
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get settingsTabAbout;

  /// 设置页高级页签
  ///
  /// In zh, this message translates to:
  /// **'高级'**
  String get settingsTabAdvanced;

  /// 设置页日历页签
  ///
  /// In zh, this message translates to:
  /// **'日历'**
  String get settingsTabCalendar;

  /// 设置页单元格页签
  ///
  /// In zh, this message translates to:
  /// **'单元格'**
  String get settingsTabCell;

  /// 设置页字体和颜色页签
  ///
  /// In zh, this message translates to:
  /// **'字体和颜色'**
  String get settingsTabFontColors;

  /// 设置页便签页签
  ///
  /// In zh, this message translates to:
  /// **'便签'**
  String get settingsTabNotes;

  /// 设置页壁纸页签
  ///
  /// In zh, this message translates to:
  /// **'壁纸'**
  String get settingsTabWallpaper;

  /// 任务完成提示音设置标签
  ///
  /// In zh, this message translates to:
  /// **'完成提示音'**
  String get settingsTaskCompleteTone;

  /// 应用主题设置标签
  ///
  /// In zh, this message translates to:
  /// **'主题'**
  String get settingsTheme;

  /// 日历显示月份列数的滑块值
  ///
  /// In zh, this message translates to:
  /// **'{count, plural, =1{{count} 列} other{{count} 列}}'**
  String settingsVisibleColumns(int count);

  /// 日历显示月份列数设置标签
  ///
  /// In zh, this message translates to:
  /// **'显示月份列'**
  String get settingsVisibleColumnsLabel;

  /// 日历显示行数的滑块值
  ///
  /// In zh, this message translates to:
  /// **'{count, plural, =1{{count} 行} other{{count} 行}}'**
  String settingsVisibleRows(int count);

  /// 日历显示行数设置标签
  ///
  /// In zh, this message translates to:
  /// **'显示行数'**
  String get settingsVisibleRowsLabel;

  /// 壁纸图片适配方式设置标签
  ///
  /// In zh, this message translates to:
  /// **'图片适配'**
  String get settingsWallpaperFit;

  /// 裁切并铺满的图片适配方式
  ///
  /// In zh, this message translates to:
  /// **'填充（裁切铺满）'**
  String get settingsWallpaperFitFill;

  /// 完整显示图片的适配方式
  ///
  /// In zh, this message translates to:
  /// **'适应（完整显示）'**
  String get settingsWallpaperFitFit;

  /// 拉伸图片的适配方式
  ///
  /// In zh, this message translates to:
  /// **'拉伸'**
  String get settingsWallpaperFitStretch;

  /// 壁纸底图模式设置标签
  ///
  /// In zh, this message translates to:
  /// **'壁纸底图'**
  String get settingsWallpaperImage;

  /// 壁纸切换间隔设置标签
  ///
  /// In zh, this message translates to:
  /// **'切换间隔（分钟）'**
  String get settingsWallpaperIntervalLabel;

  /// 壁纸切换间隔的滑块值
  ///
  /// In zh, this message translates to:
  /// **'{count, plural, =1{{count} 分钟} other{{count} 分钟}}'**
  String settingsWallpaperIntervalMinutes(int count);

  /// 循环显示目录中全部图片的开关
  ///
  /// In zh, this message translates to:
  /// **'循环目录下全部图片'**
  String get settingsWallpaperShowAll;

  /// 周序号显示开关
  ///
  /// In zh, this message translates to:
  /// **'显示周序号'**
  String get settingsWeekNumbers;

  /// 周起始日选项，weekday 为本地化星期名称
  ///
  /// In zh, this message translates to:
  /// **'周{weekday}'**
  String settingsWeekday(String weekday);

  /// 滴答提示音
  ///
  /// In zh, this message translates to:
  /// **'滴答'**
  String get soundToneDing;

  /// 叮当提示音
  ///
  /// In zh, this message translates to:
  /// **'叮当'**
  String get soundToneDing2;

  /// 叮咚提示音
  ///
  /// In zh, this message translates to:
  /// **'叮咚'**
  String get soundToneDing3;

  /// 咚提示音
  ///
  /// In zh, this message translates to:
  /// **'咚'**
  String get soundToneDong;

  /// 小星星提示音
  ///
  /// In zh, this message translates to:
  /// **'小星星'**
  String get soundToneLittleStar;

  /// 关闭提示音
  ///
  /// In zh, this message translates to:
  /// **'无'**
  String get soundToneNone;

  /// Localized desktop text: subWindowCommand
  ///
  /// In zh, this message translates to:
  /// **'子窗口指令：{command}'**
  String subWindowCommand(String command);

  /// 添加订阅按钮
  ///
  /// In zh, this message translates to:
  /// **'添加订阅'**
  String get subscriptionAdd;

  /// 复制订阅分享链接按钮提示
  ///
  /// In zh, this message translates to:
  /// **'复制分享链接'**
  String get subscriptionCopyLink;

  /// 添加订阅弹窗标题
  ///
  /// In zh, this message translates to:
  /// **'添加订阅日历'**
  String get subscriptionCreateTitle;

  /// 删除订阅按钮提示
  ///
  /// In zh, this message translates to:
  /// **'删除订阅'**
  String get subscriptionDelete;

  /// 订阅列表为空状态说明
  ///
  /// In zh, this message translates to:
  /// **'支持本地订阅与 Google / Outlook / iCloud / CalDAV'**
  String get subscriptionEmptyHint;

  /// 订阅列表为空状态标题
  ///
  /// In zh, this message translates to:
  /// **'暂无订阅日历'**
  String get subscriptionEmptyTitle;

  /// 订阅启用开关无障碍标签
  ///
  /// In zh, this message translates to:
  /// **'启用此订阅'**
  String get subscriptionEnabled;

  /// 订阅拉取失败时保留本地缓存的日志消息
  ///
  /// In zh, this message translates to:
  /// **'订阅拉取失败，保留本地缓存：{name}'**
  String subscriptionFetchFailed(String name);

  /// 订阅日历页标题和订阅数量
  ///
  /// In zh, this message translates to:
  /// **'{count, plural, =1{订阅日历（{count}）} other{订阅日历（{count}）}}'**
  String subscriptionHeading(int count);

  /// 订阅最近同步日期和时间
  ///
  /// In zh, this message translates to:
  /// **'最近同步：{date} {time}'**
  String subscriptionLastSyncedAt(String date, String time);

  /// 订阅名称输入框标签
  ///
  /// In zh, this message translates to:
  /// **'订阅名称'**
  String get subscriptionName;

  /// 订阅尚未同步状态
  ///
  /// In zh, this message translates to:
  /// **'尚未同步'**
  String get subscriptionNeverSynced;

  /// 订阅分享链接输入框标签
  ///
  /// In zh, this message translates to:
  /// **'分享链接（留空则生成本地订阅）'**
  String get subscriptionShareLinkHint;

  /// 订阅来源下拉框无障碍标签
  ///
  /// In zh, this message translates to:
  /// **'订阅来源'**
  String get subscriptionSource;

  /// CalDAV 订阅来源
  ///
  /// In zh, this message translates to:
  /// **'CalDAV'**
  String get subscriptionSourceCaldav;

  /// Google 日历订阅来源
  ///
  /// In zh, this message translates to:
  /// **'Google 日历'**
  String get subscriptionSourceGoogle;

  /// iCloud 日历订阅来源
  ///
  /// In zh, this message translates to:
  /// **'iCloud 日历'**
  String get subscriptionSourceIcloud;

  /// 本地订阅来源
  ///
  /// In zh, this message translates to:
  /// **'本地订阅'**
  String get subscriptionSourceLocal;

  /// Outlook 日历订阅来源
  ///
  /// In zh, this message translates to:
  /// **'Outlook 日历'**
  String get subscriptionSourceOutlook;

  /// 订阅来源、推送数量和最近同步时间
  ///
  /// In zh, this message translates to:
  /// **'{source} · {count, plural, =1{{count} 条推送} other{{count} 条推送}} · {lastSync}'**
  String subscriptionSummary(String source, int count, String lastSync);

  /// 同步单个订阅按钮
  ///
  /// In zh, this message translates to:
  /// **'同步'**
  String get subscriptionSync;

  /// 同步全部订阅按钮
  ///
  /// In zh, this message translates to:
  /// **'同步全部'**
  String get subscriptionSyncAll;

  /// message must be a safe localized category from failureLabel, never server or exception details
  ///
  /// In zh, this message translates to:
  /// **'同步失败：{message}'**
  String syncFailed(String message);

  /// message must be a safe localized category from failureLabel, never server or exception details
  ///
  /// In zh, this message translates to:
  /// **'{message}（已切换为本地账号）'**
  String syncLocalAccount(String message);

  /// Localized desktop text: syncLoginRequired
  ///
  /// In zh, this message translates to:
  /// **'请先登录账号后再同步'**
  String get syncLoginRequired;

  /// Localized desktop text: syncLoginSuccess
  ///
  /// In zh, this message translates to:
  /// **'登录成功'**
  String get syncLoginSuccess;

  /// Localized desktop text: syncSummary
  ///
  /// In zh, this message translates to:
  /// **'上传 {uploaded} 条记录，下载 {downloaded} 条记录。'**
  String syncSummary(int uploaded, int downloaded);

  /// 深色主题
  ///
  /// In zh, this message translates to:
  /// **'深色'**
  String get themeModeDark;

  /// 浅色主题
  ///
  /// In zh, this message translates to:
  /// **'浅色'**
  String get themeModeLight;

  /// 跟随系统主题
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get themeModeSystem;

  /// 添加课程按钮
  ///
  /// In zh, this message translates to:
  /// **'添加'**
  String get timetableAdd;

  /// 添加课程对话框标题
  ///
  /// In zh, this message translates to:
  /// **'添加课程（{weekday} 第{period}节）'**
  String timetableAddLessonTitle(String weekday, int period);

  /// 添加课程单元格图标提示
  ///
  /// In zh, this message translates to:
  /// **'添加课程（{weekday} 第{period}节）'**
  String timetableAddLessonTooltip(String weekday, int period);

  /// 课程名称输入框标签
  ///
  /// In zh, this message translates to:
  /// **'课程名称'**
  String get timetableCourseName;

  /// 课程表空状态提示
  ///
  /// In zh, this message translates to:
  /// **'支持单双周、节次时间与课程冲突检测'**
  String get timetableEmptyHint;

  /// 课程表空状态标题
  ///
  /// In zh, this message translates to:
  /// **'暂无课程表'**
  String get timetableEmptyTitle;

  /// 隐藏周末开关
  ///
  /// In zh, this message translates to:
  /// **'隐藏周末'**
  String get timetableHideWeekend;

  /// 新增课程发生时间冲突时的错误
  ///
  /// In zh, this message translates to:
  /// **'新增课程与其他课程有时间冲突'**
  String get timetableLessonConflict;

  /// 新建课程表按钮及默认名称
  ///
  /// In zh, this message translates to:
  /// **'新建课程表'**
  String get timetableNewName;

  /// 课程单双周选项：所有周
  ///
  /// In zh, this message translates to:
  /// **'全选'**
  String get timetableParityAll;

  /// 课程单双周选项：双周
  ///
  /// In zh, this message translates to:
  /// **'双周'**
  String get timetableParityEven;

  /// 课程单双周选项：单周
  ///
  /// In zh, this message translates to:
  /// **'单周'**
  String get timetableParityOdd;

  /// 课程表节次列标题
  ///
  /// In zh, this message translates to:
  /// **'节次'**
  String get timetablePeriod;

  /// 每天节次数标签
  ///
  /// In zh, this message translates to:
  /// **'每天节次'**
  String get timetablePeriodsPerDay;

  /// 每天节次数
  ///
  /// In zh, this message translates to:
  /// **'{count, plural, =1{1 节} other{{count} 节}}'**
  String timetablePeriodsPerDayCount(int count);

  /// 删除课程单元格提示
  ///
  /// In zh, this message translates to:
  /// **'删除课程{name}'**
  String timetableRemoveLessonTooltip(String name);

  /// 删除课程表图标提示
  ///
  /// In zh, this message translates to:
  /// **'删除{name}'**
  String timetableRemoveTooltip(String name);

  /// 学期周数标签
  ///
  /// In zh, this message translates to:
  /// **'学期周数'**
  String get timetableSemesterWeeks;

  /// 打开课程表设置按钮
  ///
  /// In zh, this message translates to:
  /// **'课程表设置'**
  String get timetableSettings;

  /// 课程表设置对话框标题
  ///
  /// In zh, this message translates to:
  /// **'课程表设置：{name}'**
  String timetableSettingsTitle(String name);

  /// 开学日期标签
  ///
  /// In zh, this message translates to:
  /// **'开学日期'**
  String get timetableStartDate;

  /// 课程表卡片摘要
  ///
  /// In zh, this message translates to:
  /// **'{startDate} 开学 · {weeks, plural, =1{1 周} other{{weeks} 周}}'**
  String timetableSummary(String startDate, int weeks);

  /// Localized desktop text: timetableTitle
  ///
  /// In zh, this message translates to:
  /// **'课程表'**
  String get timetableTitle;

  /// 学期周数
  ///
  /// In zh, this message translates to:
  /// **'{count, plural, =1{1 周} other{{count} 周}}'**
  String timetableWeeksCount(int count);

  /// 选择文件并导入按钮
  ///
  /// In zh, this message translates to:
  /// **'选择文件并导入'**
  String get transferChooseAndImport;

  /// 支持的导出格式说明
  ///
  /// In zh, this message translates to:
  /// **'支持再次导入的数据库文件、可打印文本、Excel 兼容 CSV'**
  String get transferExportSubtitle;

  /// 导出区域标题
  ///
  /// In zh, this message translates to:
  /// **'导出日历清单'**
  String get transferExportTitle;

  /// 导出到文件按钮
  ///
  /// In zh, this message translates to:
  /// **'导出到文件'**
  String get transferExportToFile;

  /// 导出格式：Excel 兼容 CSV
  ///
  /// In zh, this message translates to:
  /// **'Excel 文件（CSV）'**
  String get transferFormatCsv;

  /// 导出格式：可再次导入的数据库文件
  ///
  /// In zh, this message translates to:
  /// **'数据库文件（可再导入）'**
  String get transferFormatDatabase;

  /// 导出格式：文本文件
  ///
  /// In zh, this message translates to:
  /// **'文本文件'**
  String get transferFormatText;

  /// 导入数据库文件说明
  ///
  /// In zh, this message translates to:
  /// **'从 `*.json` 数据库文件恢复单元格与任务'**
  String get transferImportSubtitle;

  /// 导入区域标题
  ///
  /// In zh, this message translates to:
  /// **'导入日历清单'**
  String get transferImportTitle;

  /// 导出范围：所有时间
  ///
  /// In zh, this message translates to:
  /// **'所有时间'**
  String get transferRangeAllTime;

  /// 导出范围：自定义
  ///
  /// In zh, this message translates to:
  /// **'自定义'**
  String get transferRangeCustom;

  /// 导出范围：近半年
  ///
  /// In zh, this message translates to:
  /// **'近半年'**
  String get transferRangeSixMonths;

  /// 导入时替换冲突内容选项
  ///
  /// In zh, this message translates to:
  /// **'所有冲突都替换为导入内容'**
  String get transferReplaceConflicts;

  /// Localized desktop text: trayAbout
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get trayAbout;

  /// Localized desktop text: trayExit
  ///
  /// In zh, this message translates to:
  /// **'退出'**
  String get trayExit;

  /// Localized desktop text: trayHide
  ///
  /// In zh, this message translates to:
  /// **'隐藏主窗口'**
  String get trayHide;

  /// Localized desktop text: trayHideWidget
  ///
  /// In zh, this message translates to:
  /// **'隐藏桌面日历窗口'**
  String get trayHideWidget;

  /// Localized desktop text: trayNotes
  ///
  /// In zh, this message translates to:
  /// **'便签'**
  String get trayNotes;

  /// Localized desktop text: trayRefreshWallpaper
  ///
  /// In zh, this message translates to:
  /// **'刷新壁纸'**
  String get trayRefreshWallpaper;

  /// Localized desktop text: traySettings
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get traySettings;

  /// Localized desktop text: trayShow
  ///
  /// In zh, this message translates to:
  /// **'显示主窗口'**
  String get trayShow;

  /// Localized desktop text: trayShowWidget
  ///
  /// In zh, this message translates to:
  /// **'显示桌面日历窗口'**
  String get trayShowWidget;

  /// Localized desktop text: traySync
  ///
  /// In zh, this message translates to:
  /// **'手动同步'**
  String get traySync;

  /// Localized desktop text: wallpaperFailed
  ///
  /// In zh, this message translates to:
  /// **'壁纸生成失败'**
  String get wallpaperFailed;

  /// Localized desktop text: wallpaperFooter
  ///
  /// In zh, this message translates to:
  /// **'今天 {date} · 周{weekday}    数据来自本地日历清单'**
  String wallpaperFooter(String date, String weekday);

  /// 从桌面抓取图片的壁纸模式
  ///
  /// In zh, this message translates to:
  /// **'从桌面抓取图片'**
  String get wallpaperModeDesktopCapture;

  /// 循环显示所选图片的壁纸模式
  ///
  /// In zh, this message translates to:
  /// **'循环显示选择的图片'**
  String get wallpaperModeRotation;

  /// 纯色桌面背景模式
  ///
  /// In zh, this message translates to:
  /// **'设置桌面背景颜色'**
  String get wallpaperModeSolidColor;

  /// Localized desktop text: wallpaperRejected
  ///
  /// In zh, this message translates to:
  /// **'系统拒绝设置壁纸'**
  String get wallpaperRejected;

  /// Localized desktop text: wallpaperRestored
  ///
  /// In zh, this message translates to:
  /// **'已恢复系统原壁纸'**
  String get wallpaperRestored;

  /// Localized desktop text: wallpaperSelectDirectory
  ///
  /// In zh, this message translates to:
  /// **'选择壁纸图片目录'**
  String get wallpaperSelectDirectory;

  /// Localized desktop text: wallpaperUpdated
  ///
  /// In zh, this message translates to:
  /// **'壁纸已更新'**
  String get wallpaperUpdated;

  /// Localized desktop text: widgetAddLine
  ///
  /// In zh, this message translates to:
  /// **'添加一行'**
  String get widgetAddLine;

  /// Localized desktop text: widgetAddLineTooltip
  ///
  /// In zh, this message translates to:
  /// **'添加一行'**
  String get widgetAddLineTooltip;

  /// Localized desktop text: widgetAddToDate
  ///
  /// In zh, this message translates to:
  /// **'添加到 {date}'**
  String widgetAddToDate(String date);

  /// Localized desktop text: widgetCellColor
  ///
  /// In zh, this message translates to:
  /// **'单元格颜色'**
  String get widgetCellColor;

  /// Localized desktop text: widgetCellColorTooltip
  ///
  /// In zh, this message translates to:
  /// **'选择单元格颜色'**
  String get widgetCellColorTooltip;

  /// Localized desktop text: widgetClearDay
  ///
  /// In zh, this message translates to:
  /// **'清空本日'**
  String get widgetClearDay;

  /// Localized desktop text: widgetClearTooltip
  ///
  /// In zh, this message translates to:
  /// **'清空本日内容'**
  String get widgetClearTooltip;

  /// Localized desktop text: widgetClosePalette
  ///
  /// In zh, this message translates to:
  /// **'关闭调色板'**
  String get widgetClosePalette;

  /// Accessibility label for dragging the desktop widget header.
  ///
  /// In zh, this message translates to:
  /// **'拖动以移动桌面日历'**
  String get widgetMoveHint;

  /// Accessibility label for the left resize handle.
  ///
  /// In zh, this message translates to:
  /// **'调整左边缘大小'**
  String get widgetResizeLeft;

  /// Accessibility label for the right resize handle.
  ///
  /// In zh, this message translates to:
  /// **'调整右边缘大小'**
  String get widgetResizeRight;

  /// Accessibility label for the top resize handle.
  ///
  /// In zh, this message translates to:
  /// **'调整上边缘大小'**
  String get widgetResizeTop;

  /// Accessibility label for the bottom resize handle.
  ///
  /// In zh, this message translates to:
  /// **'调整下边缘大小'**
  String get widgetResizeBottom;

  /// Accessibility label for the top-left resize handle.
  ///
  /// In zh, this message translates to:
  /// **'调整左上角大小'**
  String get widgetResizeTopLeft;

  /// Accessibility label for the top-right resize handle.
  ///
  /// In zh, this message translates to:
  /// **'调整右上角大小'**
  String get widgetResizeTopRight;

  /// Accessibility label for the bottom-left resize handle.
  ///
  /// In zh, this message translates to:
  /// **'调整左下角大小'**
  String get widgetResizeBottomLeft;

  /// Accessibility label for the bottom-right resize handle.
  ///
  /// In zh, this message translates to:
  /// **'调整右下角大小'**
  String get widgetResizeBottomRight;

  /// Localized desktop text: widgetCollapse
  ///
  /// In zh, this message translates to:
  /// **'收起桌面组件'**
  String get widgetCollapse;

  /// Localized desktop text: widgetCompleteTooltip
  ///
  /// In zh, this message translates to:
  /// **'标记完成'**
  String get widgetCompleteTooltip;

  /// Localized desktop text: widgetConfirmClear
  ///
  /// In zh, this message translates to:
  /// **'确认清空'**
  String get widgetConfirmClear;

  /// Localized desktop text: widgetEditingDate
  ///
  /// In zh, this message translates to:
  /// **'正在编辑 {date}'**
  String widgetEditingDate(String date);

  /// Localized desktop text: widgetFinishEditing
  ///
  /// In zh, this message translates to:
  /// **'完成编辑'**
  String get widgetFinishEditing;

  /// Localized desktop text: widgetFinishEditingTooltip
  ///
  /// In zh, this message translates to:
  /// **'保存并完成编辑'**
  String get widgetFinishEditingTooltip;

  /// Localized desktop text: widgetMarkComplete
  ///
  /// In zh, this message translates to:
  /// **'标记完成'**
  String get widgetMarkComplete;

  /// Localized desktop text: widgetNewLineHint
  ///
  /// In zh, this message translates to:
  /// **'回车新增一行…'**
  String get widgetNewLineHint;

  /// Localized desktop text: widgetPopupEditor
  ///
  /// In zh, this message translates to:
  /// **'浮层编辑'**
  String get widgetPopupEditor;

  /// Localized desktop text: widgetPopupEditorTooltip
  ///
  /// In zh, this message translates to:
  /// **'打开完整编辑器'**
  String get widgetPopupEditorTooltip;

  /// Localized desktop text: widgetPromote
  ///
  /// In zh, this message translates to:
  /// **'转为任务'**
  String get widgetPromote;

  /// Localized desktop text: widgetPromoteTooltip
  ///
  /// In zh, this message translates to:
  /// **'将这一行转为重复任务'**
  String get widgetPromoteTooltip;

  /// Localized desktop text: widgetQuickInputHint
  ///
  /// In zh, this message translates to:
  /// **'输入内容，回车添加'**
  String get widgetQuickInputHint;

  /// Localized desktop text: widgetTextColor
  ///
  /// In zh, this message translates to:
  /// **'文字颜色'**
  String get widgetTextColor;

  /// Localized desktop text: widgetTextColorTooltip
  ///
  /// In zh, this message translates to:
  /// **'选择文字颜色'**
  String get widgetTextColorTooltip;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'zh': return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
