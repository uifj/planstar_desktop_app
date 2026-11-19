/// 内容搜索：对齐旧版「全部 / 近一月 / 近三月 / 近一年 / 自定义」范围与结果计数。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/core_providers.dart';
import '../../../core/value_objects.dart';
import '../../calendar/application/calendar_controller.dart';
import '../../calendar/domain/recurrence_policy.dart';
import '../../countdown/application/countdown_controller.dart';
import '../../notes/application/notes_controller.dart';
import '../../subscription/application/subscription_controller.dart';
import '../../timetable/application/timetable_controller.dart';

enum SearchRange {
  all('全部'),
  oneMonth('近一月'),
  threeMonths('近三月'),
  oneYear('近一年'),
  custom('自定义');

  const SearchRange(this.label);

  final String label;
}

final class SearchHit {
  const SearchHit({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.targetId,
    this.date,
  });

  final String kind;
  final String title;
  final String subtitle;
  final String targetId;
  final DateKey? date;
}

final class SearchState {
  const SearchState({
    this.keyword = '',
    this.range = SearchRange.all,
    this.customStart,
    this.customEnd,
    this.hits = const <SearchHit>[],
  });

  final String keyword;
  final SearchRange range;
  final DateKey? customStart;
  final DateKey? customEnd;
  final List<SearchHit> hits;

  SearchState copyWith({
    String? keyword,
    SearchRange? range,
    DateKey? customStart,
    DateKey? customEnd,
    List<SearchHit>? hits,
  }) => SearchState(
    keyword: keyword ?? this.keyword,
    range: range ?? this.range,
    customStart: customStart ?? this.customStart,
    customEnd: customEnd ?? this.customEnd,
    hits: hits ?? this.hits,
  );
}

final searchControllerProvider =
    NotifierProvider<SearchController, SearchState>(SearchController.new);

final class SearchController extends Notifier<SearchState> {
  @override
  SearchState build() => const SearchState();

  DateRange? _rangeOf(SearchState s) {
    final today = DateKey.today(ref.read(clockProvider).now());
    return switch (s.range) {
      SearchRange.all => null,
      SearchRange.oneMonth => DateRange(today.addDays(-30), today.addDays(365)),
      SearchRange.threeMonths => DateRange(
        today.addDays(-90),
        today.addDays(365),
      ),
      SearchRange.oneYear => DateRange(today.addDays(-365), today.addDays(365)),
      SearchRange.custom =>
        (s.customStart != null && s.customEnd != null)
            ? DateRange(s.customStart!, s.customEnd!)
            : null,
    };
  }

  void setRange(SearchRange range) {
    state = state.copyWith(range: range);
    run(state.keyword);
  }

  void setCustomRange(DateKey start, DateKey end) {
    state = state.copyWith(
      range: SearchRange.custom,
      customStart: start,
      customEnd: end,
    );
    run(state.keyword);
  }

  List<SearchHit> run(String keyword) {
    final query = keyword.trim().toLowerCase();
    final hits = <SearchHit>[];
    final range = _rangeOf(state);
    bool inRange(DateKey? date) =>
        date == null || range == null || range.contains(date);

    if (query.isNotEmpty) {
      final calendar = ref.read(calendarControllerProvider);
      for (final cell in calendar.cells.values) {
        for (final line in cell.lines) {
          if (!line.text.toLowerCase().contains(query)) continue;
          if (!inRange(cell.date)) continue;
          hits.add(
            SearchHit(
              kind: '单元格',
              title: line.text,
              subtitle: cell.date.cnFull,
              targetId: cell.date.key,
              date: cell.date,
            ),
          );
        }
      }
      for (final event in calendar.events) {
        if (!event.content.toLowerCase().contains(query)) continue;
        final dates = range == null
            ? <DateKey>[event.startDate]
            : RecurrencePolicy.occurrences(event, range);
        for (final date in dates) {
          hits.add(
            SearchHit(
              kind: event.type.label,
              title: event.content,
              subtitle: '${date.cnFull} · ${event.recurrence.kind.label}',
              targetId: event.id,
              date: date,
            ),
          );
        }
      }
      for (final note in ref.read(notesControllerProvider).items) {
        if (!note.plainText.toLowerCase().contains(query)) continue;
        hits.add(
          SearchHit(
            kind: '便签',
            title: note.title,
            subtitle: note.plainText.replaceAll('\n', ' '),
            targetId: note.id,
          ),
        );
      }
      for (final item in ref.read(countdownControllerProvider).items) {
        if (!item.title.toLowerCase().contains(query)) continue;
        if (!inRange(item.targetDate)) continue;
        hits.add(
          SearchHit(
            kind: '倒数日',
            title: item.title,
            subtitle: item.targetDate.cnFull,
            targetId: item.id,
            date: item.targetDate,
          ),
        );
      }
      for (final sub in ref.read(subscriptionControllerProvider).items) {
        for (final item in sub.events) {
          if (!item.title.toLowerCase().contains(query)) continue;
          if (!inRange(item.date)) continue;
          hits.add(
            SearchHit(
              kind: '订阅',
              title: item.title,
              subtitle: '${sub.name} · ${item.date.cnFull}',
              targetId: item.id,
              date: item.date,
            ),
          );
        }
      }
      for (final table in ref.read(timetableControllerProvider).items) {
        for (final lesson in table.lessons) {
          if (!lesson.name.toLowerCase().contains(query)) continue;
          hits.add(
            SearchHit(
              kind: '课程',
              title: lesson.name,
              subtitle: '${table.name} · 周${lesson.weekday} 第${lesson.period}节',
              targetId: lesson.id,
            ),
          );
        }
      }
    }
    state = state.copyWith(keyword: keyword, hits: hits);
    return hits;
  }
}
