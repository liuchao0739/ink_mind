import '../datasources/local_assets/book_asset_data_source.dart';
import '../datasources/local_storage/local_book_data_source.dart';
import '../datasources/remote/remote_book_data_source.dart';
import '../models/book.dart';
import '../models/chapter.dart';

class BookRepository {
  BookRepository({
    BookAssetDataSource? assetDataSource,
    RemoteBookDataSource? remoteDataSource,
    LocalBookDataSource? localBookDataSource,
  })  : _assetDataSource = assetDataSource ?? const BookAssetDataSource(),
        _remoteDataSource = remoteDataSource,
        _localBookDataSource = localBookDataSource ?? LocalBookDataSource();

  final BookAssetDataSource _assetDataSource;
  final RemoteBookDataSource? _remoteDataSource;
  final LocalBookDataSource _localBookDataSource;

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
    final existing = _cachedChapters[book.id];
    if (existing != null) {
      return existing;
    }

    if (book.sourceType == BookSourceType.asset) {
      final detailAssetPath = book.detailAsset ?? book.toJson()['detailAsset'] as String?;
      if (detailAssetPath == null) {
        return const [];
      }

      final result = await _assetDataSource.loadBookDetail(detailAssetPath);
      _cachedChapters[book.id] = result.$2;
      _mergeBook(result.$1);
      return result.$2;
    }

    if (book.sourceType == BookSourceType.localFile) {
      final result = await _localBookDataSource.loadBookDetail(book);
      _cachedChapters[book.id] = result.$2;
      _mergeBook(result.$1);
      return result.$2;
    }

    if (book.sourceType == BookSourceType.publicDomainApi) {
      final remoteSource = _remoteDataSource;
      final apiId = book.remoteApiId;
      if (remoteSource == null || apiId == null || apiId.isEmpty) {
        return const [];
      }
      final result = await remoteSource.fetchPublicDomainBook(apiId);
      _cachedChapters[book.id] = result.$2;
      _mergeBook(result.$1);
      return result.$2;
    }

    return const [];
  }

  Future<List<Book>> searchBooks(String keyword) async {
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
      return localMatches;
    }

    List<Book> remote = const [];
    try {
      remote = await remoteSource.searchRemote(keyword);
    } catch (e) {
      // 忽略远程搜索错误，优先保证本地搜索可用。
      // ignore: avoid_print
      print('Remote book search failed: $e');
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
    
    return merged;
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
    return book;
  }

  /// 清除缓存，强制下次调用getAllBooks时重新加载书籍
  void clearCache() {
    _cachedBooks = null;
  }
} 

