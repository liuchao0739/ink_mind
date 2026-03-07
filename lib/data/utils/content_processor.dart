import '../models/book.dart';
import '../models/chapter.dart';
import '../datasources/remote/remote_book_data_source.dart';
import '../datasources/remote/ctext_book_data_source.dart';

/// 热门书籍映射表 - ctext.org 路径
const Map<String, Map<String, String>> _famousBooksMap = {
  '红楼梦': {'path': 'hongloumeng', 'author': '曹雪芹', 'title': '红楼梦'},
  '西游': {'path': 'journeywest', 'author': '吴承恩', 'title': '西游记'},
  '三国': {'path': 'romance', 'author': '罗贯中', 'title': '三国演义'},
  '水浒': {'path': 'watermargin', 'author': '施耐庵', 'title': '水浒传'},
  '论语': {'path': 'analects', 'author': '孔子', 'title': '论语'},
  '孟子': {'path': 'mengzi', 'author': '孟轲', 'title': '孟子'},
  '庄子': {'path': 'zhuangzi', 'author': '庄周', 'title': '庄子'},
  '道德经': {'path': 'taotejing', 'author': '老子', 'title': '道德经'},
  '史记': {'path': 'shiji', 'author': '司马迁', 'title': '史记'},
  '资治通鉴': {'path': 'zizhitongjian', 'author': '司马光', 'title': '资治通鉴'},
  '黄帝内经': {'path': 'huangdi', 'author': '黄帝', 'title': '黄帝内经'},
  '诗经': {'path': 'shijing', 'author': '孔子', 'title': '诗经'},
};

/// 内容处理器
/// 负责智能内容获取、拼接和质量评估
class ContentProcessor {
  ContentProcessor(this._remoteDataSource);

  final RemoteBookDataSource? _remoteDataSource;

  /// 智能获取书籍内容（从多个数据源）
  Future<(Book, List<Chapter>)> smartFetchBook(String keyword) async {
    print('ContentProcessor: Smart fetching book for keyword: $keyword');
    final ctext = CtextDataSource();

    // 1. 首先检查热门书籍映射
    final lowerKeyword = keyword.toLowerCase();
    for (final entry in _famousBooksMap.entries) {
      if (lowerKeyword.contains(entry.key.toLowerCase()) ||
          entry.key.toLowerCase().contains(lowerKeyword)) {
        try {
          print('ContentProcessor: Step 1: Found in famous books map: ${entry.key}');
          final path = '/${entry.value['path']}';
          final result = await ctext.fetchPublicDomainBook(path);
          if (result.$1.title.isNotEmpty || result.$2.isNotEmpty) {
            // 更新作者信息
            final book = result.$1.title.isEmpty
                ? result.$1.copyWith(
                    title: entry.value['title']!,
                    author: entry.value['author']!,
                  )
                : result.$1.copyWith(author: entry.value['author']!);
            print('ContentProcessor: Found book: ${book.title}');
            return (book, result.$2);
          }
        } catch (e) {
          print('ContentProcessor: Error fetching famous book: $e');
        }
      }
    }

    // 2. 尝试直接用keyword作为路径
    try {
      print('ContentProcessor: Step 2: Trying keyword as path');
      final path = '/$keyword';
      final result = await ctext.fetchPublicDomainBook(path);
      if (result.$1.title.isNotEmpty && result.$2.isNotEmpty) {
        print('ContentProcessor: Found book: ${result.$1.title}');
        return result;
      }
    } catch (e) {
      print('ContentProcessor: Error with direct path: $e');
    }

    // 3. 回退到 RemoteBookDataSource 搜索
    if (_remoteDataSource != null) {
      try {
        print('ContentProcessor: Step 2: Using remote data source search');
        final books = await _remoteDataSource.searchRemote(keyword);
        print('ContentProcessor: Remote search returned ${books.length} books');

        if (books.isEmpty) {
          throw Exception('No books found for keyword: $keyword');
        }

        // 按相关性排序
        final sortedBooks = _rankBooksByRelevance(books, keyword);

        // 尝试获取第一本书的详细内容
        for (final book in sortedBooks) {
          if (book.remoteApiId != null && book.remoteApiId!.isNotEmpty) {
            try {
              final result = await _remoteDataSource.fetchPublicDomainBook(book.remoteApiId!);
              if (result.$2.isNotEmpty) {
                return (result.$1, result.$2);
              }
            } catch (e) {
              print('Error fetching book: $e');
              continue;
            }
          }
        }

        throw Exception('Failed to fetch book content from all sources');
      } catch (e) {
        print('ContentProcessor: Error in remote search: $e');
        throw Exception('Failed to fetch book content');
      }
    }

    throw Exception('No data sources available');
  }

  /// 智能拼接章节内容
  Future<List<Chapter>> smartFetchChapters(String bookId, List<Chapter> chapters) async {
    if (chapters.isEmpty) {
      return [];
    }
    // 内容已经在 getChaptersForBook 中获取，这里直接优化
    return _optimizeChapters(chapters);
  }

  /// 按相关性排序书籍
  List<Book> _rankBooksByRelevance(List<Book> books, String keyword) {
    final lowerKeyword = keyword.toLowerCase();

    books.sort((a, b) {
      // 1. 标题完全匹配优先
      final aTitleMatch = a.title.toLowerCase() == lowerKeyword ? 3 :
                          a.title.toLowerCase().contains(lowerKeyword) ? 2 : 0;
      final bTitleMatch = b.title.toLowerCase() == lowerKeyword ? 3 :
                          b.title.toLowerCase().contains(lowerKeyword) ? 2 : 0;
      if (aTitleMatch != bTitleMatch) {
        return bTitleMatch.compareTo(aTitleMatch);
      }

      // 2. 热度排序
      final aHeat = a.heatScore ?? 0;
      final bHeat = b.heatScore ?? 0;
      if (aHeat != bHeat) {
        return bHeat.compareTo(aHeat);
      }

      return 0;
    });

    return books;
  }

  /// 优化章节内容
  List<Chapter> _optimizeChapters(List<Chapter> chapters) {
    return chapters.map((chapter) {
      var optimizedContent = _cleanContent(chapter.content ?? '');
      return chapter.copyWith(content: optimizedContent);
    }).toList();
  }

  /// 清理内容
  String _cleanContent(String content) {
    // 1. 移除HTML标签
    var cleaned = content.replaceAll(RegExp(r'<[^>]*>'), '');

    // 2. 移除多余的空白字符
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();

    // 3. 移除广告和无关内容
    cleaned = cleaned.replaceAll(RegExp(r'\[.*?广告.*?\]'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\(.*?广告.*?\)'), '');

    // 4. 规范化换行
    cleaned = cleaned.replaceAll('\n\n\n', '\n\n');

    return cleaned;
  }
}
