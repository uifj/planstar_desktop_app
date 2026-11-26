/// 文件端口实现：`file_picker` 选路径 + `dart:io` 读写 + `path_provider` 默认目录。
library;

import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../core/ports.dart';
import '../l10n/l10n.dart';

final class DesktopFileGateway implements FileGateway {
  DesktopFileGateway({required this.localizationScope});

  final AppLocalizationScope localizationScope;

  AppLocalizations get _l10n => localizationScope.localizations;
  @override
  Future<String?> pickOpenPath() async {
    final result = await FilePicker.pickFiles(
      dialogTitle: _l10n.transferImportTitle,
      type: FileType.custom,
      allowedExtensions: const <String>['json', 'txt', 'csv'],
    );
    return result?.files.single.path;
  }

  @override
  Future<String?> pickSavePath(String suggestedName) => FilePicker.saveFile(
    dialogTitle: _l10n.transferExportTitle,
    fileName: suggestedName,
  );

  @override
  Future<String?> pickDirectory() =>
      FilePicker.getDirectoryPath(dialogTitle: _l10n.wallpaperSelectDirectory);

  /// 读取时兼容 UTF-8 BOM，避免 Windows 记事本导出的文件多出 `\uFEFF`。
  @override
  Future<String> readText(String path) async {
    final bytes = await File(path).readAsBytes();
    final start =
        (bytes.length >= 3 &&
            bytes[0] == 0xEF &&
            bytes[1] == 0xBB &&
            bytes[2] == 0xBF)
        ? 3
        : 0;
    return utf8.decode(bytes.sublist(start));
  }

  @override
  Future<void> writeText(String path, String content) async {
    final file = File(path);
    if (!file.parent.existsSync()) {
      await file.parent.create(recursive: true);
    }
    await file.writeAsString(content, flush: true);
  }

  @override
  Future<String> defaultExportDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}${Platform.pathSeparator}PlanStar';
  }
}
