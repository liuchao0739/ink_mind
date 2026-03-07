import 'dart:async';
import 'package:collection/collection.dart';
import '../../models/book.dart';
import '../../models/chapter.dart';
import 'universal_book_data_source.dart';

/// 数据源管理器
/// 负责管理多个数据源的注册、调度和健康检查
class DataSourceManager {
  DataSourceManager() : _dataSources = [];
  
  final List<UniversalBookDataSource> _dataSources;
  final Map<String, DataSourceHealthStatus> _healthStatuses = {};
  final Map<String, DateTime> _lastCheckTimes = {};
  
  /// 注册数据源
  void registerDataSource(UniversalBookDataSource dataSource) {
    _dataSources.add(dataSource);
  }
  
  /// 注册多个数据源
  void registerDataSources(List<UniversalBookDataSource> dataSources) {
    _dataSources.addAll(dataSources);
  }
  
  /// 获取所有数据源
  List<UniversalBookDataSource> getAllDataSources() {
    return List.unmodifiable(_dataSources);
  }
  
  /// 获取健康的数据源
  Future<List<UniversalBookDataSource>> getHealthyDataSources() async {
    final healthy = <UniversalBookDataSource>[];
    
    for (final source in _dataSources) {
      final status = await checkDataSourceHealth(source);
      if (status == DataSourceHealthStatus.healthy) {
        healthy.add(source);
      }
    }
    
    return healthy;
  }
  
  /// 检查数据源健康状态
  Future<DataSourceHealthStatus> checkDataSourceHealth(UniversalBookDataSource source) async {
    final now = DateTime.now();
    final lastCheck = _lastCheckTimes[source.sourceName];
    
    // 如果最近检查过，直接返回缓存的状态
    if (lastCheck != null && now.difference(lastCheck).inMinutes < 5) {
      return _healthStatuses[source.sourceName] ?? DataSourceHealthStatus.unknown;
    }
    
    try {
      final status = await source.checkHealthStatus();
      _healthStatuses[source.sourceName] = status;
      _lastCheckTimes[source.sourceName] = now;
      return status;
    } catch (e) {
      _healthStatuses[source.sourceName] = DataSourceHealthStatus.unavailable;
      _lastCheckTimes[source.sourceName] = now;
      return DataSourceHealthStatus.unavailable;
    }
  }
  
  /// 全网搜索
  Future<List<Book>> searchAllSources(String keyword) async {
    final healthySources = await getHealthyDataSources();
    if (healthySources.isEmpty) {
      return [];
    }
    
    final futures = healthySources.map((source) async {
      try {
        return await source.searchRemote(keyword);
      } catch (e) {
        print('DataSource ${source.sourceName} search error: $e');
        return <Book>[];
      }
    });
    
    final results = await Future.wait(futures);
    final merged = <String, Book>{};
    
    for (final books in results) {
      for (final book in books) {
        // 去重，保留第一个找到的版本
        merged.putIfAbsent(book.id, () => book);
      }
    }
    
    return merged.values.toList();
  }
  
  /// 高级全网搜索
  Future<List<Book>> advancedSearchAllSources({
    required String keyword,
    SearchType searchType = SearchType.title,
    String? author,
    String? category,
  }) async {
    final healthySources = await getHealthyDataSources();
    if (healthySources.isEmpty) {
      return [];
    }
    
    final futures = healthySources.map((source) async {
      try {
        return await source.advancedSearch(
          keyword: keyword,
          searchType: searchType,
          author: author,
          category: category,
        );
      } catch (e) {
        print('DataSource ${source.sourceName} advanced search error: $e');
        return <Book>[];
      }
    });
    
    final results = await Future.wait(futures);
    final merged = <String, Book>{};
    
    for (final books in results) {
      for (final book in books) {
        merged.putIfAbsent(book.id, () => book);
      }
    }
    
    return merged.values.toList();
  }
  
  /// 获取书籍详情（尝试多个数据源）
  Future<(Book, List<Chapter>)?> fetchBookFromAnySource(String bookId) async {
    final healthySources = await getHealthyDataSources();
    if (healthySources.isEmpty) {
      return null;
    }
    
    for (final source in healthySources) {
      try {
        final result = await source.fetchPublicDomainBook(bookId);
        if (result.$2.isNotEmpty) {
          return result;
        }
      } catch (e) {
        print('DataSource ${source.sourceName} fetch error: $e');
        continue;
      }
    }
    
    return null;
  }
  
  /// 批量获取章节内容（从多个数据源）
  Future<Map<String, String>> batchFetchChapterContent(
    List<String> chapterIds, 
    String novelId,
  ) async {
    final healthySources = await getHealthyDataSources();
    if (healthySources.isEmpty) {
      return {};
    }
    
    final results = <String, String>{};
    final remainingChapterIds = List.from(chapterIds);
    
    for (final source in healthySources) {
      if (remainingChapterIds.isEmpty) break;
      
      try {
        final batchResult = await source.batchFetchChapterContent(
          remainingChapterIds.cast<String>(),
          novelId,
        );
        
        results.addAll(batchResult);
        remainingChapterIds.removeWhere(batchResult.containsKey);
      } catch (e) {
        print('DataSource ${source.sourceName} batch fetch error: $e');
        continue;
      }
    }
    
    return results;
  }
  
  /// 清除所有数据源的缓存
  Future<void> clearAllCaches() async {
    for (final source in _dataSources) {
      try {
        await source.clearCache();
      } catch (e) {
        print('DataSource ${source.sourceName} clear cache error: $e');
      }
    }
  }
  
  /// 刷新所有数据源的健康状态
  Future<void> refreshAllHealthStatuses() async {
    for (final source in _dataSources) {
      await checkDataSourceHealth(source);
    }
  }
  
  /// 获取相关推荐书籍
  Future<List<Book>> getRelatedBooks(String novelId) async {
    final healthySources = await getHealthyDataSources();
    if (healthySources.isEmpty) {
      return [];
    }
    
    final results = <Book>{};
    
    for (final source in healthySources) {
      try {
        final relatedBooks = await source.getRelatedBooks(novelId);
        results.addAll(relatedBooks);
      } catch (e) {
        print('DataSource ${source.sourceName} get related books error: $e');
        continue;
      }
    }
    
    return results.toList();
  }
}
