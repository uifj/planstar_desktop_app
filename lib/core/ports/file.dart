/// 文件选择与读写端口。
library;

abstract interface class FileGateway {
  Future<String?> pickOpenPath();

  Future<String?> pickDirectory();

  Future<String?> pickSavePath(String suggestedName);

  Future<void> writeText(String path, String content);

  Future<String> readText(String path);

  Future<String> defaultExportDirectory();
}
