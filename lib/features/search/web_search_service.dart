import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/remote/serpapi_search_data_source.dart';
import '../../data/datasources/remote/universal_web_crawler_data_source.dart';
import '../../data/datasources/remote/search_engine_data_source.dart';
import '../../data/models/book.dart';
import '../../data/models/chapter.dart';

/// 搜索结果状态
class SearchState {
  final bool isLoading;
  final List<Book> results;
  final String? error;
  final String? currentKeyword;

  SearchState({
    this.isLoading = false,
    this.results = const [],
    this.error,
    this.currentKeyword,
  });

  SearchState copyWith({
    bool? isLoading,
    List<Book>? results,
    String? error,
    String? currentKeyword,
  }) {
    return SearchState(
      isLoading: isLoading ?? this.isLoading,
      results: results ?? this.results,
      error: error,
      currentKeyword: currentKeyword ?? this.currentKeyword,
    );
  }
}

/// 网页搜索服务
class WebSearchService {
  WebSearchService({
    this.serpApiKey,
    this.useSerpApi = false,
  }) {
    _initDataSources();
  }

  final String? serpApiKey;
  final bool useSerpApi;
  
  final List<SearchEngineDataSource> _dataSources = [];

  void _initDataSources() {
    // 添加通用网页爬虫（免 API Key）
    _dataSources.add(UniversalWebCrawlerDataSource(
      searchEngine: 'duckduckgo',
    ));

    // 如果配置了 SerpAPI，也添加它
    if (useSerpApi && serpApiKey != null && serpApiKey!.isNotEmpty) {
      _dataSources.add(SerpApiSearchDataSource(
        apiKey: serpApiKey!,
      ));
    }
  }

  /// 搜索
  Future<List<Book>> search(String keyword, {int limit = 10}) async {
    final results = <Book>[];
    final seenUrls = <String>{};

    for (final source in _dataSources) {
      try {
        final sourceResults = await source.searchRemote(keyword);
        
        for (final book in sourceResults) {
          // 去重
          final uniqueKey = '${book.title}_${book.author}';
          if (!seenUrls.contains(uniqueKey)) {
            seenUrls.add(uniqueKey);
            results.add(book);
          }
        }
      } catch (e) {
        print('WebSearchService: Search error from ${source.sourceName}: $e');
      }
    }

    return results;
  }

  /// 获取网页内容
  Future<BookContent?> fetchContent(String bookId, String url) async {
    for (final source in _dataSources) {
      try {
        final content = await source.fetchWebContent(url);
        return content;
      } catch (e) {
        print('WebSearchService: Fetch error from ${source.sourceName}: $e');
        continue;
      }
    }
    return null;
  }

  /// 获取书籍详情和章节
  Future<(Book, List<Chapter>)?> fetchBookWithChapters(String bookId) async {
    for (final source in _dataSources) {
      try {
        final result = await source.fetchPublicDomainBook(bookId);
        // 检查结果是否有效（有章节内容）
        if (result.$2.isNotEmpty) {
          return result;
        }
      } catch (e) {
        print('WebSearchService: Fetch book error from ${source.sourceName}: $e');
        continue;
      }
    }
    return null;
  }

  /// 清除所有缓存
  Future<void> clearAllCaches() async {
    for (final source in _dataSources) {
      try {
        await source.clearCache();
      } catch (e) {
        print('WebSearchService: Clear cache error: $e');
      }
    }
  }
}

/// WebSearchService Provider
final webSearchServiceProvider = Provider<WebSearchService>((ref) {
  return WebSearchService(
    // 可以从配置中读取 SerpAPI Key
    serpApiKey: null, // 设置为 null，使用免费爬虫
    useSerpApi: false,
  );
});

/// 搜索状态 Notifier
class SearchNotifier extends StateNotifier<SearchState> {
  SearchNotifier(this._service) : super(SearchState());

  final WebSearchService _service;

  Future<void> search(String keyword) async {
    if (keyword.isEmpty) {
      state = SearchState();
      return;
    }

    state = state.copyWith(
      isLoading: true,
      error: null,
      currentKeyword: keyword,
    );

    try {
      final results = await _service.search(keyword);
      state = state.copyWith(
        isLoading: false,
        results: results,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '搜索失败: $e',
      );
    }
  }

  void clear() {
    state = SearchState();
  }
}

/// 搜索状态 Provider
final searchProvider = StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  final service = ref.watch(webSearchServiceProvider);
  return SearchNotifier(service);
});
