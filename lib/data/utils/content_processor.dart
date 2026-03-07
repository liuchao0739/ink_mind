import '../models/book.dart';
import '../models/chapter.dart';
import '../datasources/remote/universal_book_data_source.dart';
import '../datasources/remote/data_source_manager.dart';
import '../../core/crawler/web_crawler.dart';

/// 内容处理器
/// 负责智能内容获取、拼接和质量评估
class ContentProcessor {
  ContentProcessor(this._dataSourceManager) : _crawler = WebCrawler();

  final DataSourceManager? _dataSourceManager;
  final WebCrawler _crawler;

  /// 智能获取书籍内容（从多个数据源）
  Future<(Book, List<Chapter>)> smartFetchBook(String keyword) async {
    print('ContentProcessor: Smart fetching book for keyword: $keyword');
    try {
      // 1. 尝试使用增强爬虫搜索
      print('ContentProcessor: Step 1: Using enhanced crawler search');
      final crawlerResults = await _crawler.search(keyword);
      print('ContentProcessor: Crawler returned ${crawlerResults.length} results');
      if (crawlerResults.isNotEmpty) {
        print('ContentProcessor: Processing crawler results...');
        for (final result in crawlerResults) {
          try {
            print('ContentProcessor: Processing result: ${result['title']} by ${result['author']}');
            final bookUrl = result['url'] as String;
            print('ContentProcessor: Crawling book URL: $bookUrl');
            final bookData = await _crawler.crawl99CSW(bookUrl);
            if (bookData.isNotEmpty) {
              print('ContentProcessor: Successfully crawled book data');
              final bookInfo = bookData['book'] as Map<String, dynamic>;
              final chaptersData = bookData['chapters'] as List<dynamic>;
              print('ContentProcessor: Found ${chaptersData.length} chapters');

              // 构建Book对象
              final book = Book(
                id: 'crawler_${bookInfo['title']}'.replaceAll(' ', '_'),
                title: bookInfo['title'] as String,
                author: bookInfo['author'] as String,
                category: '网络小说',
                intro: bookInfo['intro'] as String,
                sourceType: BookSourceType.publicDomainApi,
                remoteApiId: bookUrl,
              );
              print('ContentProcessor: Created book object: ${book.title}');

              // 构建Chapter列表
              final chapters = <Chapter>[];
              print('ContentProcessor: Fetching chapter contents...');
              for (final chapterData in chaptersData) {
                final chapterMap = chapterData as Map<String, dynamic>;
                final chapterUrl = chapterMap['url'] as String;
                print('ContentProcessor: Crawling chapter URL: $chapterUrl');
                final chapterContent = await _crawler.crawlChapter(chapterUrl);

                chapters.add(Chapter(
                  id: chapterMap['id'] as String,
                  bookId: book.id,
                  index: chapterMap['index'] as int,
                  title: chapterMap['title'] as String,
                  content: chapterContent,
                ));
              }
              print('ContentProcessor: Created ${chapters.length} chapter objects');

              return (book, chapters);
            }
          } catch (e) {
            print('ContentProcessor: Error fetching book from crawler: $e');
            continue;
          }
        }
      }
    } catch (e) {
      print('ContentProcessor: Error in smartFetchBook: $e');
      // 继续使用传统搜索
    }

    // 2. 回退到传统搜索
    if (_dataSourceManager != null) {
      try {
        final books = await _dataSourceManager.searchAllSources(keyword);
        if (books.isEmpty) {
          throw Exception('No books found for keyword: $keyword');
        }

        // 3. 按相关性排序
        final sortedBooks = _rankBooksByRelevance(books, keyword);

        // 4. 尝试从多个数据源获取内容
        for (final book in sortedBooks) {
          try {
            final result = await _dataSourceManager.fetchBookFromAnySource(book.remoteApiId!);
            if (result != null && result.$2.isNotEmpty) {
              // 5. 增强章节内容
              final enhancedChapters = await _enhanceChapters(result.$1, result.$2);
              return (result.$1, enhancedChapters);
            }
          } catch (e) {
            print('Error fetching book from source: $e');
            continue;
          }
        }

        throw Exception('Failed to fetch book content from all sources');
      } catch (e) {
        print('ContentProcessor: Error in traditional search: $e');
        throw Exception('Failed to fetch book content');
      }
    } else {
      // 如果没有数据源，直接抛出异常
      throw Exception('No data sources available');
    }
  }

