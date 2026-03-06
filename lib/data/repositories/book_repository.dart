import '../datasources/local_assets/book_asset_data_source.dart';
import '../models/book.dart';
import '../models/chapter.dart';

class BookRepository {
  BookRepository({
    BookAssetDataSource? assetDataSource,
  }) : _assetDataSource = assetDataSource ?? const BookAssetDataSource();

  final BookAssetDataSource _assetDataSource;

  List<Book>? _cachedBooks;
  final Map<String, List<Chapter>> _cachedChapters = {};

  Future<List<Book>> getAllBooks() async {
    _cachedBooks ??= await _assetDataSource.loadCatalog();
    return _cachedBooks!;
  }

  Future<List<Chapter>> getChaptersForBook(Book book) async {
    final existing = _cachedChapters[book.id];
    if (existing != null) {
      return existing;
    }

    final detailAssetPath = book.toJson()['detailAsset'] as String?;
    if (detailAssetPath == null) {
      return const [];
    }

    final result = await _assetDataSource.loadBookDetail(detailAssetPath);
    _cachedChapters[book.id] = result.$2;
    // Ensure catalog book fields are up to date as well.
    _mergeBook(result.$1);
    return result.$2;
  }

  Future<List<Book>> searchBooks(String keyword) async {
    final all = await getAllBooks();
    if (keyword.trim().isEmpty) {
      return all;
    }
    final lower = keyword.toLowerCase();
    return all.where((book) {
      return book.title.toLowerCase().contains(lower) ||
          book.author.toLowerCase().contains(lower) ||
          book.category.toLowerCase().contains(lower) ||
          book.tags.any((t) => t.toLowerCase().contains(lower));
    }).toList();
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
    );
  }
}

