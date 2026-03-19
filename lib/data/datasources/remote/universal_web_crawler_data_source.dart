import 'dart:async';
import 'package:hive/hive.dart';
import '../../../core/crawler/web_crawler.dart';
import '../../../core/cache/cache_manager.dart';
import '../../models/book.dart';
import '../../models/chapter.dart';
import 'search_engine_data_source.dart';
import 'universal_book_data_source.dart';

/// 通用网页爬虫数据源
/// 使用 DuckDuckGo 或 SearX 等免 API Key 搜索服务
class UniversalWebCrawlerDataSource extends SearchEngineDataSource {
  UniversalWebCrawlerDataSource({
    WebCrawler? webCrawler,
    CacheManager? cacheManager,
    this.enableCache = true,
    this.searchEngine = 'duckduckgo', // duckduckgo, searx, bing
  }) : _webCrawler = webCrawler ?? WebCrawler(),
       _cacheManager = cacheManager ?? CacheManager() {
    _initCache();
  }

  final WebCrawler _webCrawler;
  final CacheManager _cacheManager;
  final bool enableCache;
  final String searchEngine;
  
  Box<dynamic>? _cacheBox;
  static const String _cacheBoxName = 'web_crawler_cache';
  static const String _sourceName = 'WebCrawler';

  Future<void> _initCache() async {
    if (!enableCache) return;
    try {
      _cacheBox = await Hive.openBox(_cacheBoxName);
    } catch (e) {
      print('UniversalWebCrawlerDataSource: Cache init error: $e');
    }
  }

  @override
  String get sourceName => '$_sourceName($searchEngine)';

  @override
  String get baseUrl => 'https://$searchEngine.com';

  @override
  List<SearchType> get supportedSearchTypes => [
    SearchType.title,
    SearchType.keyword,
  ];

  @override
  String get sourceType => 'webCrawler';

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<DataSourceHealthStatus> checkHealthStatus() async {
    try {
      final testResult = await searchWeb('test', limit: 1);
      return testResult.isNotEmpty 
        ? DataSourceHealthStatus.healthy 
        : DataSourceHealthStatus.degraded;
    } catch (e) {
      return DataSourceHealthStatus.unavailable;
    }
  }

  @override
  Future<List<SearchResult>> searchWeb(String keyword, {int limit = 10}) async {
    // 检查缓存
    final cacheKey = 'search_${searchEngine}_${keyword}_$limit';
    if (enableCache && _cacheBox != null) {
      final cached = _cacheBox!.get(cacheKey);
      if (cached != null) {
        final cacheTime = _cacheBox!.get('${cacheKey}_time') as DateTime?;
        if (cacheTime != null && 
            DateTime.now().difference(cacheTime).inHours < 6) { // 6小时缓存
          return (cached as List)
              .map((e) => SearchResult.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        }
      }
    }

    try {
      final searchUrl = _buildSearchUrl(keyword);
      final html = await _webCrawler.crawl(searchUrl);
      
      if (html.isEmpty) {
        return [];
      }

      // 检测是否被反爬虫拦截（CAPTCHA页面）
      if (html.contains('Please complete the following challenge') ||
          html.contains('bot protection') ||
          html.contains('captcha')) {
        print('UniversalWebCrawlerDataSource: Blocked by CAPTCHA');
        return [];
      }

      print('DDG_HTML_SAMPLE: ${html.substring(0, html.length.clamp(0, 500))}');
      final results = _parseSearchResults(html);
      
      // 缓存结果
      if (enableCache && _cacheBox != null && results.isNotEmpty) {
        await _cacheBox!.put(cacheKey, results.map((r) => r.toJson()).toList());
        await _cacheBox!.put('${cacheKey}_time', DateTime.now());
      }

      return results.take(limit).toList();
    } catch (e) {
      print('UniversalWebCrawlerDataSource: Search error: $e');
      return [];
    }
  }

  @override
  Future<BookContent> fetchWebContent(String url) async {
    // 检查缓存
    if (enableCache && _cacheBox != null) {
      final cached = _cacheBox!.get('content_$url');
      if (cached != null) {
        final cacheTime = _cacheBox!.get('content_${url}_time') as DateTime?;
        if (cacheTime != null && 
            DateTime.now().difference(cacheTime).inDays < 7) { // 7天缓存
          return BookContent(
            title: cached['title'],
            author: cached['author'],
            content: cached['content'],
            url: url,
            fetchedAt: DateTime.parse(cached['fetchedAt']),
          );
        }
      }
    }

    try {
      final html = await _webCrawler.crawl(url);
      
      final title = _extractTitle(html) ?? '未知标题';
      final content = _extractMainContent(html);
      final author = _extractAuthor(html);

      if (content.isEmpty || content.length < 200) {
        throw Exception('Content too short or empty');
      }

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
        await _cacheBox!.put('content_${url}_time', DateTime.now());
      }

      return bookContent;
    } catch (e) {
      print('UniversalWebCrawlerDataSource: Fetch content error: $e');
      throw Exception('Failed to fetch content: $e');
    }
  }

