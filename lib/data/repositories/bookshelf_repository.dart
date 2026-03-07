import 'package:flutter/foundation.dart';

import '../datasources/local_storage/hive_bookshelf_data_source.dart';
import '../datasources/local_storage/local_book_data_source.dart';
import '../models/bookshelf_item.dart';
import '../models/book.dart';
import 'book_repository.dart';

class BookshelfRepository {
  BookshelfRepository({
    HiveBookshelfDataSource? localDataSource,
    BookRepository? bookRepository,
    LocalBookDataSource? localBookDataSource,
  })  : _localDataSource = localDataSource ?? HiveBookshelfDataSource(),
        _bookRepository = bookRepository ?? BookRepository(),
        _localBookDataSource = localBookDataSource ?? LocalBookDataSource();

  final HiveBookshelfDataSource _localDataSource;
  final BookRepository _bookRepository;
  final LocalBookDataSource _localBookDataSource;

  final ValueNotifier<List<BookshelfItem>> _itemsNotifier =
      ValueNotifier<List<BookshelfItem>>(<BookshelfItem>[]);

  ValueListenable<List<BookshelfItem>> get itemsListenable => _itemsNotifier;

  Future<List<BookshelfItem>> load() async {
    final all = await _localDataSource.loadAll();
    _itemsNotifier.value = List.unmodifiable(all);
    return all;
  }

  Future<void> toggleBook(Book book) async {
    final exists = await _localDataSource.exists(book.id);
    if (exists) {
      await _localDataSource.remove(book.id);
    } else {
      // 保存书籍到本地存储，确保书架能够显示完整信息
      final localBooks = await _localBookDataSource.loadAll();
      final bookExists = localBooks.any((b) => b.id == book.id);
      if (!bookExists) {
        // 将远程书籍也存储到本地，确保书架能够显示完整信息
        await _localBookDataSource.saveBook(book);
        // 清除BookRepository的缓存，强制下次调用getAllBooks时重新加载书籍
        _bookRepository.clearCache();
      }
      
      final now = DateTime.now().millisecondsSinceEpoch;
      final item = BookshelfItem(
        bookId: book.id,
        addedAtMillis: now,
        lastReadAtMillis: now,
      );
      await _localDataSource.upsert(item);
    }
    await load();
  }

  Future<void> updateLastRead(String bookId) async {
    final all = await _localDataSource.loadAll();
    final index = all.indexWhere((e) => e.bookId == bookId);
    if (index == -1) {
      return;
    }
    final updated = all[index].copyWith(
      lastReadAtMillis: DateTime.now().millisecondsSinceEpoch,
    );
    await _localDataSource.upsert(updated);
    await load();
  }

  Future<bool> isOnShelf(String bookId) {
    return _localDataSource.exists(bookId);
  }

  Future<List<(BookshelfItem, Book)>> getBookshelfWithBooks() async {
    final items = await _localDataSource.loadAll();
    final result = <(BookshelfItem, Book)>[];
    
    // 从本地存储中加载所有书籍，包括我们之前保存的远程书籍
    final localBooks = await _localBookDataSource.loadAll();
    final localBooksMap = {for (final book in localBooks) book.id: book};
    
    for (final item in items) {
      // 首先尝试从本地存储中获取书籍
      if (localBooksMap.containsKey(item.bookId)) {
        // 找到书籍，添加到结果中
        result.add((item, localBooksMap[item.bookId]!));
      } else {
        // 然后尝试从缓存中获取书籍
        final allBooks = await _bookRepository.getAllBooks();
        final bookIndex = allBooks.indexWhere((b) => b.id == item.bookId);
        
        if (bookIndex != -1) {
          // 找到书籍，添加到结果中
          result.add((item, allBooks[bookIndex]));
        } else {
          // 如果找不到，从书架中移除该项目
          await _localDataSource.remove(item.bookId);
          print('Removed invalid book from bookshelf: ${item.bookId}');
        }
      }
    }
    
    return result;
  }
}

