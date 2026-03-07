import '../../models/book.dart';
import '../../models/chapter.dart';
import 'novel_book_data_source.dart';

/// 通用书籍数据源接口，扩展自NovelBookDataSource
/// 用于实现各种书籍网站的数据源，支持全网搜索
abstract class UniversalBookDataSource extends NovelBookDataSource {
  /// 数据源名称
  String get sourceName;
  
  /// 数据源基础URL
  String get baseUrl;
  
  /// 支持的搜索类型
  List<SearchType> get supportedSearchTypes;
  
  /// 高级搜索
  Future<List<Book>> advancedSearch({
    required String keyword,
    SearchType searchType = SearchType.title,
    String? author,
    String? category,
  });
  
  /// 批量获取章节内容
  Future<Map<String, String>> batchFetchChapterContent(
    List<String> chapterIds, 
    String novelId,
  );
  
  /// 获取相关推荐书籍
  Future<List<Book>> getRelatedBooks(String novelId);
  
  /// 检查数据源健康状态
  Future<DataSourceHealthStatus> checkHealthStatus();
  
  /// 清除数据源缓存
  Future<void> clearCache();
}

/// 搜索类型枚举
enum SearchType {
  title,  // 按标题搜索
  author, // 按作者搜索
  isbn,   // 按ISBN搜索
  keyword, // 按关键词搜索
}

/// 数据源健康状态
enum DataSourceHealthStatus {
  healthy,      // 健康
  degraded,     // 性能下降
  unavailable,  // 不可用
  unknown,      // 未知
}

/// 数据源配置类
class DataSourceConfig {
  const DataSourceConfig({
    required this.enabled,
    this.timeout = const Duration(seconds: 30),
    this.retryCount = 3,
    this.requestInterval = const Duration(milliseconds: 500),
    this.userAgents = const [],
    this.proxies = const [],
  });
  
  /// 是否启用该数据源
  final bool enabled;
  
  /// 请求超时时间
  final Duration timeout;
  
  /// 重试次数
  final int retryCount;
  
  /// 请求间隔
  final Duration requestInterval;
  
  /// 用户代理列表
  final List<String> userAgents;
  
  /// 代理列表
  final List<String> proxies;
}
