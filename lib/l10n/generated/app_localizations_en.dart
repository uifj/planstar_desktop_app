// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get accountAutoSyncHourly => 'Sync automatically every hour';

  @override
  String get accountCloudSyncSubtitle => 'Changes → manual / automatic sync → status update';

  @override
  String get accountCloudSyncTitle => 'Cloud sync';

  @override
  String accountLastSyncAt(String dateTime) {
    return 'Last sync: $dateTime';
  }

  @override
  String get accountLoginOrRegister => 'Sign in / Register';

  @override
  String get accountLogout => 'Sign out';

  @override
  String get accountManualSync => 'Sync now';

  @override
  String get accountNeverSynced => 'Never synced';

  @override
  String accountPendingChanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pending changes',
      one: '1 pending change',
      zero: 'No pending changes',
    );
    return '$_temp0';
  }

  @override
  String get accountStatusFailure => 'Sync failed';

  @override
  String get accountStatusIdle => 'Idle';

  @override
  String get accountStatusSuccess => 'Sync succeeded';

  @override
  String get accountStatusSyncing => 'Syncing';

  @override
  String get accountSubtitle => 'Sign in to sync and back up your calendar lists';

  @override
  String get accountTitle => 'Account';

  @override
  String get appTitle => 'Planstar · Desktop Calendar & Checklist';

  @override
  String get bulletStyleDot => 'Dots';

  @override
  String get bulletStyleNone => 'None';

  @override
  String get bulletStyleNumber => 'Numbers';

  @override
  String get calendarAddCountdown => 'Add countdown';

  @override
  String get calendarAddLine => 'Add line';

  @override
  String get calendarAllColors => 'All colors';

  @override
  String get calendarCellColor => 'Cell color';

  @override
  String get calendarCellEditorEmptyHint => 'Double-click a cell or add a line to start recording';

  @override
  String get calendarClearAction => 'Clear';

  @override
  String calendarClearConfirmMessage(String target) {
    return 'All content in $target will be cleared. This action cannot be undone.';
  }

  @override
  String get calendarClearConfirmTitle => 'Confirm clear';

  @override
  String get calendarClearDayContent => 'Clear this day\'s content';

  @override
  String get calendarColorLabel => 'Colors';

  @override
  String get calendarColorPickerDescription => 'Text color / cell color';

  @override
  String get calendarColorPickerTitle => 'Choose a color';

  @override
  String calendarColorValue(String color) {
    return 'Color $color';
  }

  @override
  String get calendarContentHint => 'Enter a task or reminder';

  @override
  String get calendarContentLabel => 'Content';

  @override
  String get calendarCopyDayContent => 'Copy this day\'s content';

  @override
  String get calendarCountdownAdded => 'Countdown added';

  @override
  String calendarDateWithWeekday(String date, String weekday) {
    return '$date, $weekday';
  }

  @override
  String get calendarDayContent => 'this day\'s content';

  @override
  String get calendarDayContentCopied => 'This day\'s content has been copied';

  @override
  String get calendarDeleteRecurringEvent => 'Delete recurring task…';

  @override
  String get calendarDeleteRecurringEventTitle => 'Delete recurring task';

  @override
  String get calendarDeleteScopeAll => 'Delete all events';

  @override
  String get calendarDeleteScopeCurrent => 'Delete this event only';

  @override
  String get calendarDeleteScopeCurrentAndFuture => 'Delete this and all future events';

  @override
  String get calendarDeleteScopeRememberChoice => 'Use this choice for all conflicts';

  @override
  String get calendarDisplayModeFixedSingleLine => 'Fixed single row';

  @override
  String get calendarDisplayModeFloatingMonth => 'Floating month';

  @override
  String get calendarDisplayModeFloatingSingleLine => 'Floating single row';

  @override
  String get calendarDisplayModeFullMonth => 'Full month';

  @override
  String get calendarEditDayContent => 'Edit this day\'s content';

  @override
  String get calendarEditTaskOrReminder => 'Edit task / reminder';

  @override
  String get calendarEventTypeCountdown => 'Countdown anniversary';

  @override
  String get calendarEventTypeReminder => 'Reminder';

  @override
  String get calendarEventTypeSubscription => 'Subscription update';

  @override
  String get calendarEventTypeTask => 'Recurring task';

  @override
  String get calendarIntervalLabel => 'Interval';

  @override
  String get calendarLineTextColor => 'Line text color';

  @override
  String get calendarMakeRecurringTask => 'Make recurring task';

  @override
  String get calendarMakeupWorkdayBadge => 'Work';

  @override
  String get calendarMarkEventComplete => 'Mark task as complete';

  @override
  String get calendarMarkEventIncomplete => 'Mark task as incomplete';

  @override
  String get calendarMarkLineComplete => 'Mark as complete';

  @override
  String get calendarMarkLineIncomplete => 'Mark as incomplete';

  @override
  String get calendarNewTask => 'New task';

  @override
  String get calendarNewTaskOrReminder => 'New task / reminder';

  @override
  String get calendarNextMonth => 'Next month';

  @override
  String get calendarNoTasksOnDay => 'There are no tasks on this day';

  @override
  String get calendarOpenCountdownCard => 'Click to open the desktop card';

  @override
  String get calendarOpenDesktopNote => 'Open desktop note';

  @override
  String get calendarPasteToDay => 'Paste into this day';

  @override
  String get calendarPreviousMonth => 'Previous month';

  @override
  String get calendarRecurrenceCustomDay => 'Custom daily interval';

  @override
  String get calendarRecurrenceCustomMonthDay => 'Custom days of the month';

  @override
  String get calendarRecurrenceCustomMonthWeek => 'Custom weekday of the month';

  @override
  String get calendarRecurrenceCustomWeek => 'Custom weekly schedule';

  @override
  String get calendarRecurrenceCustomYear => 'Custom yearly interval';

  @override
  String get calendarRecurrenceDaily => 'Repeat daily';

  @override
  String get calendarRecurrenceEbbinghaus => 'Ebbinghaus review schedule';

  @override
  String get calendarRecurrenceLegalWorkday => 'Repeat on official workdays';

  @override
  String get calendarRecurrenceLunarYearly => 'Repeat on lunar anniversary';

  @override
  String get calendarRecurrenceMonthLastDay => 'Last day of each month';

  @override
  String get calendarRecurrenceMonthly => 'Repeat monthly';

  @override
  String get calendarRecurrenceNone => 'Does not repeat';

  @override
  String get calendarRecurrenceQuarterly => 'Repeat quarterly';

  @override
  String get calendarRecurrenceRule => 'Recurrence';

  @override
  String get calendarRecurrenceWeekly => 'Repeat weekly';

  @override
  String get calendarRecurrenceWorkday => 'Repeat on workdays';

  @override
  String get calendarRecurrenceYearly => 'Repeat yearly';

  @override
  String get calendarReminderCustom => 'Custom';

  @override
  String calendarReminderDaysBefore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# days before',
      one: '# day before',
    );
    return '$_temp0';
  }

  @override
  String get calendarReminderLabel => 'Reminder';

  @override
  String get calendarReminderSameDay => 'On the day';

  @override
  String get calendarRestDayBadge => 'Rest';

  @override
  String get calendarSetCellColor => 'Set cell color';

  @override
  String get calendarTextColor => 'Text color';

  @override
  String get calendarToday => 'Today';

  @override
  String get calendarTransparentColor => 'Transparent';

  @override
  String get calendarTypeLabel => 'Type';

  @override
  String get calendarWechatNotification => 'WeChat notifications';

  @override
  String calendarWeekNumberAccessibility(int week) {
    return 'Week $week';
  }

  @override
  String get calendarWeekdayFriday => 'Fri';

  @override
  String get calendarWeekdayLongFriday => 'Friday';

  @override
  String get calendarWeekdayLongMonday => 'Monday';

  @override
  String get calendarWeekdayLongSaturday => 'Saturday';

  @override
  String get calendarWeekdayLongSunday => 'Sunday';

  @override
  String get calendarWeekdayLongThursday => 'Thursday';

  @override
  String get calendarWeekdayLongTuesday => 'Tuesday';

  @override
  String get calendarWeekdayLongWednesday => 'Wednesday';

  @override
  String get calendarWeekdayMonday => 'Mon';

  @override
  String get calendarWeekdaySaturday => 'Sat';

  @override
  String get calendarWeekdaySunday => 'Sun';

  @override
  String get calendarWeekdayThursday => 'Thu';

  @override
  String get calendarWeekdayTuesday => 'Tue';

  @override
  String get calendarWeekdayWednesday => 'Wed';

  @override
  String get commonAdd => 'Add';

  @override
  String get commonAllColors => 'All colors';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonClose => 'Close';

  @override
  String get commonColorPickerHint => 'Text color / cell color';

  @override
  String get commonCountdowns => 'Countdowns';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonMaximize => 'Maximize';

  @override
  String get commonMinimize => 'Minimize';

  @override
  String get commonNoCountdowns => 'No countdowns yet';

  @override
  String get commonNotes => 'Notes';

  @override
  String get commonRecentColors => 'Recently used';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonSave => 'Save';

  @override
  String get commonSettings => 'Settings';

  @override
  String get commonSyncNow => 'Sync now';

  @override
  String get commonToday => 'Today';

  @override
  String countdownBirthdayAge(int age) {
    return 'Turning $age';
  }

  @override
  String get countdownCreate => 'New countdown';

  @override
  String get countdownCreated => 'Create';

  @override
  String countdownDaysRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days remaining',
      one: '$count day remaining',
    );
    return '$_temp0';
  }

  @override
  String countdownDaysSince(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days since',
      one: '$count day since',
    );
    return '$_temp0';
  }

  @override
  String countdownDeleteTooltip(String title) {
    return 'Delete countdown: $title';
  }

  @override
  String get countdownEmptyHint => 'Supports countdowns, elapsed days, birthdays and anniversaries';

  @override
  String get countdownEmptyTitle => 'No countdowns yet';

  @override
  String countdownExpiredDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Expired $count days ago',
      one: 'Expired $count day ago',
    );
    return '$_temp0';
  }

  @override
  String countdownLoadFailed(String message) {
    return 'Couldn\'t load countdowns: $message';
  }

  @override
  String get countdownNameField => 'Name';

  @override
  String get countdownOpenDesktopCard => 'Open desktop card';

  @override
  String get countdownShowTypeBoth => 'Both';

  @override
  String get countdownShowTypeCalendarBottom => 'Calendar bottom bar';

  @override
  String get countdownShowTypeDesktopCard => 'Desktop card';

  @override
  String get countdownShowTypeField => 'Display location';

  @override
  String countdownTargetDateValue(String date) {
    return 'Target date: $date';
  }

  @override
  String countdownTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Countdowns ($count)',
      one: 'Countdown ($count)',
    );
    return '$_temp0';
  }

  @override
  String get countdownTypeBirthday => 'Birthday';

  @override
  String get countdownTypeCustom => 'Countdown';

  @override
  String get countdownTypeExam => 'Exam';

  @override
  String get countdownTypeFestival => 'Festival';

  @override
  String get countdownTypeField => 'Type';

  @override
  String get countdownTypeMemorial => 'Anniversary';

  @override
  String get countdownWindowTitle => 'Countdown';

  @override
  String desktopWidgetFailed(String message) {
    return 'Failed to start the desktop widget: $message';
  }

  @override
  String get desktopWidgetHidden => 'Editable desktop calendar is now hidden';

  @override
  String get desktopWidgetShown => 'Editable desktop calendar is now visible';

  @override
  String get desktopWidgetTitle => 'Desktop calendar & checklist';

  @override
  String get exportCancelled => 'Export canceled';

  @override
  String get exportCellType => 'Calendar checklist';

  @override
  String get exportColumnColor => 'Color';

  @override
  String get exportColumnContent => 'Content';

  @override
  String get exportColumnDate => 'Date';

  @override
  String get exportColumnStatus => 'Status';

  @override
  String get exportColumnType => 'Type';

  @override
  String get exportCompleted => 'Completed';

  @override
  String exportFailed(String message) {
    return 'Export failed: $message';
  }

  @override
  String get exportIncomplete => 'Incomplete';

  @override
  String get exportPreparing => 'Preparing export…';

  @override
  String exportSuccess(String path) {
    return 'Export successful: $path';
  }

  @override
  String exportTextTitle(String date) {
    return 'Planstar calendar export · Exported $date';
  }

  @override
  String get failureGeneric => 'Something went wrong. Please try again.';

  @override
  String get failureNetwork => 'Network connection failed. Check your connection and try again.';

  @override
  String get failureOffline => 'You are offline. Check your connection and try again.';

  @override
  String get failureTimeout => 'The request timed out. Please try again.';

  @override
  String get failureAuthentication => 'Your sign-in is invalid. Please sign in again.';

  @override
  String get failureSessionExpired => 'Your session has expired. Please sign in again.';

  @override
  String get failureForbidden => 'You don\'t have permission to perform this action.';

  @override
  String get failureBadRequest => 'The request is invalid. Check your input and try again.';

  @override
  String get failureNotFound => 'The requested content could not be found. It may have been removed.';

  @override
  String get failureConflict => 'The data has changed. Refresh and try again.';

  @override
  String get failureRateLimit => 'Too many attempts. Please wait and try again.';

  @override
  String get failureServer => 'The service is temporarily unavailable. Please try again later.';

  @override
  String get failureData => 'Unable to read the data. Please try again.';

  @override
  String get failureValidation => 'The input is invalid. Check it and try again.';

  @override
  String get failureCancelled => 'The operation was cancelled.';

  @override
  String get failureCertificate => 'The secure connection could not be verified. Check your network or certificate.';

  @override
  String get failureLocalData => 'Unable to read local data. Please try again.';

  @override
  String get failureFile => 'The file operation failed. Check the file and try again.';

  @override
  String get failurePlatform => 'The device operation failed. Please try again.';

  @override
  String get historyAuthorLocal => 'This device';

  @override
  String get historyClearAction => 'Clear history';

  @override
  String get historyClearConfirmMessage => 'All history entries will be permanently deleted. This action cannot be undone.';

  @override
  String get historyClearConfirmTitle => 'Clear history?';

  @override
  String get historyClearedContent => '(Cleared content)';

  @override
  String historyDateAt(String date, String time) {
    return '$date at $time';
  }

  @override
  String get historyDeleteConfirmMessage => 'This history entry cannot be recovered after deletion.';

  @override
  String get historyDeleteConfirmTitle => 'Delete this history entry?';

  @override
  String get historyDeleteRecordTooltip => 'Delete this entry';

  @override
  String get historyEmptyHint => 'Editing calendar cells or notes automatically creates history';

  @override
  String get historyEmptyTitle => 'No history yet';

  @override
  String historyEntryMetadata(String relativeTime, String kind, String target) {
    return '$relativeTime · $kind · $target';
  }

  @override
  String get historyFilterAll => 'All';

  @override
  String get historyJustNow => 'Just now';

  @override
  String get historyKindCell => 'Calendar cell';

  @override
  String get historyKindNote => 'Note';

  @override
  String historyLoadFailed(String message) {
    return 'Unable to load history: $message';
  }

  @override
  String historyMinutesAgo(int count, String time) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes ago · $time',
      one: '$count minute ago · $time',
    );
    return '$_temp0';
  }

  @override
  String historyNewerContentMessage(String date) {
    return 'The current content for $date is newer than this history entry. Restoring will overwrite it. Continue?';
  }

  @override
  String get historyNewerContentTitle => 'Newer content exists';

  @override
  String get historyNoMatchesHint => 'Try another keyword or filter';

  @override
  String get historyNoMatchesTitle => 'No matching history';

  @override
  String get historyNoteRemoved => 'Deleted note';

  @override
  String historyNoteRemovedWithTitle(String title) {
    return 'Deleted note: $title';
  }

  @override
  String historyNoteWithSummary(String title, String summary) {
    return '$title: $summary';
  }

  @override
  String get historyRestoreAction => 'Restore';

  @override
  String get historyRestoreCancelled => 'Restore canceled because newer content exists';

  @override
  String get historyRestoreFailed => 'Restore failed. Please try again later';

  @override
  String get historyRestoreInvalid => 'This entry cannot be restored';

  @override
  String historyRestoreMessage(String date) {
    return 'Restore the calendar cell for $date to this history snapshot?';
  }

  @override
  String get historyRestoreTitle => 'Restore history content';

  @override
  String historyRestoredMessage(String date) {
    return 'Restored to $date';
  }

  @override
  String get historySearchHint => 'Search history…';

  @override
  String historyTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'History ($count entries)',
      one: 'History ($count entry)',
    );
    return '$_temp0';
  }

  @override
  String historyTodayAt(String time) {
    return 'Today at $time';
  }

  @override
  String historyVisibleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Showing $count entries',
      one: 'Showing $count entry',
    );
    return '$_temp0';
  }

  @override
  String get historyYesterday => 'Yesterday';

  @override
  String historyYesterdayAt(String time) {
    return 'Yesterday at $time';
  }

  @override
  String get importCancelled => 'Import canceled';

  @override
  String get importChoosing => 'Select a file to import…';

  @override
  String importFailed(String message) {
    return 'Import failed: $message';
  }

  @override
  String get importInvalidFormat => 'Import failed: Invalid file format';

  @override
  String importSummary(int imported, int conflicts) {
    return 'Import complete: $imported records imported, with $conflicts date conflicts.';
  }

  @override
  String get languageChinese => 'Chinese (Simplified)';

  @override
  String get languageEnglish => 'English';

  @override
  String get navAccountSync => 'Account & Sync';

  @override
  String get navAnonymousAccount => 'Signed out';

  @override
  String ideaCreatedAt(String date) {
    return 'Created $date';
  }

  @override
  String ideaCreator(String name) {
    return 'Proposed by $name';
  }

  @override
  String get ideaDetailTitle => 'Project details';

  @override
  String get ideaEmptyHint => 'Pull to refresh or try again later';

  @override
  String get ideaEmptyTitle => 'No new projects yet';

  @override
  String get ideaGallery => 'Project images';

  @override
  String get ideaLoadMore => 'Load more';

  @override
  String get ideaNav => 'Projects';

  @override
  String get ideaNoDescription => 'The proposer has not added a detailed description yet';

  @override
  String get ideaNoReasonStats => 'No opposition reasons yet';

  @override
  String ideaOpposeCount(int count) {
    return 'Oppose $count';
  }

  @override
  String get ideaOpposeReasonHint => 'Additional details (optional, up to 100 characters)';

  @override
  String get ideaOpposeReasonNotEnoughInfo => 'Not enough information';

  @override
  String get ideaOpposeReasonNotExecutable => 'Difficult to execute';

  @override
  String get ideaOpposeReasonNotInterested => 'Not interested';

  @override
  String get ideaOpposeReasonOther => 'Other';

  @override
  String get ideaOpposeReasonTooManySimilar => 'Too many similar projects';

  @override
  String get ideaOpposeReasonUnreasonablePricing => 'Expected pricing is unreasonable';

  @override
  String get ideaOpposeSubmit => 'Submit opposition';

  @override
  String get ideaOpposeSubtitle => 'Choose the main reason to help the proposer understand your concerns';

  @override
  String get ideaOpposeSuccess => 'Your opposition has been submitted';

  @override
  String get ideaOtherReasonRequired => 'Add a reason when selecting Other';

  @override
  String get ideaReasonCountsTitle => 'Reasons for opposition';

  @override
  String get ideaRefresh => 'Refresh';

  @override
  String get ideaSubtitle => 'Discover ideas and share support or concerns; voting never charges you';

  @override
  String get ideaSupport => 'Support';

  @override
  String ideaSupportCount(int count) {
    return 'Support $count';
  }

  @override
  String get ideaSupportDisclaimer => 'Tiers only record future willingness to support. No coins are charged and no order is created.';

  @override
  String ideaSupportRate(int percent) {
    return 'Support rate $percent%';
  }

  @override
  String get ideaSupportReasonHint => 'Share your expectations (optional, up to 60 characters)';

  @override
  String get ideaSupportReasonCreative => 'Great idea';

  @override
  String get ideaSupportReasonJoin => 'I would join';

  @override
  String get ideaSupportReasonLaunch => 'Looking forward to launch';

  @override
  String get ideaSupportSubmit => 'Submit support';

  @override
  String get ideaSupportSubtitle => 'Choose a future support tier to express willingness only';

  @override
  String get ideaSupportSuccess => 'Your support has been recorded';

  @override
  String ideaTierCount(int tier, int count) {
    return '$tier-coin tier: $count people';
  }

  @override
  String get ideaTierDistributionTitle => 'Support willingness';

  @override
  String get ideaTitle => 'Project ideas';

  @override
  String get ideaUntitled => 'Untitled project';

  @override
  String get ideaUnknownCreator => 'Anonymous proposer';

  @override
  String get ideaVoteAlready => 'Your vote is already recorded';

  @override
  String get ideaVoteLoginRequired => 'Sign in before voting';

  @override
  String get ideaVoteMyOppose => 'You submitted an opposition';

  @override
  String ideaVoteMySupport(int tier) {
    return 'You supported the $tier-coin tier';
  }

  @override
  String get ideaVoting => 'Submitting…';

  @override
  String get navCalendar => 'Calendar';

  @override
  String get navGoToToday => 'Go to today';

  @override
  String get navHideToTray => 'Hide to tray (right-click the tray icon to quit)';

  @override
  String get navHistory => 'History';

  @override
  String get navNextMonth => 'Next month';

  @override
  String get navPreviousMonth => 'Previous month';

  @override
  String navReminderStatus(int count) {
    return 'Reminders ($count scheduled)';
  }

  @override
  String get navSearch => 'Search';

  @override
  String get navSearchAction => 'Search calendar and checklists';

  @override
  String get navToggleTheme => 'Toggle theme';

  @override
  String get navTransfer => 'Import / Export';

  @override
  String get noteTitle => 'Note';

  @override
  String get notesAddLine => 'Add line';

  @override
  String get notesBackgroundColor => 'Background color';

  @override
  String get notesDeleteLine => 'Delete line';

  @override
  String get notesEditNote => 'Edit note';

  @override
  String get notesEditorMissing => 'This note no longer exists or has been deleted';

  @override
  String get notesEditorTitle => 'Note';

  @override
  String get notesEmpty => '(Empty note)';

  @override
  String get notesEmptyHint => 'Select New note above. Notes can stay on top in their own windows.';

  @override
  String get notesEmptyTitle => 'No notes yet';

  @override
  String notesHeading(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Notes ($count)',
      one: 'Note ($count)',
    );
    return '$_temp0';
  }

  @override
  String get notesHide => 'Hide';

  @override
  String get notesLineColor => 'Line text color';

  @override
  String get notesMarkLineComplete => 'Mark line complete';

  @override
  String get notesNewNote => 'New note';

  @override
  String get notesOpenWindow => 'Open in separate window';

  @override
  String get notesPinWindow => 'Keep window on top';

  @override
  String get notesPinned => 'Pinned';

  @override
  String get notesShow => 'Show';

  @override
  String get notesStandaloneWindow => 'Separate window';

  @override
  String get notesTitleField => 'Title';

  @override
  String get notesUnavailable => 'No notes yet';

  @override
  String get notificationChannel => 'Task reminders';

  @override
  String get notificationChannelDescription => 'Calendar task and anniversary reminders';

  @override
  String get notificationOpenCalendar => 'Open calendar';

  @override
  String get reminderAcknowledge => 'Got it';

  @override
  String get reminderDismissTooltip => 'Dismiss reminder';

  @override
  String get reminderDontShowAgain => 'Don\'t show this window again';

  @override
  String reminderLogCancelFailed(String notificationId) {
    return 'Reminder cancellation failed: $notificationId';
  }

  @override
  String get reminderLogClearFailed => 'Failed to clear reminders';

  @override
  String get reminderLogInitializeFailed => 'Local notification initialization failed; using in-app reminders';

  @override
  String get reminderLogInitialized => 'Local notification plugin initialized';

  @override
  String reminderLogScheduleFailed(String eventId) {
    return 'Reminder scheduling failed: $eventId';
  }

  @override
  String reminderNotificationBody(String date, String time) {
    return '$date $time';
  }

  @override
  String reminderRescheduleFailed(String message) {
    return 'Couldn\'t reschedule reminders: $message';
  }

  @override
  String get reminderTaskTitle => 'Task reminder';

  @override
  String get searchChooseCustomRange => 'Choose custom range';

  @override
  String get searchClearQueryTooltip => 'Clear search';

  @override
  String searchCourseSubtitle(String course, String weekday, int period) {
    return '$course · $weekday, period $period';
  }

  @override
  String searchCustomRangeLabel(String start, String end) {
    return '$start – $end';
  }

  @override
  String get searchEmptyHint => 'Enter a keyword to search all modules instantly';

  @override
  String get searchEmptyTitle => 'No matching content';

  @override
  String searchEventSubtitle(String date, String recurrence) {
    return '$date · $recurrence';
  }

  @override
  String get searchFieldHint => 'Content, tasks, notes, countdowns, subscriptions, courses';

  @override
  String get searchFieldLabel => 'Search calendar and lists';

  @override
  String get searchKindCell => 'Calendar cell';

  @override
  String get searchKindCountdown => 'Countdown';

  @override
  String get searchKindCourse => 'Course';

  @override
  String get searchKindNote => 'Note';

  @override
  String get searchKindSubscription => 'Subscription';

  @override
  String get searchRangeAll => 'All';

  @override
  String get searchRangeCustom => 'Custom';

  @override
  String get searchRangeOneMonth => 'Past month';

  @override
  String get searchRangeOneYear => 'Past year';

  @override
  String get searchRangeThreeMonths => 'Past 3 months';

  @override
  String searchResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count results found',
      one: '$count result found',
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
  String get settingsAboutData => 'About / data';

  @override
  String get settingsAdvanced => 'Advanced settings';

  @override
  String get settingsApplyToDesktop => 'Apply to desktop now';

  @override
  String get settingsAutoCheckUpdates => 'Check for updates automatically';

  @override
  String get settingsBulletStyle => 'Bullet style';

  @override
  String get settingsCalendarColors => 'Calendar colors';

  @override
  String get settingsCalendarDisplay => 'Calendar display';

  @override
  String get settingsCalendarFontSize => 'Calendar font size';

  @override
  String get settingsCalendarOpacity => 'Calendar opacity';

  @override
  String get settingsCellGap => 'Cell spacing';

  @override
  String get settingsCellSection => 'Cells';

  @override
  String get settingsCheckNow => 'Check now';

  @override
  String get settingsCheckUpdates => 'Check for updates';

  @override
  String get settingsChooseImageDirectory => 'Choose image folder';

  @override
  String get settingsClearImageDirectory => 'Clear image folder';

  @override
  String get settingsCloudSync => 'Cloud sync';

  @override
  String get settingsCompletedLast => 'Move completed items to the end';

  @override
  String get settingsContentFontSize => 'Content font size';

  @override
  String get settingsCountdownOpacity => 'Countdown opacity';

  @override
  String get settingsDesktop => 'Desktop';

  @override
  String get settingsDesktopBehavior => 'The widget stays below all windows. Type, check, or drag inside the card; clicks outside it pass through to desktop icons.';

  @override
  String get settingsDesktopDescription => 'Keep the editable calendar widget on the desktop layer; static wallpaper snapshots are optional backups only';

  @override
  String get settingsDesktopWidgetHidden => 'Desktop widget: hidden';

  @override
  String get settingsDesktopWidgetVisible => 'Desktop widget: visible (editable)';

  @override
  String get settingsDisplayMode => 'Display mode';

  @override
  String get settingsEditableDesktopCalendar => 'Show editable calendar on the desktop (true desktop layer)';

  @override
  String get settingsFestivalInfo => 'Show festivals / lunar dates / solar terms';

  @override
  String get settingsFontColors => 'Fonts & colors';

  @override
  String get settingsGlassEffect => 'Show transparent glass effect';

  @override
  String get settingsHideHotkey => 'Crtl+H show or hide / hotkey toggle';

  @override
  String get settingsHolidays => 'Show public holidays';

  @override
  String get settingsHotSearchFloating => 'Show trending searches / floating button';

  @override
  String get settingsIeProxy => 'Use IE proxy settings';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLegacyCalendarHint => 'Matches the legacy Calendar settings page';

  @override
  String get settingsLineSpacing => 'Line spacing';

  @override
  String get settingsLunar => 'Show lunar calendar';

  @override
  String get settingsMonthDetails => 'Show month separators / week numbers / shadows / title bar';

  @override
  String get settingsNoImageDirectory => 'No image folder selected';

  @override
  String get settingsNotesLineSpacing => 'Line spacing';

  @override
  String get settingsNotesOpacity => 'Note opacity';

  @override
  String get settingsNotesSection => 'Notes';

  @override
  String get settingsReminderTone => 'Reminder sound';

  @override
  String get settingsRescheduleReminders => 'Reschedule reminders';

  @override
  String get settingsRestoreDefaults => 'Restore default settings';

  @override
  String get settingsSaveFailed => 'Could not save settings. Check local storage and try again.';

  @override
  String get settingsRestoreSystemWallpaper => 'Restore original system wallpaper';

  @override
  String settingsScheduledReminders(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count scheduled reminders',
      one: '$count scheduled reminder',
    );
    return '$_temp0';
  }

  @override
  String get settingsSearchEngine => 'Search engine';

  @override
  String get settingsSearchEngineBaidu => 'Baidu';

  @override
  String get settingsSearchEngineBing => 'Bing';

  @override
  String get settingsShowAllNotes => 'Show all notes';

  @override
  String get settingsShowCompleted => 'Show completed items';

  @override
  String get settingsShowReminderTime => 'Show reminder time';

  @override
  String get settingsSolarTerms => 'Show solar terms';

  @override
  String get settingsStartOfWeek => 'First day of week';

  @override
  String get settingsStartWithWindows => 'Start with Windows';

  @override
  String get settingsStaticWallpaperGenerated => 'Static wallpaper: generated';

  @override
  String get settingsStaticWallpaperNotEnabled => 'Static wallpaper: not enabled';

  @override
  String get settingsStaticWallpaperSnapshot => '(Optional) Generate a static wallpaper snapshot';

  @override
  String settingsStorageName(String storageName) {
    return 'Clean DDD + Riverpod · Local storage: $storageName';
  }

  @override
  String get settingsSyncNow => 'Sync now';

  @override
  String get settingsTabAbout => 'About';

  @override
  String get settingsTabAdvanced => 'Advanced';

  @override
  String get settingsTabCalendar => 'Calendar';

  @override
  String get settingsTabCell => 'Cells';

  @override
  String get settingsTabFontColors => 'Fonts & colors';

  @override
  String get settingsTabNotes => 'Notes';

  @override
  String get settingsTabWallpaper => 'Wallpaper';

  @override
  String get settingsTaskCompleteTone => 'Task completion sound';

  @override
  String get settingsTheme => 'Theme';

  @override
  String settingsVisibleColumns(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count columns',
      one: '$count column',
    );
    return '$_temp0';
  }

  @override
  String get settingsVisibleColumnsLabel => 'Visible month columns';

  @override
  String settingsVisibleRows(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rows',
      one: '$count row',
    );
    return '$_temp0';
  }

  @override
  String get settingsVisibleRowsLabel => 'Visible rows';

  @override
  String get settingsWallpaperFit => 'Image fitting';

  @override
  String get settingsWallpaperFitFill => 'Fill (crop to cover)';

  @override
  String get settingsWallpaperFitFit => 'Fit (show entire image)';

  @override
  String get settingsWallpaperFitStretch => 'Stretch';

  @override
  String get settingsWallpaperImage => 'Wallpaper source';

  @override
  String get settingsWallpaperIntervalLabel => 'Interval (minutes)';

  @override
  String settingsWallpaperIntervalMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes',
      one: '$count minute',
    );
    return '$_temp0';
  }

  @override
  String get settingsWallpaperShowAll => 'Cycle through all images in the folder';

  @override
  String get settingsWeekNumbers => 'Show week numbers';

  @override
  String settingsWeekday(String weekday) {
    return '$weekday';
  }

  @override
  String get soundToneDing => 'Ding';

  @override
  String get soundToneDing2 => 'Ding-dang';

  @override
  String get soundToneDing3 => 'Ding-dong';

  @override
  String get soundToneDong => 'Dong';

  @override
  String get soundToneLittleStar => 'Twinkle, Twinkle, Little Star';

  @override
  String get soundToneNone => 'None';

  @override
  String subWindowCommand(String command) {
    return 'Subwindow command: $command';
  }

  @override
  String get subscriptionAdd => 'Add subscription';

  @override
  String get subscriptionCopyLink => 'Copy share link';

  @override
  String get subscriptionCreateTitle => 'Add subscription calendar';

  @override
  String get subscriptionDelete => 'Delete subscription';

  @override
  String get subscriptionEmptyHint => 'Supports local subscriptions and Google / Outlook / iCloud / CalDAV';

  @override
  String get subscriptionEmptyTitle => 'No subscription calendars yet';

  @override
  String get subscriptionEnabled => 'Enable this subscription';

  @override
  String subscriptionFetchFailed(String name) {
    return 'Failed to fetch subscription; keeping local cache: $name';
  }

  @override
  String subscriptionHeading(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Subscription calendars ($count)',
      one: 'Subscription calendar ($count)',
    );
    return '$_temp0';
  }

  @override
  String subscriptionLastSyncedAt(String date, String time) {
    return 'Last synced: $date at $time';
  }

  @override
  String get subscriptionName => 'Subscription name';

  @override
  String get subscriptionNeverSynced => 'Not synced yet';

  @override
  String get subscriptionShareLinkHint => 'Share link (leave blank to create a local subscription)';

  @override
  String get subscriptionSource => 'Subscription source';

  @override
  String get subscriptionSourceCaldav => 'CalDAV';

  @override
  String get subscriptionSourceGoogle => 'Google Calendar';

  @override
  String get subscriptionSourceIcloud => 'iCloud Calendar';

  @override
  String get subscriptionSourceLocal => 'Local subscription';

  @override
  String get subscriptionSourceOutlook => 'Outlook Calendar';

  @override
  String subscriptionSummary(String source, int count, String lastSync) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count events',
      one: '$count event',
    );
    return '$source · $_temp0 · $lastSync';
  }

  @override
  String get subscriptionSync => 'Sync';

  @override
  String get subscriptionSyncAll => 'Sync all';

  @override
  String syncFailed(String message) {
    return 'Sync failed: $message';
  }

  @override
  String get syncLoginRequired => 'Sign in before syncing';

  @override
  String syncSummary(int uploaded, int downloaded) {
    return 'Uploaded $uploaded records and downloaded $downloaded records.';
  }

  @override
  String get themeModeDark => 'Dark';

  @override
  String get themeModeLight => 'Light';

  @override
  String get themeModeSystem => 'Follow system';

  @override
  String get timetableAdd => 'Add';

  @override
  String timetableAddLessonTitle(String weekday, int period) {
    return 'Add course ($weekday, period $period)';
  }

  @override
  String timetableAddLessonTooltip(String weekday, int period) {
    return 'Add course ($weekday, period $period)';
  }

  @override
  String get timetableCourseName => 'Course name';

  @override
  String get timetableEmptyHint => 'Supports odd/even weeks, period times, and course conflict detection';

  @override
  String get timetableEmptyTitle => 'No timetables yet';

  @override
  String get timetableHideWeekend => 'Hide weekends';

  @override
  String get timetableLessonConflict => 'The new course conflicts with another course at the same time';

  @override
  String get timetableNewName => 'New timetable';

  @override
  String get timetableParityAll => 'All weeks';

  @override
  String get timetableParityEven => 'Even weeks';

  @override
  String get timetableParityOdd => 'Odd weeks';

  @override
  String get timetablePeriod => 'Period';

  @override
  String get timetablePeriodsPerDay => 'Periods per day';

  @override
  String timetablePeriodsPerDayCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count periods',
      one: '1 period',
    );
    return '$_temp0';
  }

  @override
  String timetableRemoveLessonTooltip(String name) {
    return 'Delete course $name';
  }

  @override
  String timetableRemoveTooltip(String name) {
    return 'Delete $name';
  }

  @override
  String get timetableSemesterWeeks => 'Term length';

  @override
  String get timetableSettings => 'Timetable settings';

  @override
  String timetableSettingsTitle(String name) {
    return 'Timetable settings: $name';
  }

  @override
  String get timetableStartDate => 'Start date';

  @override
  String timetableSummary(String startDate, int weeks) {
    String _temp0 = intl.Intl.pluralLogic(
      weeks,
      locale: localeName,
      other: '$weeks weeks',
      one: '1 week',
    );
    return 'Starts $startDate · $_temp0';
  }

  @override
  String get timetableTitle => 'Timetable';

  @override
  String timetableWeeksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count weeks',
      one: '1 week',
    );
    return '$_temp0';
  }

  @override
  String get transferChooseAndImport => 'Choose file and import';

  @override
  String get transferExportSubtitle => 'Re-importable database files, printable text, and Excel-compatible CSV';

  @override
  String get transferExportTitle => 'Export calendar list';

  @override
  String get transferExportToFile => 'Export to file';

  @override
  String get transferFormatCsv => 'Excel (CSV)';

  @override
  String get transferFormatDatabase => 'Database (re-importable)';

  @override
  String get transferFormatText => 'Text file';

  @override
  String get transferImportSubtitle => 'Restore cells and tasks from a `*.json` database file';

  @override
  String get transferImportTitle => 'Import calendar list';

  @override
  String get transferRangeAllTime => 'All time';

  @override
  String get transferRangeCustom => 'Custom';

  @override
  String get transferRangeSixMonths => 'Last 6 months';

  @override
  String get transferReplaceConflicts => 'Replace all conflicts with imported content';

  @override
  String get trayAbout => 'About';

  @override
  String get trayExit => 'Exit';

  @override
  String get trayHide => 'Hide main window';

  @override
  String get trayHideWidget => 'Hide desktop calendar widget';

  @override
  String get trayNotes => 'Notes';

  @override
  String get trayRefreshWallpaper => 'Refresh wallpaper';

  @override
  String get traySettings => 'Settings';

  @override
  String get trayShow => 'Show main window';

  @override
  String get trayShowWidget => 'Show desktop calendar widget';

  @override
  String get traySync => 'Sync now';

  @override
  String get wallpaperFailed => 'Failed to generate wallpaper';

  @override
  String wallpaperFooter(String date, String weekday) {
    return 'Today: $date, $weekday    Data from your local calendar and checklists';
  }

  @override
  String get wallpaperModeDesktopCapture => 'Capture an image from the desktop';

  @override
  String get wallpaperModeRotation => 'Cycle through selected images';

  @override
  String get wallpaperModeSolidColor => 'Set a solid desktop background color';

  @override
  String get wallpaperRejected => 'The system rejected the wallpaper change';

  @override
  String get wallpaperRestored => 'Original system wallpaper restored';

  @override
  String get wallpaperSelectDirectory => 'Select wallpaper image folder';

  @override
  String get wallpaperUpdated => 'Wallpaper updated';

  @override
  String get widgetAddLine => 'Add a line';

  @override
  String get widgetAddLineTooltip => 'Add a line';

  @override
  String widgetAddToDate(String date) {
    return 'Add to $date';
  }

  @override
  String get widgetCellColor => 'Cell color';

  @override
  String get widgetCellColorTooltip => 'Choose cell color';

  @override
  String get widgetClearDay => 'Clear this day';

  @override
  String get widgetClearTooltip => 'Clear this day';

  @override
  String get widgetClosePalette => 'Close color palette';

  @override
  String get widgetMoveHint => 'Drag to move the desktop calendar';

  @override
  String get widgetResizeLeft => 'Resize from the left edge';

  @override
  String get widgetResizeRight => 'Resize from the right edge';

  @override
  String get widgetResizeTop => 'Resize from the top edge';

  @override
  String get widgetResizeBottom => 'Resize from the bottom edge';

  @override
  String get widgetResizeTopLeft => 'Resize from the top-left corner';

  @override
  String get widgetResizeTopRight => 'Resize from the top-right corner';

  @override
  String get widgetResizeBottomLeft => 'Resize from the bottom-left corner';

  @override
  String get widgetResizeBottomRight => 'Resize from the bottom-right corner';

  @override
  String get widgetCollapse => 'Collapse desktop widget';

  @override
  String get widgetCompleteTooltip => 'Mark complete';

  @override
  String get widgetConfirmClear => 'Confirm clear';

  @override
  String widgetEditingDate(String date) {
    return 'Editing $date';
  }

  @override
  String get widgetFinishEditing => 'Finish editing';

  @override
  String get widgetFinishEditingTooltip => 'Save and finish editing';

  @override
  String get widgetMarkComplete => 'Mark complete';

  @override
  String get widgetNewLineHint => 'Press Enter to add a line…';

  @override
  String get widgetPopupEditor => 'Popup editor';

  @override
  String get widgetPopupEditorTooltip => 'Open the full editor';

  @override
  String get widgetPromote => 'Make task';

  @override
  String get widgetPromoteTooltip => 'Turn this line into a recurring task';

  @override
  String get widgetQuickInputHint => 'Type something and press Enter';

  @override
  String get widgetTextColor => 'Text color';

  @override
  String get widgetTextColorTooltip => 'Choose text color';

  @override
  String get authLoginTitle => 'Sign in / Sign up';

  @override
  String get authLoginSubtitle => 'Sign in with your phone number. Your account is created automatically on first sign-in.';

  @override
  String get authPhoneHint => 'Phone number';

  @override
  String get authCodeHint => '6-digit code';

  @override
  String get authPasswordHint => 'Password (6–20 characters)';

  @override
  String get authSendCode => 'Send code';

  @override
  String get authSendingCode => 'Sending';

  @override
  String authResendCode(int seconds) {
    return 'Resend in ${seconds}s';
  }

  @override
  String get authLoggingIn => 'Signing in';

  @override
  String get authLoginAction => 'Sign in / Sign up';

  @override
  String get authSwitchToPassword => 'Use password';

  @override
  String get authSwitchToCode => 'Use SMS code';

  @override
  String get authAgreementText => 'I have read and agree to the registration agreement and privacy policy';

  @override
  String get authAgreementRequired => 'Accept the registration agreement and privacy policy to continue';

  @override
  String get authPhoneInvalid => 'Enter a valid 11-digit phone number';

  @override
  String get authCodeInvalid => 'Enter the 6-digit SMS code';

  @override
  String get authPasswordInvalid => 'Password must contain 6–20 characters';

  @override
  String get authCodeSent => 'Verification code sent';

  @override
  String get authNetworkError => 'Network connection failed. Check your connection and try again.';

  @override
  String get authTimeoutError => 'The request timed out. Please try again.';

  @override
  String get authStorageError => 'The sign-in state could not be saved securely. Check your system keychain.';

  @override
  String get authSessionExpired => 'Your session has expired. Please sign in again.';

  @override
  String get authUnknownError => 'Something went wrong. Please try again.';

  @override
  String get authAccountLockedTitle => 'Account locked';

  @override
  String get authAccountLockedConfirm => 'Got it';

  @override
  String get authCaptchaTitle => 'Image verification';

  @override
  String get authCaptchaHint => 'Enter the characters shown';

  @override
  String get authCaptchaRefresh => 'Refresh';

  @override
  String get authCaptchaCancel => 'Cancel';

  @override
  String get authCaptchaConfirm => 'Confirm';

  @override
  String get authCaptchaLoadFailed => 'Could not load the image. Tap to retry.';

  @override
  String get authNewUserWelcome => 'Your account has been created. Welcome to Planstar.';

  @override
  String get authBackToAccount => 'Back to account';

  @override
  String get authRefreshProfile => 'Refresh profile';

  @override
  String get authProfileRefreshing => 'Refreshing';

  @override
  String get authSignIn => 'Daily check-in';

  @override
  String get authSigningIn => 'Checking in';

  @override
  String authSignInReward(int reward) {
    return 'Today\'s reward: $reward stars';
  }

  @override
  String authWalletBalance(String balance) {
    return 'Star balance: $balance';
  }

  @override
  String authUserId(int id) {
    return 'User ID: $id';
  }

  @override
  String get authProfileEmpty => 'No bio yet';

  @override
  String get authSignedToday => 'Checked in today';

  @override
  String get authLoginPrompt => 'Sign in to sync your account profile and check in every day.';

  @override
  String get authGuestName => 'Not signed in';

  @override
  String get catalogTitle => 'Project catalog';

  @override
  String get catalogSubtitle => 'Browse funding progress, rewards and project updates';

  @override
  String get catalogAllCategories => 'All';

  @override
  String get catalogSortRecommended => 'Recommended';

  @override
  String get catalogSortNewest => 'Newest';

  @override
  String get catalogSortEnding => 'Ending soon';

  @override
  String get catalogSortAchievement => 'Most funded';

  @override
  String get catalogLoadMore => 'Load more';

  @override
  String get catalogEnd => 'No more projects';

  @override
  String get catalogEmptyTitle => 'No projects found';

  @override
  String get catalogEmptyHint => 'Try another category or refresh the catalog.';

  @override
  String get catalogCredits => 'Credits';

  @override
  String catalogSupporters(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count supporters',
      one: '$count supporter',
    );
    return '$_temp0';
  }

  @override
  String catalogAchievement(int percent) {
    return '$percent% funded';
  }

  @override
  String get catalogDetailTitle => 'Project details';

  @override
  String get catalogDetailEmpty => 'Project unavailable';

  @override
  String get catalogReadOnlyNotice => 'Read-only preview. Payment, seat selection and order creation are not available in this desktop version yet.';

  @override
  String get catalogStatusPreheating => 'Coming soon';

  @override
  String get catalogStatusAchieved => 'Goal reached';

  @override
  String get catalogStatusDelivered => 'Delivered';

  @override
  String get catalogStatusFailed => 'Funding closed';

  @override
  String get catalogStatusOngoing => 'Funding';

  @override
  String get catalogProgressTitle => 'Funding progress';

  @override
  String catalogDaysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days left',
      one: '$count day left',
    );
    return '$_temp0';
  }

  @override
  String get catalogEnded => 'Ended';

  @override
  String get catalogGoalAmount => 'Goal';

  @override
  String get catalogRaisedAmount => 'Raised';

  @override
  String get catalogDeadline => 'Deadline';

  @override
  String get catalogInfoTitle => 'Project information';

  @override
  String catalogDuration(String duration) {
    return 'Duration: $duration';
  }

  @override
  String get catalogSoldOut => 'Sold out';

  @override
  String get catalogRewardsTitle => 'Reward tiers';

  @override
  String catalogDelivery(String date) {
    return 'Estimated delivery: $date';
  }

  @override
  String get catalogUpdatesTitle => 'Project updates';

  @override
  String get catalogRiskTitle => 'Risk and fulfillment';

  @override
  String get catalogRiskNote => 'Risk note';

  @override
  String get catalogDeliveryPlan => 'Delivery plan';

  @override
  String get catalogFundUsage => 'Use of funds';

  @override
  String get catalogRefundRule => 'Refund policy';

  @override
  String catalogReviewsTitle(int count) {
    return 'Reviews ($count)';
  }

  @override
  String get catalogAnonymous => 'Anonymous supporter';

  @override
  String get catalogFaqTitle => 'Frequently asked questions';

  @override
  String get catalogCreatorTitle => 'About the creator';

  @override
  String catalogCreator(String name) {
    return 'Created by $name';
  }

  @override
  String get catalogCreatorVerified => 'Verified creator';

  @override
  String catalogCreatorStats(int projects, int successful, int rate) {
    return '$projects projects · $successful successful · $rate% fulfillment';
  }

  @override
  String get catalogStoryTitle => 'Project story';

  @override
  String get catalogGalleryTitle => 'Gallery';

  @override
  String get catalogNoticeTitle => 'Support notice';
}
