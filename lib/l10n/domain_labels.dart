import 'package:intl/intl.dart';

import '../core/ports.dart';
import '../core/value_objects.dart';
import '../features/calendar/domain/calendar_event.dart';
import '../features/calendar/domain/recurrence.dart';
import '../features/countdown/domain/countdown.dart';
import '../features/notes/domain/note.dart';
import '../features/search/application/search_controller.dart';
import '../features/settings/domain/app_settings.dart';
import '../features/subscription/domain/subscription.dart';
import '../features/timetable/domain/timetable.dart';
import '../features/transfer/application/transfer_controller.dart';
import 'generated/app_localizations.dart';

extension DateKeyPresentation on DateKey {
  String fullDate(AppLocalizations l10n) =>
      DateFormat.yMMMMd(l10n.localeName).format(date);

  String shortDate(AppLocalizations l10n) =>
      DateFormat.MMMd(l10n.localeName).format(date);
}

String weekdayLong(int weekday, AppLocalizations l10n) => switch (weekday) {
  1 => l10n.calendarWeekdayLongMonday,
  2 => l10n.calendarWeekdayLongTuesday,
  3 => l10n.calendarWeekdayLongWednesday,
  4 => l10n.calendarWeekdayLongThursday,
  5 => l10n.calendarWeekdayLongFriday,
  6 => l10n.calendarWeekdayLongSaturday,
  _ => l10n.calendarWeekdayLongSunday,
};

String weekdayShort(int weekday, AppLocalizations l10n) => switch (weekday) {
  1 => l10n.calendarWeekdayMonday,
  2 => l10n.calendarWeekdayTuesday,
  3 => l10n.calendarWeekdayWednesday,
  4 => l10n.calendarWeekdayThursday,
  5 => l10n.calendarWeekdayFriday,
  6 => l10n.calendarWeekdaySaturday,
  _ => l10n.calendarWeekdaySunday,
};

extension CalendarEventTypePresentation on CalendarEventType {
  String localizedLabel(AppLocalizations l10n) => switch (this) {
    CalendarEventType.task => l10n.calendarEventTypeTask,
    CalendarEventType.reminder => l10n.calendarEventTypeReminder,
    CalendarEventType.countdown => l10n.calendarEventTypeCountdown,
    CalendarEventType.subscription => l10n.calendarEventTypeSubscription,
  };
}

extension DeleteScopePresentation on DeleteScope {
  String localizedLabel(AppLocalizations l10n) => switch (this) {
    DeleteScope.current => l10n.calendarDeleteScopeCurrent,
    DeleteScope.currentAndFuture => l10n.calendarDeleteScopeCurrentAndFuture,
    DeleteScope.all => l10n.calendarDeleteScopeAll,
  };
}

extension RecurrenceKindPresentation on RecurrenceKind {
  String localizedLabel(AppLocalizations l10n) => switch (this) {
    RecurrenceKind.none => l10n.calendarRecurrenceNone,
    RecurrenceKind.daily => l10n.calendarRecurrenceDaily,
    RecurrenceKind.workday => l10n.calendarRecurrenceWorkday,
    RecurrenceKind.weekly => l10n.calendarRecurrenceWeekly,
    RecurrenceKind.monthly => l10n.calendarRecurrenceMonthly,
    RecurrenceKind.monthLastDay => l10n.calendarRecurrenceMonthLastDay,
    RecurrenceKind.quarterly => l10n.calendarRecurrenceQuarterly,
    RecurrenceKind.yearly => l10n.calendarRecurrenceYearly,
    RecurrenceKind.lunarYearly => l10n.calendarRecurrenceLunarYearly,
    RecurrenceKind.legalWorkday => l10n.calendarRecurrenceLegalWorkday,
    RecurrenceKind.ebbinghaus => l10n.calendarRecurrenceEbbinghaus,
    RecurrenceKind.customDay => l10n.calendarRecurrenceCustomDay,
    RecurrenceKind.customWeek => l10n.calendarRecurrenceCustomWeek,
    RecurrenceKind.customMonthDay => l10n.calendarRecurrenceCustomMonthDay,
    RecurrenceKind.customMonthWeek => l10n.calendarRecurrenceCustomMonthWeek,
    RecurrenceKind.customYear => l10n.calendarRecurrenceCustomYear,
  };
}

extension CalendarDisplayModePresentation on CalendarDisplayMode {
  String localizedLabel(AppLocalizations l10n) => switch (this) {
    CalendarDisplayMode.floatingMonth => l10n.calendarDisplayModeFloatingMonth,
    CalendarDisplayMode.fullMonth => l10n.calendarDisplayModeFullMonth,
    CalendarDisplayMode.fixedSingleLine =>
      l10n.calendarDisplayModeFixedSingleLine,
    CalendarDisplayMode.floatingSingleLine =>
      l10n.calendarDisplayModeFloatingSingleLine,
  };
}

extension BulletStylePresentation on BulletStyle {
  String localizedLabel(AppLocalizations l10n) => switch (this) {
    BulletStyle.none => l10n.bulletStyleNone,
    BulletStyle.number => l10n.bulletStyleNumber,
    BulletStyle.dot => l10n.bulletStyleDot,
  };
}

