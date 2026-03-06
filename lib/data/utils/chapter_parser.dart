import '../models/book.dart';
import '../models/chapter.dart';

/// 简单的章节解析工具，用于从整本 TXT 文本中按常见章节标题规则切分为多章。
///
/// 解析策略偏保守：如果未能识别到任何章节标题，则整体作为一章返回，
/// 避免错误拆分带来更差的阅读体验。
class ChapterParser {
  const ChapterParser._();

  /// 根据全书纯文本内容粗略拆分章节。
  ///
  /// - [book]：对应的图书元数据，用于生成章节 ID 和兜底标题。
  /// - [fullText]：整本书的纯文本内容。
  ///
  /// 返回的 [Chapter] 列表的 [index] 从 0 开始递增。
  static List<Chapter> parse({
    required Book book,
    required String fullText,
  }) {
    final trimmed = fullText.trim();
    if (trimmed.isEmpty) {
      return <Chapter>[
        Chapter(
          id: '${book.id}_ch0',
          bookId: book.id,
          index: 0,
          title: book.title.isNotEmpty ? book.title : '正文',
          content: '',
        ),
      ];
    }

    final lines = trimmed.split(RegExp(r'\r?\n'));

    // 常见中文、英文章节标题模式。
    final headerPatterns = <RegExp>[
      // 第X章 / 第X回 / 第X卷 / 第X节 等
      RegExp(r'^第[一二三四五六七八九十百千0-9]+[章节回卷部篇].*'),
      // CHAPTER I / Chapter 1 等
      RegExp(r'^(CHAPTER|Chapter|chapter)\s+[IVXLCDM0-9]+\b.*'),
    ];

    bool _isHeader(String line) {
      final value = line.trim();
      if (value.isEmpty) {
        return false;
      }
      for (final pattern in headerPatterns) {
        if (pattern.hasMatch(value)) {
          return true;
        }
      }
      return false;
    }

    final chapters = <Chapter>[];
    final buffer = StringBuffer();
    String? currentTitle;
    var chapterIndex = 0;
    var foundAnyHeader = false;

    void flushChapter() {
      if (currentTitle == null && buffer.isEmpty) {
        return;
      }

      final title =
          (currentTitle ?? '').trim().isNotEmpty ? currentTitle!.trim() : null;
      final resolvedTitle =
          title ?? (book.title.isNotEmpty ? book.title : '正文');

      chapters.add(
        Chapter(
          id: '${book.id}_ch$chapterIndex',
          bookId: book.id,
          index: chapterIndex,
          title: resolvedTitle,
          content: buffer.toString().trim(),
        ),
      );
      chapterIndex++;
      buffer.clear();
    }

    for (final rawLine in lines) {
      final line = rawLine.replaceAll('\ufeff', '').trimRight();

      if (_isHeader(line)) {
        foundAnyHeader = true;
        // 遇到新的章节标题，先把前一章收尾。
        flushChapter();
        currentTitle = line.trim();
        continue;
      }

      if (buffer.isNotEmpty) {
        buffer.writeln();
      }
      buffer.write(line);
    }

    // 收尾最后一章。
    flushChapter();

    if (!foundAnyHeader || chapters.isEmpty) {
      // 未识别到任何章节标题时，退化为整本一章。
      return <Chapter>[
        Chapter(
          id: '${book.id}_ch0',
          bookId: book.id,
          index: 0,
          title: book.title.isNotEmpty ? book.title : '正文',
          content: trimmed,
        ),
      ];
    }

    return chapters;
  }
}

