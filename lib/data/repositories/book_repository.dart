import '../datasources/local_assets/book_asset_data_source.dart';
import '../datasources/local_storage/local_book_data_source.dart';
import '../datasources/remote/remote_book_data_source.dart';
import '../models/book.dart';
import '../models/chapter.dart';
import '../../core/cache/cache_manager.dart';
import '../utils/content_processor.dart';

class BookRepository {
  BookRepository({
    BookAssetDataSource? assetDataSource,
    RemoteBookDataSource? remoteDataSource,
    LocalBookDataSource? localBookDataSource,
  })  : _assetDataSource = assetDataSource ?? const BookAssetDataSource(),
        _remoteDataSource = remoteDataSource,
        _localBookDataSource = localBookDataSource ?? LocalBookDataSource(),
        _cacheManager = CacheManager(),
        _contentProcessor = ContentProcessor(null);

  final BookAssetDataSource _assetDataSource;
  final RemoteBookDataSource? _remoteDataSource;
  final LocalBookDataSource _localBookDataSource;
  final CacheManager _cacheManager;
  final ContentProcessor _contentProcessor;

  List<Book>? _cachedBooks;
  final Map<String, List<Chapter>> _cachedChapters = {};

  Future<List<Book>> getAllBooks() async {
    if (_cachedBooks == null) {
      final assets = await _assetDataSource.loadCatalog();
      final locals = await _localBookDataSource.loadAll();
      _cachedBooks = <Book>[
        ...assets,
        ...locals,
      ];
    }
    return _cachedBooks!;
  }

  Future<List<Chapter>> getChaptersForBook(Book book) async {
    // 首先检查内存缓存
    final existing = _cachedChapters[book.id];
    if (existing != null) {
      return existing;
    }

    // 检查本地缓存
    final cachedChapters = await _cacheManager.getCachedChapterList(book.id);
    if (cachedChapters != null) {
      _cachedChapters[book.id] = cachedChapters;
      return cachedChapters;
    }

    List<Chapter> chapters = const [];

    if (book.sourceType == BookSourceType.asset) {
      final detailAssetPath = book.detailAsset ?? book.toJson()['detailAsset'] as String?;
      if (detailAssetPath == null) {
        return const [];
      }

      final result = await _assetDataSource.loadBookDetail(detailAssetPath);
      chapters = result.$2;
      _mergeBook(result.$1);
    } else if (book.sourceType == BookSourceType.localFile) {
      final result = await _localBookDataSource.loadBookDetail(book);
      chapters = result.$2;
      _mergeBook(result.$1);
    } else if (book.sourceType == BookSourceType.publicDomainApi) {
      final remoteSource = _remoteDataSource;
      final apiId = book.remoteApiId;
      if (remoteSource == null || apiId == null || apiId.isEmpty) {
        return const [];
      }
      final result = await remoteSource.fetchPublicDomainBook(apiId);
      chapters = result.$2;
      _mergeBook(result.$1);
    }

    // 缓存章节列表
    if (chapters.isNotEmpty) {
      await _cacheManager.cacheChapterList(book.id, chapters);
      _cachedChapters[book.id] = chapters;
    }

    return chapters;
  }

