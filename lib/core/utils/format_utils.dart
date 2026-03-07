import 'dart:io';
import 'dart:convert';
import '../../data/models/book.dart';
import '../../data/models/chapter.dart';

/// 格式处理工具
class FormatUtils {
  /// 将书籍内容导出为TXT格式
  static Future<File> exportToTxt(Book book, List<Chapter> chapters, String outputPath) async {
    final file = File(outputPath);
    final content = StringBuffer();

    // 写入书籍信息
    content.writeln('${book.title}');
    content.writeln('作者: ${book.author}');
    content.writeln('分类: ${book.category}');
    content.writeln('');
    content.writeln('${book.intro}');
    content.writeln('');
    content.writeln('====================================');
    content.writeln('');

    // 写入章节内容
    for (final chapter in chapters) {
      content.writeln('${chapter.title}');
      content.writeln('');
      content.writeln('${chapter.content}');
      content.writeln('');
      content.writeln('====================================');
      content.writeln('');
    }

    await file.writeAsString(content.toString());
    return file;
  }

  /// 从TXT文件导入书籍
  static Future<(Book, List<Chapter>)> importFromTxt(File file, {
    String? title,
    String? author,
  }) async {
    final content = await file.readAsString();
    final lines = content.split('\n');
    
    // 提取书籍信息
    final bookTitle = title ?? '未知标题';
    final bookAuthor = author ?? '未知作者';

    // 解析章节
    final chapters = <Chapter>[];
    String currentChapterTitle = '第一章';
    StringBuffer currentChapterContent = StringBuffer();
    bool isFirstChapter = true;

    for (final line in lines) {
      final trimmedLine = line.trim();
      
      // 简单的章节识别逻辑
      if (trimmedLine.startsWith('第') && (trimmedLine.contains('章') || trimmedLine.contains('节'))) {
        if (!isFirstChapter) {
          // 保存当前章节
          chapters.add(Chapter(
            id: 'imported_chapter_${chapters.length}',
            bookId: 'imported_book',
            index: chapters.length,
            title: currentChapterTitle,
            content: currentChapterContent.toString().trim(),
          ));
        }
        
        // 开始新章节
        currentChapterTitle = trimmedLine;
        currentChapterContent = StringBuffer();
        isFirstChapter = false;
      } else {
        currentChapterContent.writeln(line);
      }
    }

    // 保存最后一章
    if (!isFirstChapter) {
      chapters.add(Chapter(
        id: 'imported_chapter_${chapters.length}',
        bookId: 'imported_book',
        index: chapters.length,
        title: currentChapterTitle,
        content: currentChapterContent.toString().trim(),
      ));
    }

    // 如果没有识别到章节，创建一个默认章节
    if (chapters.isEmpty) {
      chapters.add(Chapter(
        id: 'imported_chapter_0',
        bookId: 'imported_book',
        index: 0,
        title: '正文',
        content: content,
      ));
    }

    // 创建书籍对象
    final book = Book(
      id: 'imported_book_${DateTime.now().millisecondsSinceEpoch}',
      title: bookTitle,
      author: bookAuthor,
      category: '未知分类',
      intro: '从TXT文件导入',
      sourceType: BookSourceType.localFile,
      localFilePath: file.path,
    );

    return (book, chapters);
  }

  /// 将书籍内容导出为JSON格式
  static Future<File> exportToJson(Book book, List<Chapter> chapters, String outputPath) async {
    final file = File(outputPath);
    final data = {
      'book': book.toJson(),
      'chapters': chapters.map((chapter) => chapter.toJson()).toList(),
    };
    await file.writeAsString(json.encode(data)); // 移除indent参数，使用默认格式
    return file;
  }

  /// 从JSON文件导入书籍
  static Future<(Book, List<Chapter>)> importFromJson(File file) async {
    final content = await file.readAsString();
    final data = json.decode(content) as Map<String, dynamic>;
    
    final bookJson = data['book'] as Map<String, dynamic>;
    final book = Book.fromJson(bookJson);
    
    final chaptersJson = data['chapters'] as List<dynamic>;
    final chapters = chaptersJson
        .map((json) => Chapter.fromJson(json as Map<String, dynamic>))
        .toList();
    
    return (book, chapters);
  }

  /// 清理文本内容
  static String cleanText(String text) {
    var cleaned = text;
    
    // 移除多余的空白字符
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    // 移除广告内容
    cleaned = cleaned.replaceAll(RegExp(r'\[.*?广告.*?\]'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\(.*?广告.*?\)'), '');
    
    // 规范化换行
    cleaned = cleaned.replaceAll('\n\n', '\n');
    
    return cleaned;
  }

  /// 分割大文本为章节
  static List<String> splitTextIntoChapters(String text, {int chapterSize = 10000}) {
    final chapters = <String>[];
    int start = 0;
    
    while (start < text.length) {
      int end = start + chapterSize;
      if (end >= text.length) {
        end = text.length;
      } else {
        // 尝试在句子边界分割
        final lastPeriod = text.lastIndexOf('.', end);
        final lastComma = text.lastIndexOf('，', end);
        final lastSpace = text.lastIndexOf(' ', end);
        
        if (lastPeriod > start + chapterSize * 0.8) {
          end = lastPeriod + 1;
        } else if (lastComma > start + chapterSize * 0.8) {
          end = lastComma + 1;
        } else if (lastSpace > start + chapterSize * 0.8) {
          end = lastSpace + 1;
        }
      }
      
      chapters.add(text.substring(start, end));
      start = end;
    }
    
    return chapters;
  }

  /// 生成章节标题
  static List<String> generateChapterTitles(int count) {
    final titles = <String>[];
    for (int i = 1; i <= count; i++) {
      titles.add('第${_numberToChinese(i)}章');
    }
    return titles;
  }

  /// 数字转中文
  static String _numberToChinese(int number) {
    if (number == 0) return '零';
    
    final digits = ['', '一', '二', '三', '四', '五', '六', '七', '八', '九'];
    final units = ['', '十', '百', '千'];
    final bigUnits = ['', '万', '亿'];
    
    String result = '';
    int unitIndex = 0;
    int bigUnitIndex = 0;
    
    while (number > 0) {
      final section = number % 10000;
      if (section > 0) {
        String sectionResult = '';
        int sectionUnitIndex = 0;
        int temp = section;
        
        while (temp > 0) {
          final digit = temp % 10;
          if (digit > 0) {
            sectionResult = digits[digit] + units[sectionUnitIndex] + sectionResult;
          }
          temp ~/= 10;
          sectionUnitIndex++;
        }
        
        result = sectionResult + bigUnits[bigUnitIndex] + result;
      }
      
      number ~/= 10000;
      bigUnitIndex++;
    }
    
    // 处理特殊情况
    if (result.startsWith('一十')) {
      result = result.substring(1);
    }
    
    return result;
  }
}
