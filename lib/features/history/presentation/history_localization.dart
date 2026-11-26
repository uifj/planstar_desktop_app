import '../../../l10n/l10n.dart';
import '../domain/history_entry.dart';

final _templateSources = supportedLocales
    .map(lookupAppLocalizations)
    .toList(growable: false);

/// Localizes the known local-device author without mutating persisted entries.
///
/// Note content is an opaque user-content snapshot. The storage format does not
/// record template provenance, so re-rendering it could rewrite title punctuation.
({String author, String content}) localizeHistoryEntry(
  HistoryEntry entry,
  AppLocalizations l10n,
) {
  final isLocalAuthor =
      entry.author.isNotEmpty &&
      _templateSources.any(
        (AppLocalizations source) => source.historyAuthorLocal == entry.author,
      );
  return (
    author: isLocalAuthor ? l10n.historyAuthorLocal : entry.author,
    content: entry.content,
  );
}