extension AppThemeModePresentation on AppThemeMode {
  String localizedLabel(AppLocalizations l10n) => switch (this) {
    AppThemeMode.system => l10n.themeModeSystem,
    AppThemeMode.light => l10n.themeModeLight,
    AppThemeMode.dark => l10n.themeModeDark,
  };
}

extension WallpaperModePresentation on WallpaperMode {
  String localizedLabel(AppLocalizations l10n) => switch (this) {
    WallpaperMode.rotation => l10n.wallpaperModeRotation,
    WallpaperMode.desktopCapture => l10n.wallpaperModeDesktopCapture,
    WallpaperMode.solidColor => l10n.wallpaperModeSolidColor,
  };
}

extension SoundTonePresentation on SoundTone {
  String localizedLabel(AppLocalizations l10n) => switch (this) {
    SoundTone.none => l10n.soundToneNone,
    SoundTone.ding => l10n.soundToneDing,
    SoundTone.ding2 => l10n.soundToneDing2,
    SoundTone.ding3 => l10n.soundToneDing3,
    SoundTone.dong => l10n.soundToneDong,
    SoundTone.littleStar => l10n.soundToneLittleStar,
  };
}

extension CountdownTypePresentation on CountdownType {
  String localizedLabel(AppLocalizations l10n) => switch (this) {
    CountdownType.custom => l10n.countdownTypeCustom,
    CountdownType.birthday => l10n.countdownTypeBirthday,
    CountdownType.memorial => l10n.countdownTypeMemorial,
    CountdownType.festival => l10n.countdownTypeFestival,
    CountdownType.exam => l10n.countdownTypeExam,
  };
}

extension CountdownShowTypePresentation on CountdownShowType {
  String localizedLabel(AppLocalizations l10n) => switch (this) {
    CountdownShowType.desktopCard => l10n.countdownShowTypeDesktopCard,
    CountdownShowType.calendarBottom => l10n.countdownShowTypeCalendarBottom,
    CountdownShowType.both => l10n.countdownShowTypeBoth,
  };
}

extension CountdownItemPresentation on CountdownItem {
  String localizedDisplayText(AppLocalizations l10n, DateKey today) {
    final days = daysLeft(today);
    if (days == 0) return l10n.commonToday;
    if (days > 0) return l10n.countdownDaysRemaining(days);
    if (type == CountdownType.birthday || type == CountdownType.memorial) {
      return l10n.countdownDaysSince(-days);
    }
    return l10n.countdownExpiredDays(-days);
  }

  String localizedAgeText(AppLocalizations l10n, DateKey today) {
    if (type != CountdownType.birthday || birthYear == null) return '';
    return l10n.countdownBirthdayAge(nextOccurrence(today).year - birthYear!);
  }
}

extension SubscriptionSourcePresentation on SubscriptionSource {
  String localizedLabel(AppLocalizations l10n) => switch (this) {
    SubscriptionSource.local => l10n.subscriptionSourceLocal,
    SubscriptionSource.google => l10n.subscriptionSourceGoogle,
    SubscriptionSource.outlook => l10n.subscriptionSourceOutlook,
    SubscriptionSource.icloud => l10n.subscriptionSourceIcloud,
    SubscriptionSource.caldav => l10n.subscriptionSourceCaldav,
  };
}

extension WeekParityPresentation on WeekParity {
  String localizedLabel(AppLocalizations l10n) => switch (this) {
    WeekParity.all => l10n.timetableParityAll,
    WeekParity.odd => l10n.timetableParityOdd,
    WeekParity.even => l10n.timetableParityEven,
  };
}

extension SearchRangePresentation on SearchRange {
  String localizedLabel(AppLocalizations l10n) => switch (this) {
    SearchRange.all => l10n.searchRangeAll,
    SearchRange.oneMonth => l10n.searchRangeOneMonth,
    SearchRange.threeMonths => l10n.searchRangeThreeMonths,
    SearchRange.oneYear => l10n.searchRangeOneYear,
    SearchRange.custom => l10n.searchRangeCustom,
  };
}

extension EventColorPresentation on EventColor {
  String localizedLabel(AppLocalizations l10n, {String? purpose}) {
    if (isTransparent) return l10n.calendarTransparentColor;
    final rgb = hex.substring(3);
    final context = purpose ?? l10n.commonColorPickerHint;
    return '$context #$rgb';
  }
}

extension NotePresentation on Note {
  String localizedTitle(AppLocalizations l10n) =>
      title.isEmpty || title == '新建便签' || title == 'New note'
      ? l10n.notesNewNote
      : title;
}

extension TimetablePresentation on Timetable {
  String localizedName(AppLocalizations l10n) =>
      name == '新建课程表' || name == 'New timetable' ? l10n.timetableNewName : name;
}

extension ExportFormatPresentation on ExportFormat {
  String localizedLabel(AppLocalizations l10n) => switch (this) {
    ExportFormat.database => l10n.transferFormatDatabase,
    ExportFormat.text => l10n.transferFormatText,
    ExportFormat.csv => l10n.transferFormatCsv,
  };
}
