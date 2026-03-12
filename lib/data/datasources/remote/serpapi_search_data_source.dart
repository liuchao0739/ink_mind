import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:hive/hive.dart';
import '../../../core/network/api_client.dart';
import '../../models/book.dart';
import '../../models/chapter.dart';
import 'search_engine_data_source.dart';
import 'universal_book_data_source.dart';

/// SerpAPI 搜索引擎数据源实现
/// 需要申请 API Key: https://serpapi.com
class SerpApiSearchDataSource extends SearchEngineDataSource {
  SerpApiSearchDataSource({
    required this.apiKey,
    ApiClient? apiClient,
    this.enableCache = true,
  }) : _apiClient = apiClient ?? ApiClient(baseUrl: 'https://serpapi.com') {
    _initCache();
  }

  final String apiKey;
  final ApiClient _apiClient;
  final bool enableCache;
  Box<dynamic>? _cacheBox;

  static const String _cacheBoxName = 'serpapi_cache';
  static const String _sourceName = 'SerpAPI';

  Future<void> _initCache() async {
    if (!enableCache) return;
    try {
      _cacheBox = await Hive.openBox(_cacheBoxName);
    } catch (e) {
      print('SerpApiSearchDataSource: Cache init error: $e');
    }
  }

  @override
  String get sourceName => _sourceName;

  @override
  String get baseUrl => 'https://serpapi.com';

  @override
  List<SearchType> get supportedSearchTypes => [
    SearchType.title,
    SearchType.author,
    SearchType.keyword,
  ];

  @override
  String get sourceType => 'searchEngine';

  @override
  Future<bool> isAvailable() async {
    return apiKey.isNotEmpty;
  }

  @override
  Future<DataSourceHealthStatus> checkHealthStatus() async {
    try {
      if (apiKey.isEmpty) {
        return DataSourceHealthStatus.unavailable;
      }
      // 简单测试搜索
      final testResult = await searchWeb('test', limit: 1);
      return testResult.isNotEmpty 
        ? DataSourceHealthStatus.healthy 
        : DataSourceHealthStatus.degraded;
    } catch (e) {
      return DataSourceHealthStatus.unavailable;
    }
  }

