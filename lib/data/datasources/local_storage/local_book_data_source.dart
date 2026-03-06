import 'dart:io';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/hive_boxes.dart';
import '../../models/book.dart';
import '../../models/chapter.dart';
import '../../utils/chapter_parser.dart';

/// 本地导入书籍的数据源，基于 Hive 持久化 Book 元数据与文件路径。
class LocalBookDataSource {
  Box<Map>? _box;

  Future<Box<Map>> _ensureBox() async {
    final existing = _box;
    if (existing != null && existing.isOpen) {
      return existing;
    }
    final box = await Hive.openBox<Map>(HiveBoxes.localBooks);
    _box = box;
    return box;
  }

  /// 加载所有本地导入的书籍。
  Future<List<Book>> loadAll() async {
    final box = await _ensureBox();
    return box.values
        .map(
          (value) => Book.fromJson(
            Map<String, dynamic>.from(value),
          ),
        )
        .toList();
  }

  /// 从本地文件导入一本书。
  ///
  /// - 会将原始文件复制到应用文档目录的 `local_books/` 子目录下；
  /// - 生成一个 `local_xxx` 风格的内部 ID；
  /// - 默认使用文件名作为书名，用户稍后可在应用内自行重命名。
  Future<Book> addFromFile({
    required String path,
    String? title,
    String? author,
  }) async {
    final file = File(path);
    if (!await file.exists()) {
      throw Exception('文件不存在：$path');
    }

    // 复制到应用自己的目录，避免原始路径失效。
    final docsDir = await getApplicationDocumentsDirectory();
    final localDir = Directory('${docsDir.path}${Platform.pathSeparator}local_books');
    if (!await localDir.exists()) {
      await localDir.create(recursive: true);
    }

    final fileName = _extractFileName(path);
    final targetPath =
        '${localDir.path}${Platform.pathSeparator}${DateTime.now().millisecondsSinceEpoch}_$fileName';
    await file.copy(targetPath);

    final id = 'local_${DateTime.now().millisecondsSinceEpoch}';
    final book = Book(
      id: id,
      title: title ?? fileName,
      author: author ?? '',
      category: '本地导入',
      tags: const ['本地导入'],
      wordCount: 0,
      status: 'completed',
      intro: '',
      sourceType: BookSourceType.localFile,
      heatScore: 0,
      remoteApiId: null,
      externalUrl: null,
      detailAsset: null,
      localFilePath: targetPath,
    );

    final box = await _ensureBox();
    await box.put(id, book.toJson());
    return book;
  }

  /// 加载本地书籍的正文。会尝试根据常见章节标题自动分章节。
  Future<(Book, List<Chapter>)> loadBookDetail(Book book) async {
    final box = await _ensureBox();
    final raw = box.get(book.id);
    if (raw == null) {
      return (book, const <Chapter>[]);
    }
    final stored = Book.fromJson(Map<String, dynamic>.from(raw));
    final path = stored.localFilePath;
    if (path == null || path.isEmpty) {
      return (stored, const <Chapter>[]);
    }

    final file = File(path);
    if (!await file.exists()) {
      return (stored, const <Chapter>[]);
    }

    final text = await file.readAsString();
    final chapters = ChapterParser.parse(
      book: stored,
      fullText: text,
    );
    return (stored, chapters);
  }

  String _extractFileName(String path) {
    // 简单从路径中截取文件名，兼容常见的 / 与 \\。
    var name = path;
    final slash = name.lastIndexOf('/');
    final backslash = name.lastIndexOf('\\');
    final index = slash > backslash ? slash : backslash;
    if (index != -1 && index + 1 < name.length) {
      name = name.substring(index + 1);
    }
    return name;
  }
}

