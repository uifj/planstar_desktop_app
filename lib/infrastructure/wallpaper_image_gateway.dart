/// [WallpaperImageGateway] 的本地文件实现。
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../core/ports.dart';

final class LocalWallpaperImageGateway implements WallpaperImageGateway {
  @override
  Future<String> get outputDirectory async {
    final root = await getApplicationSupportDirectory();
    final folder = Directory('${root.path}/planstar_wallpaper');
    if (!await folder.exists()) await folder.create(recursive: true);
    return folder.path;
  }

  @override
  Future<String> get outputPath async {
    final folder = await outputDirectory;
    return '$folder/planstar_calendar_wallpaper.png';
  }

  @override
  Future<String> savePng(Uint8List bytes) async {
    final path = await outputPath;
    await File(path).writeAsBytes(bytes, flush: true);
    return path;
  }

  @override
  Future<String> readOriginalWallpaper() async {
    try {
      final path = await _originalPath;
      final file = File(path);
      if (!await file.exists()) return '';
      return (await file.readAsString()).trim();
    } on Object {
      return '';
    }
  }

  @override
  Future<void> writeOriginalWallpaper(String path) async {
    try {
      await File(await _originalPath).writeAsString(path, flush: true);
    } on Object {
      // 记住原始壁纸失败只影响 desktopCapture 底图，不阻断本次刷新。
    }
  }

  Future<String> get _originalPath async {
    final folder = await outputDirectory;
    return '$folder/original_wallpaper.txt';
  }

  @override
  Future<Uint8List?> readImage(String path) async {
    if (path.isEmpty) return null;
    try {
      final file = File(path);
      if (!await file.exists()) return null;
      return await file.readAsBytes();
    } on Object {
      return null;
    }
  }

  @override
  Future<List<String>> listImages(String directory) async {
    if (directory.isEmpty) return const <String>[];
    try {
      final folder = Directory(directory);
      if (!await folder.exists()) return const <String>[];
      const extensions = <String>{'.png', '.jpg', '.jpeg', '.bmp', '.webp'};
      final files = await folder
          .list()
          .where(
            (FileSystemEntity entity) =>
                entity is File &&
                extensions.contains(
                  _extensionOf(entity.path),
                ),
          )
          .cast<File>()
          .map((File file) => file.path)
          .toList();
      files.sort();
      return files;
    } on Object {
      return const <String>[];
    }
  }

  String _extensionOf(String path) {
    final dot = path.lastIndexOf('.');
    final slash = path.lastIndexOf(Platform.pathSeparator);
    if (dot < 0 || dot < slash) return '';
    return path.substring(dot).toLowerCase();
  }
}
