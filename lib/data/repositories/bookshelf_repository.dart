import 'package:flutter/foundation.dart';

import '../datasources/local_storage/hive_bookshelf_data_source.dart';
import '../models/bookshelf_item.dart';
import '../models/book.dart';
import 'book_repository.dart';

class BookshelfRepository {
  BookshelfRepository({
    HiveBookshelfDataSource? localDataSource,
    BookRepository? bookRepository,
  })  : _localDataSource = localDataSource ?? HiveBookshelfDataSource(),
        _bookRepository = bookRepository ?? BookRepository();

  final HiveBookshelfDataSource _localDataSource;
  final BookRepository _bookRepository;

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
    final allBooks = await _bookRepository.getAllBooks();
    final byId = {for (final b in allBooks) b.id: b};
    final result = <(BookshelfItem, Book)>[];
    for (final item in items) {
      final book = byId[item.bookId];
      if (book != null) {
        result.add((item, book));
      }
    }
    return result;
  }
}