  /// 搜索网页
  /// [keyword] 搜索关键词
  /// [limit] 返回结果数量
  @override
  Future<List<SearchResult>> searchWeb(String keyword, {int limit = 10}) async {
    // 检查缓存
    final cacheKey = 'search_${keyword}_$limit';
    if (enableCache && _cacheBox != null) {
      final cached = _cacheBox!.get(cacheKey);
      if (cached != null) {
        final cacheTime = _cacheBox!.get('${cacheKey}_time') as DateTime?;
        if (cacheTime != null && 
            DateTime.now().difference(cacheTime).inHours < 24) {
          print('SerpApiSearchDataSource: Returning cached results for $keyword');
          return (cached as List)
              .map((e) => SearchResult.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        }
      }
    }

    try {
      final response = await _apiClient.dio.get(
        '/search',
        queryParameters: {
          'q': keyword,
          'api_key': apiKey,
          'engine': 'google',
          'num': limit,
          'hl': 'zh-CN',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Search failed: ${response.statusCode}');
      }

      final data = response.data;
      final results = <SearchResult>[];

      // 解析搜索结果
      final organicResults = data['organic_results'] as List?;
      if (organicResults != null) {
        for (final result in organicResults) {
          results.add(SearchResult(
            title: result['title'] ?? '未知标题',
            url: result['link'] ?? '',
            snippet: result['snippet'],
            source: _sourceName,
            publishedDate: result['date'] != null 
              ? _parseDate(result['date']) 
              : null,
          ));
        }
      }

      // 缓存结果
      if (enableCache && _cacheBox != null) {
        await _cacheBox!.put(cacheKey, results.map((r) => r.toJson()).toList());
        await _cacheBox!.put('${cacheKey}_time', DateTime.now());
      }

      return results;
    } catch (e) {
      print('SerpApiSearchDataSource: Search error: $e');
      return [];
    }
  }

  /// 获取网页内容
  @override
  Future<BookContent> fetchWebContent(String url) async {
    // 检查缓存
    if (enableCache && _cacheBox != null) {
      final cached = _cacheBox!.get('content_$url');
      if (cached != null) {
        return BookContent(
          title: cached['title'],
          author: cached['author'],
          content: cached['content'],
          url: url,
          fetchedAt: DateTime.parse(cached['fetchedAt']),
        );
      }
    }

    try {
      // 使用爬虫获取内容
      final html = await _apiClient.getTextFromUrl(url);
      
      // 解析标题
      final title = _extractTitle(html) ?? '未知标题';
      
      // 解析正文内容
      final content = _extractContent(html);
      
      // 解析作者（如果可能）
      final author = _extractAuthor(html);

      final bookContent = BookContent(
        title: title,
        author: author,
        content: content,
        url: url,
        fetchedAt: DateTime.now(),
      );

      // 缓存内容
      if (enableCache && _cacheBox != null) {
        await _cacheBox!.put('content_$url', bookContent.toJson());
      }

      return bookContent;
    } catch (e) {
      print('SerpApiSearchDataSource: Fetch content error: $e');
      throw Exception('Failed to fetch content: $e');
    }
  }

  /// 从搜索结果转换为 Book 模型
  @override
  Future<List<Book>> searchRemote(String keyword, {int limit = 10}) async {
    final results = await searchWeb(keyword, limit: limit);
    
    return results.map((result) => Book(
      id: 'serpapi_${result.url.hashCode}',
      title: result.title,
      author: result.source,
      category: '网络资源',
      intro: result.snippet ?? '',
      sourceType: BookSourceType.publicDomainApi,
      externalUrl: result.url,
    )).toList();
  }

  @override
  Future<List<Book>> advancedSearch({
    required String keyword,
    SearchType searchType = SearchType.title,
    String? author,
    String? category,
    int limit = 10,
  }) async {
    String query = keyword;
    
    if (searchType == SearchType.author && author != null) {
      query = 'author:$author $keyword';
    }
    
    return searchRemote(query, limit: limit);
  }

  @override
  Future<(Book, List<Chapter>)> fetchPublicDomainBook(String bookId) async {
    // 从缓存或 URL 获取
    final url = bookId.replaceFirst('serpapi_', '');
    try {
      final content = await fetchWebContent(url);
      
      final book = Book(
        id: bookId,
        title: content.title,
        author: content.author ?? '未知作者',
        category: '网络资源',
        sourceType: BookSourceType.publicDomainApi,
        externalUrl: content.url,
      );

      // 如果内容很长，分割成章节
      final chapters = content.chapters ?? _splitIntoChapters(content.content);
      
      return (book, chapters);
    } catch (e) {
      print('SerpApiSearchDataSource: Fetch book error: $e');
      // 返回空书籍和章节列表
      return (
        Book(
          id: bookId,
          title: '获取失败',
          author: '未知',
          category: '网络资源',
        ),
        <Chapter>[],
      );
    }
  }

  @override
  Future<String> fetchChapterContent(String chapterId) async {
    // 直接返回章节内容
    return '';
  }

  @override
  Future<Map<String, String>> batchFetchChapterContent(
    List<String> chapterIds,
    String novelId,
  ) async {
    return {};
  }

  @override
  Future<List<Book>> getRelatedBooks(String novelId) async {
    return [];
  }

  @override
  Future<Book> fetchNovelDetail(String novelId) async {
    final result = await fetchPublicDomainBook(novelId);
    if (result != null) {
      return result.$1;
    }
    throw Exception('Book not found: $novelId');
  }

  @override
  Future<List<Chapter>> fetchChapterList(String novelId) async {
    final result = await fetchPublicDomainBook(novelId);
    if (result != null) {
      return result.$2;
    }
    return [];
  }

  @override
  Future<void> clearCache() async {
    if (_cacheBox != null) {
      await _cacheBox!.clear();
    }
  }

// Helper methods
  DateTime? _parseDate(String dateStr) {
    try {
      return DateTime.parse(dateStr);
    } catch (e) {
      return null;
    }
  }

  String? _extractTitle(String html) {
    final titleMatch = RegExp(r'<title[^>]*>([^<]*)</title>', caseSensitive: false)
        .firstMatch(html);
    return titleMatch?.group(1)?.trim();
  }

  String _extractContent(String html) {
    // 移除脚本和样式
    var content = html
        .replaceAll(RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false), '');
    
    // 提取正文区域（常见选择器）
    final contentPatterns = [
      RegExp(r'<article[^>]*>([\s\S]*?)</article>', caseSensitive: false),
      RegExp(r'<main[^>]*>([\s\S]*?)</main>', caseSensitive: false),
      RegExp(r'<div[^>]*class="[^"]*content[^"]*"[^>]*>([\s\S]*?)</div>', caseSensitive: false),
      RegExp(r'<div[^>]*id="[^"]*content[^"]*"[^>]*>([\s\S]*?)</div>', caseSensitive: false),
    ];

    for (final pattern in contentPatterns) {
      final match = pattern.firstMatch(content);
      if (match != null) {
        content = match.group(1)!;
        break;
      }
    }

    // 移除 HTML 标签
    content = content.replaceAll(RegExp(r'<[^>]+>'), ' ');
    
    // 解码 HTML 实体
    content = content
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&gt;', '>')
        .replaceAll('&lt;', '<')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"');

    // 清理空白
    content = content.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    return content.length > 100 ? content : '';
  }

  String? _extractAuthor(String html) {
    // 尝试从 meta 标签提取作者
    final authorPatterns = [
      RegExp(r'<meta[^>]*name="author"[^>]*content="([^"]*)"', caseSensitive: false),
      RegExp(r'<meta[^>]*property="[^"]*author"[^>]*content="([^"]*)"', caseSensitive: false),
    ];

    for (final pattern in authorPatterns) {
      final match = pattern.firstMatch(html);
      if (match != null) {
        return match.group(1)?.trim();
      }
    }

    // 尝试从文本提取
    final textMatch = RegExp(r'作者[：:]\s*([^\n<]{1,50})').firstMatch(html);
    return textMatch?.group(1)?.trim();
  }

  List<Chapter> _splitIntoChapters(String content, {int wordsPerChapter = 3000}) {
    final chapters = <Chapter>[];
    final words = content.split('');
    final totalChapters = (words.length / wordsPerChapter).ceil();

    for (var i = 0; i < totalChapters; i++) {
      final start = i * wordsPerChapter;
      final end = (i + 1) * wordsPerChapter;
      final chapterContent = words.sublist(
        start,
        end > words.length ? words.length : end,
      ).join();

      chapters.add(Chapter(
        id: 'chapter_$i',
        title: '第${i + 1}章',
        content: chapterContent,
        index: i,
      ));
    }

    return chapters;
  }
}