  Future<List<Book>> searchBooks(String keyword) async {
    // 暂时禁用缓存，以便测试ContentProcessor
    // final cachedResults = await _cacheManager.getCachedSearchResults(keyword);
    // if (cachedResults != null) {
    //   return cachedResults;
    // }

    print('BookRepository: Searching for keyword: $keyword');
    // 1. 尝试使用ContentProcessor智能获取书籍内容
    try {
      print('BookRepository: Step 1: Using ContentProcessor to search for $keyword');
      final (book, chapters) = await _contentProcessor.smartFetchBook(keyword);
      print('BookRepository: ContentProcessor found book: ${book.title}');
      
      // 缓存书籍和章节
      await _cacheManager.cacheBook(book);
      await _cacheManager.cacheChapterList(book.id, chapters);
      
      // 添加到缓存列表
      final all = await getAllBooks();
      final existingIds = all.map((b) => b.id).toSet();
      if (!existingIds.contains(book.id)) {
        _cachedBooks = [...all, book];
      }
      
      // 缓存搜索结果
      await _cacheManager.cacheSearchResults(keyword, [book]);
      
      print('BookRepository: Returning book from ContentProcessor: ${book.title}');
      return [book];
    } catch (e) {
      print('BookRepository: ContentProcessor search failed: $e');
      // 继续使用传统搜索
    }

    // 2. 传统搜索作为回退
    final all = await getAllBooks();
    if (keyword.trim().isEmpty) {
      return all;
    }
    final lower = keyword.toLowerCase();
    final localMatches = all.where((book) {
      return book.title.toLowerCase().contains(lower) ||
          book.author.toLowerCase().contains(lower) ||
          book.category.toLowerCase().contains(lower) ||
          book.tags.any((t) => t.toLowerCase().contains(lower));
    }).toList();

    final remoteSource = _remoteDataSource;
    if (remoteSource == null) {
      // 缓存本地搜索结果
      await _cacheManager.cacheSearchResults(keyword, localMatches);
      return localMatches;
    }

    List<Book> remote = const [];
    try {
      remote = await remoteSource.searchRemote(keyword);
    } catch (e) {
      // 忽略远程搜索错误，优先保证本地搜索可用。
      // ignore: avoid_print
      print('Remote book search failed: $e');
      // 缓存本地搜索结果
      await _cacheManager.cacheSearchResults(keyword, localMatches);
      return localMatches;
    }
    final existingIds = localMatches.map((b) => b.id).toSet();
    final merged = [
      ...localMatches,
      ...remote.where((b) => !existingIds.contains(b.id)),
    ];
    
    // 优化搜索结果排序
    merged.sort((a, b) {
      // 1. 首先按匹配度排序（标题完全匹配优先）
      final aTitleMatch = a.title.toLowerCase() == keyword.toLowerCase() ? 2 : a.title.toLowerCase().contains(keyword.toLowerCase()) ? 1 : 0;
      final bTitleMatch = b.title.toLowerCase() == keyword.toLowerCase() ? 2 : b.title.toLowerCase().contains(keyword.toLowerCase()) ? 1 : 0;
      if (aTitleMatch != bTitleMatch) {
        return bTitleMatch.compareTo(aTitleMatch);
      }
      
      // 2. 然后按热度排序
      final aHeat = a.heatScore ?? 0;
      final bHeat = b.heatScore ?? 0;
      if (aHeat != bHeat) {
        return bHeat.compareTo(aHeat);
      }
      
      // 3. 最后按来源排序（本地书籍优先）
      if (a.sourceType != b.sourceType) {
        if (a.sourceType == BookSourceType.localFile || a.sourceType == BookSourceType.asset) {
          return -1;
        }
        if (b.sourceType == BookSourceType.localFile || b.sourceType == BookSourceType.asset) {
          return 1;
        }
      }
      
      return 0;
    });
    
    // 缓存搜索结果
    await _cacheManager.cacheSearchResults(keyword, merged);
    
    return merged;
  }

  /// 获取章节内容（带缓存）
  Future<String> getChapterContent(String chapterId, Book book) async {
    // 首先检查缓存
    final cachedContent = await _cacheManager.getCachedChapterContent(chapterId);
    if (cachedContent != null) {
      return cachedContent;
    }

    // 这里可以实现从网络获取章节内容的逻辑
    // 为了示例，这里返回空字符串
    final content = '';

    // 缓存章节内容
    await _cacheManager.cacheChapterContent(chapterId, content);
    
    return content;
  }

  void _mergeBook(Book updated) {
    final list = _cachedBooks;
    if (list == null) {
      return;
    }
    final index = list.indexWhere((b) => b.id == updated.id);
    if (index == -1) {
      return;
    }
    list[index] = list[index].copyWith(
      title: updated.title,
      author: updated.author,
      category: updated.category,
      coverAsset: updated.coverAsset,
      tags: updated.tags,
      wordCount: updated.wordCount,
      status: updated.status,
      intro: updated.intro,
      sourceType: updated.sourceType,
      heatScore: updated.heatScore,
      localFilePath: updated.localFilePath,
    );

    // 缓存书籍信息
    _cacheManager.cacheBook(list[index]);
  }

  /// 从文件系统导入一本本地 TXT 书籍。
  ///
  /// 导入成功后会更新内存缓存，并返回新建的 [Book]。
  Future<Book> addLocalBookFromFile(
    String path, {
    String? title,
    String? author,
  }) async {
    // 确保已有缓存，以资产书库为基础。
    await getAllBooks();
    final book = await _localBookDataSource.addFromFile(
      path: path,
      title: title,
      author: author,
    );
    final current = _cachedBooks ?? <Book>[];
    _cachedBooks = <Book>[...current, book];
    
    // 缓存书籍信息
    await _cacheManager.cacheBook(book);
    
    return book;
  }

  /// 清除缓存，强制下次调用getAllBooks时重新加载书籍
  Future<void> clearCache() async {
    _cachedBooks = null;
    _cachedChapters.clear();
    await _cacheManager.clearAllCache();
  }

  /// 清理过期缓存
  Future<void> cleanExpiredCache() async {
    await _cacheManager.cleanExpiredCache();
  }

  /// 管理缓存大小
  Future<void> manageCache() async {
    await _cacheManager.manageCache();
  }
}
 

