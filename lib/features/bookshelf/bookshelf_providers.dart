import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/book.dart';
import '../../data/models/bookshelf_item.dart';
import '../../data/repositories/bookshelf_repository.dart';
import '../home/home_page.dart';

final bookshelfRepositoryProvider = Provider<BookshelfRepository>((ref) {
  final bookRepo = ref.watch(bookRepositoryProvider);
  return BookshelfRepository(bookRepository: bookRepo);
});

final bookshelfItemsProvider =
    StateNotifierProvider<BookshelfNotifier, AsyncValue<List<BookshelfItem>>>(
  (ref) {
    final repo = ref.watch(bookshelfRepositoryProvider);
    final notifier = BookshelfNotifier(repo: repo);
    notifier.load();
    return notifier;
  },
);

class BookshelfNotifier extends StateNotifier<AsyncValue<List<BookshelfItem>>> {
  BookshelfNotifier({required this.repo})
      : super(const AsyncValue.loading());

  final BookshelfRepository repo;

  Future<void> load() async {
    try {
      final items = await repo.load();
      state = AsyncValue.data(items);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> toggle(Book book) async {
    try {
      await repo.toggleBook(book);
      await load();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final bookshelfJoinedProvider =
    FutureProvider<List<(BookshelfItem, Book)>>((ref) async {
  final repo = ref.watch(bookshelfRepositoryProvider);
  return repo.getBookshelfWithBooks();
});