  /// 智能拼接章节内容（从多个数据源）
  Future<List<Chapter>> smartFetchChapters(String bookId, List<Chapter> chapters) async {
    if (chapters.isEmpty) {
      return [];
    }

    // 1. 提取章节ID
    final chapterIds = chapters.map((c) => c.id).toList();

    // 2. 批量获取章节内容
    final contentMap = <String, String>{};
    if (_dataSourceManager != null) {
      contentMap.addAll(await _dataSourceManager.batchFetchChapterContent(chapterIds, bookId));
    }

    // 3. 填充章节内容
    final enhancedChapters = chapters.map((chapter) {
      final content = contentMap[chapter.id] ?? '';
      return chapter.copyWith(content: content);
    }).toList();

    // 4. 内容质量评估和优化
    return _optimizeChapters(enhancedChapters);
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

      // 2. 作者匹配
      final aAuthorMatch = a.author.toLowerCase().contains(lowerKeyword) ? 1 : 0;
      final bAuthorMatch = b.author.toLowerCase().contains(lowerKeyword) ? 1 : 0;
      if (aAuthorMatch != bAuthorMatch) {
        return bAuthorMatch.compareTo(aAuthorMatch);
      }

      // 3. 热度排序
      final aHeat = a.heatScore ?? 0;
      final bHeat = b.heatScore ?? 0;
      if (aHeat != bHeat) {
        return bHeat.compareTo(aHeat);
      }

      return 0;
    });

    return books;
  }

  /// 增强章节内容
  Future<List<Chapter>> _enhanceChapters(Book book, List<Chapter> chapters) async {
    // 1. 批量获取章节内容
    final chapterIds = chapters.map((c) => c.id).toList();
    final contentMap = <String, String>{};
    if (_dataSourceManager != null && book.remoteApiId != null) {
      contentMap.addAll(await _dataSourceManager.batchFetchChapterContent(chapterIds, book.remoteApiId!));
    }

    // 2. 填充章节内容
    final enhancedChapters = chapters.map((chapter) {
      final content = contentMap[chapter.id] ?? '';
      return chapter.copyWith(content: content);
    }).toList();

    // 3. 优化章节
    return _optimizeChapters(enhancedChapters);
  }

  /// 优化章节内容
  List<Chapter> _optimizeChapters(List<Chapter> chapters) {
    return chapters.map((chapter) {
      // 1. 清理内容
      var optimizedContent = _cleanContent(chapter.content ?? ''); // 处理null值
      
      // 2. 内容质量评估
      final qualityScore = _evaluateContentQuality(optimizedContent);
      
      // 3. 如果内容质量低，尝试从其他数据源获取
      // 这里可以实现更复杂的逻辑，比如从其他数据源获取内容
      
      return chapter.copyWith(
        content: optimizedContent,
        // 可以添加质量分数到章节中
      );
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
    cleaned = cleaned.replaceAll('\n\n', '\n');
    
    return cleaned;
  }

  /// 评估内容质量
  int _evaluateContentQuality(String content) {
    if (content.isEmpty) {
      return 0;
    }

    // 1. 内容长度评分
    final lengthScore = content.length > 500 ? 3 : content.length > 100 ? 2 : 1;
    
    // 2. 内容完整性评分
    final completenessScore = _evaluateCompleteness(content);
    
    // 3. 内容相关性评分
    final relevanceScore = _evaluateRelevance(content);
    
    // 4. 综合评分
    return lengthScore + completenessScore + relevanceScore;
  }

  /// 评估内容完整性
  int _evaluateCompleteness(String content) {
    // 简单的完整性评估逻辑
    if (content.length > 1000) {
      return 3;
    } else if (content.length > 300) {
      return 2;
    } else {
      return 1;
    }
  }

  /// 评估内容相关性
  int _evaluateRelevance(String content) {
    // 简单的相关性评估逻辑
    // 这里可以实现更复杂的算法，比如关键词匹配
    return 2; // 默认评分
  }

  /// 深度搜索
  Future<List<Book>> deepSearch(String keyword, {
    SearchType searchType = SearchType.keyword,
    int depth = 3,
  }) async {
    final results = <Book>{};
    
    if (_dataSourceManager != null) {
      // 1. 初始搜索
      final initialResults = await _dataSourceManager.advancedSearchAllSources(
        keyword: keyword,
        searchType: searchType,
      );
      results.addAll(initialResults);
      
      // 2. 深度搜索（递归）
      if (depth > 0) {
        for (final book in initialResults) {
          // 获取相关推荐
          final relatedBooks = await _dataSourceManager.getHealthyDataSources().then((sources) async {
            final related = <Book>[];
            for (final source in sources) {
              try {
                final books = await source.getRelatedBooks(book.remoteApiId!);
                related.addAll(books);
              } catch (e) {
                continue;
              }
            }
            return related;
          });
          
          results.addAll(relatedBooks);
          
          // 递归搜索
          for (final relatedBook in relatedBooks) {
            final deepResults = await deepSearch(
              relatedBook.title,
              searchType: SearchType.title,
              depth: depth - 1,
            );
            results.addAll(deepResults);
          }
        }
      }
    }
    
    return results.toList();
  }

  /// 智能联想搜索
  Future<List<String>> suggestKeywords(String keyword) async {
    final suggestions = <String>{};
    
    if (_dataSourceManager != null) {
      // 1. 从搜索结果中提取关键词
      final books = await _dataSourceManager.searchAllSources(keyword);
      for (final book in books) {
        suggestions.add(book.title);
        suggestions.add(book.author);
        // 从简介中提取关键词
        final introKeywords = _extractKeywords(book.intro);
        suggestions.addAll(introKeywords);
      }
    }
    
    // 2. 过滤和排序
    return suggestions
        .where((s) => s.contains(keyword) && s != keyword)
        .take(10)
        .toList();
  }

  /// 提取关键词
  List<String> _extractKeywords(String text) {
    // 简单的关键词提取逻辑
    // 这里可以实现更复杂的NLP算法
    final words = text.split(RegExp(r'\s+'));
    return words
        .where((word) => word.length > 2)
        .take(5)
        .toList();
  }
}