  @override
  Future<List<Book>> searchRemote(String keyword, {int limit = 10}) async {
    final results = await searchWeb(keyword, limit: limit);
    
    return results.map((result) => Book(
      id: 'web_${result.url.hashCode}',
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
    return searchRemote(keyword, limit: limit);
  }

  @override
  Future<(Book, List<Chapter>)> fetchPublicDomainBook(String bookId) async {
    try {
      // 解析 URL
      final url = _extractUrlFromBookId(bookId);
      if (url == null) {
        return (
          Book(id: bookId, title: '无效链接', author: '未知', category: ''),
          <Chapter>[],
        );
      }

      final content = await fetchWebContent(url);
      
      final book = Book(
        id: bookId,
        title: content.title,
        author: content.author ?? '网络资源',
        category: '网络资源',
        intro: '',
        sourceType: BookSourceType.publicDomainApi,
        externalUrl: content.url,
      );

      // 分割内容成章节
      final chapters = _splitIntoChapters(content.content, bookId: bookId);
      
      return (book, chapters);
    } catch (e) {
      print('UniversalWebCrawlerDataSource: Fetch book error: $e');
      return (
        Book(id: bookId, title: '获取失败', author: '未知', category: ''),
        <Chapter>[],
      );
    }
  }

  @override
  Future<String> fetchChapterContent(String chapterId, String novelId) async {
    // 从缓存获取
    if (_cacheBox != null) {
      return _cacheBox!.get('chapter_$chapterId') ?? '';
    }
    return '';
  }

  @override
  Future<Map<String, String>> batchFetchChapterContent(
    List<String> chapterIds,
    String novelId,
  ) async {
    final results = <String, String>{};
    for (final id in chapterIds) {
      final content = await fetchChapterContent(id, novelId);
      if (content.isNotEmpty) {
        results[id] = content;
      }
    }
    return results;
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

  // Private helper methods
  String _buildSearchUrl(String keyword) {
    final encodedKeyword = Uri.encodeComponent(keyword);
    
    switch (searchEngine) {
      case 'duckduckgo':
        return 'https://html.duckduckgo.com/html/?q=$encodedKeyword';
      case 'searx':
        return 'https://searx.be/search?q=$encodedKeyword';
      case 'bing':
        return 'https://www.bing.com/search?q=$encodedKeyword';
      default:
        return 'https://html.duckduckgo.com/html/?q=$encodedKeyword';
    }
  }

  List<SearchResult> _parseSearchResults(String html) {
    final results = <SearchResult>[];
    
    switch (searchEngine) {
      case 'duckduckgo':
        return _parseDuckDuckGoResults(html);
      case 'searx':
        return _parseSearxResults(html);
      case 'bing':
        return _parseBingResults(html);
      default:
        return _parseDuckDuckGoResults(html);
    }
  }

  List<SearchResult> _parseDuckDuckGoResults(String html) {
    final results = <SearchResult>[];

    // DuckDuckGo HTML 搜索结果解析 - 每个结果在 class="result" 的 div 中
    // 先按结果块分割，再从每个块中提取信息
    final blockPattern = RegExp(
      r'<div\s+class="[^"]*\bresult\b[^"]*"[^>]*>(.*?)</div>\s*</div>',
      caseSensitive: false,
      dotAll: true,
    );

    for (final block in blockPattern.allMatches(html)) {
      final blockHtml = block.group(0) ?? '';

      // 提取标题链接
      final linkMatch = RegExp(
        r'<a[^>]*class="[^"]*result__a[^"]*"[^>]*href="([^"]*)"[^>]*>(.*?)</a>',
        caseSensitive: false,
        dotAll: true,
      ).firstMatch(blockHtml);

      if (linkMatch == null) continue;

      var url = linkMatch.group(1) ?? '';
      var title = (linkMatch.group(2) ?? '').replaceAll(RegExp(r'<[^>]+>'), '').trim();

      // 提取摘要
      final snippetMatch = RegExp(
        r'<a[^>]*class="[^"]*result__snippet[^"]*"[^>]*>(.*?)</a>',
        caseSensitive: false,
        dotAll: true,
      ).firstMatch(blockHtml);
      var snippet = (snippetMatch?.group(1) ?? '').replaceAll(RegExp(r'<[^>]+>'), '').trim();

      // 处理 DuckDuckGo 的跳转链接
      if (url.startsWith('//')) {
        url = 'https:$url';
      } else if (url.startsWith('/l/?')) {
        final uddgMatch = RegExp(r'uddg=([^&]+)').firstMatch(url);
        if (uddgMatch != null) {
          url = Uri.decodeComponent(uddgMatch.group(1)!);
        }
      }

      if (url.isNotEmpty && title.isNotEmpty) {
        results.add(SearchResult(
          title: title,
          url: url,
          snippet: snippet.isNotEmpty ? snippet : null,
          source: 'DuckDuckGo',
        ));
      }
    }

    // 备用解析：如果上面没匹配到，尝试更宽松的模式
    if (results.isEmpty) {
      final linkPattern = RegExp(
        r'<a[^>]*class="[^"]*result__a[^"]*"[^>]*href="([^"]*)"[^>]*>(.*?)</a>',
        caseSensitive: false,
        dotAll: true,
      );
      for (final match in linkPattern.allMatches(html)) {
        var url = match.group(1) ?? '';
        var title = (match.group(2) ?? '').replaceAll(RegExp(r'<[^>]+>'), '').trim();

        if (url.startsWith('/l/?')) {
          final uddgMatch = RegExp(r'uddg=([^&]+)').firstMatch(url);
          if (uddgMatch != null) {
            url = Uri.decodeComponent(uddgMatch.group(1)!);
          }
        } else if (url.startsWith('//')) {
          url = 'https:$url';
        }

        if (url.isNotEmpty && title.isNotEmpty && url.startsWith('http')) {
          results.add(SearchResult(
            title: title,
            url: url,
            snippet: null,
            source: 'DuckDuckGo',
          ));
        }
      }
    }

    return results;
  }

  List<SearchResult> _parseSearxResults(String html) {
    final results = <SearchResult>[];
    
    final resultBlocks = RegExp(
      r'<article[^>]*class="[^"]*result[^"]*"[^>]*>.*?<h3[^>]*>.*?<a[^>]*href="([^"]*)"[^>]*>(.*?)</a>.*?</h3>.*?<p[^>]*class="[^"]*content[^"]*"[^>]*>(.*?)</p>.*?</article>',
      caseSensitive: false,
      dotAll: true,
    ).allMatches(html);

    for (final match in resultBlocks) {
      if (match.groupCount >= 3) {
        var title = match.group(2) ?? '';
        var snippet = match.group(3) ?? '';
        
        title = title.replaceAll(RegExp(r'<[^>]+>'), '').trim();
        snippet = snippet.replaceAll(RegExp(r'<[^>]+>'), '').trim();

        results.add(SearchResult(
          title: title,
          url: match.group(1) ?? '',
          snippet: snippet.isNotEmpty ? snippet : null,
          source: 'SearX',
        ));
      }
    }

    return results;
  }

  List<SearchResult> _parseBingResults(String html) {
    final results = <SearchResult>[];
    
    final resultBlocks = RegExp(
      r'<li class="b_algo"[^>]*>.*?<h2[^>]*>.*?<a[^>]*href="([^"]*)"[^>]*>(.*?)</a>.*?</h2>.*?<p[^>]*>(.*?)</p>.*?</li>',
      caseSensitive: false,
      dotAll: true,
    ).allMatches(html);

    for (final match in resultBlocks) {
      if (match.groupCount >= 3) {
        var title = match.group(2) ?? '';
        var snippet = match.group(3) ?? '';
        
        title = title.replaceAll(RegExp(r'<[^>]+>'), '').trim();
        snippet = snippet.replaceAll(RegExp(r'<[^>]+>'), '').trim();

        results.add(SearchResult(
          title: title,
          url: match.group(1) ?? '',
          snippet: snippet.isNotEmpty ? snippet : null,
          source: 'Bing',
        ));
      }
    }

    return results;
  }

  String? _extractUrlFromBookId(String bookId) {
    // bookId 格式: web_<url_hash>
    // 由于 hash 不可逆，我们需要通过其他方式获取 URL
    // 目前从缓存中查找
    if (_cacheBox != null) {
      // 查找所有缓存的内容，匹配 bookId
      for (final key in _cacheBox!.keys) {
        if (key is String && key.startsWith('content_')) {
          final cached = _cacheBox!.get(key);
          if (cached != null && cached is Map) {
            // 检查这个缓存项是否匹配 bookId
            final url = key.replaceFirst('content_', '');
            if ('web_${url.hashCode}' == bookId) {
              return url;
            }
          }
        }
      }
    }
    return null;
  }

  String? _extractTitle(String html) {
    final titleMatch = RegExp(r'<title[^>]*>([^<]*)</title>', caseSensitive: false)
        .firstMatch(html);
    return titleMatch?.group(1)?.trim();
  }

  String? _extractAuthor(String html) {
    // 尝试从 meta 标签提取
    final metaPattern = RegExp(
      '<meta[^>]*name="author"[^>]*content="([^"]*)"',
      caseSensitive: false,
    );
    final metaMatch = metaPattern.firstMatch(html);
    if (metaMatch != null) {
      return metaMatch.group(1)?.trim();
    }
    return null;
  }

  String _extractMainContent(String html) {
    // 移除脚本、样式和导航
    var content = html
        .replaceAll(RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<nav[^>]*>[\s\S]*?</nav>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<header[^>]*>[\s\S]*?</header>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<footer[^>]*>[\s\S]*?</footer>', caseSensitive: false), '');

    // 尝试找到主要内容区域
    final contentSelectors = [
      RegExp(r'<article[^>]*>([\s\S]*?)</article>', caseSensitive: false),
      RegExp(r'<main[^>]*>([\s\S]*?)</main>', caseSensitive: false),
      RegExp(r'<div[^>]*class="[^"]*(?:content|article|post|entry)[^"]*"[^>]*>([\s\S]*?)</div>', caseSensitive: false),
      RegExp(r'<div[^>]*id="[^"]*(?:content|article|post|entry)[^"]*"[^>]*>([\s\S]*?)</div>', caseSensitive: false),
    ];

    for (final selector in contentSelectors) {
      final match = selector.firstMatch(content);
      if (match != null) {
        final extracted = match.group(1)!;
        if (extracted.length > 500) {
          content = extracted;
          break;
        }
      }
    }

    // 清理 HTML
    content = content
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&gt;', '>')
        .replaceAll('&lt;', '<')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"');

    // 清理多余空白
    content = content.replaceAll(RegExp(r'\s+'), ' ').trim();

    return content;
  }

  List<Chapter> _splitIntoChapters(String content, {int wordsPerChapter = 3000, required String bookId}) {
    final chapters = <Chapter>[];
    
    // 尝试识别章节标题
    final chapterPattern = RegExp(r'第[一二三四五六七八九十百千零\d]+章[^\n]*');
    final chapterMatches = chapterPattern.allMatches(content).toList();
    
    if (chapterMatches.length > 2) {
      // 按章节标题分割
      for (var i = 0; i < chapterMatches.length; i++) {
        final start = chapterMatches[i].start;
        final end = i < chapterMatches.length - 1 
            ? chapterMatches[i + 1].start 
            : content.length;
        
        final chapterTitle = chapterMatches[i].group(0) ?? '第${i + 1}章';
        final chapterContent = content.substring(start, end).trim();

        chapters.add(Chapter(
          id: 'chapter_$i',
          bookId: bookId,
          title: chapterTitle,
          content: chapterContent.replaceFirst(chapterTitle, '').trim(),
          index: i,
        ));
      }
    } else {
      // 按字数平均分割
      final runes = content.runes.toList();
      final totalChapters = (runes.length / wordsPerChapter).ceil();

      for (var i = 0; i < totalChapters; i++) {
        final start = i * wordsPerChapter;
        final end = ((i + 1) * wordsPerChapter).clamp(0, runes.length);
        final chapterContent = String.fromCharCodes(runes.sublist(start, end));

        chapters.add(Chapter(
          id: 'chapter_$i',
          bookId: bookId,
          title: '第${i + 1}部分',
          content: chapterContent,
          index: i,
        ));
      }
    }

    return chapters;
  }
}
