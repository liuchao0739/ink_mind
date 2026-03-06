import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/book.dart';
import '../../../data/models/bookshelf_item.dart';
import '../../bookshelf/bookshelf_providers.dart';
import '../../home/home_page.dart';

class RecommendationEngine {
  const RecommendationEngine({
    required this.books,
    required this.shelfItems,
  });

  final List<Book> books;
  final List<BookshelfItem> shelfItems;

  List<Book> recommendForYou() {
    if (books.isEmpty) {
      return const [];
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final categoryScores = <String, double>{};

    for (final item in shelfItems) {
      final book = books.firstWhere(
        (b) => b.id == item.bookId,
        orElse: () => const Book(
          id: '',
          title: '',
          author: '',
          category: '',
        ),
      );
      if (book.id.isEmpty) continue;

      final lastRead = item.lastReadAtMillis ?? item.addedAtMillis;
      final hoursAgo = (now - lastRead) / (1000 * 60 * 60);
      final timeWeight = hoursAgo < 24
          ? 3
          : hoursAgo < 72
              ? 2
              : 1;
      categoryScores.update(
        book.category,
        (value) => value + timeWeight,
        ifAbsent: () => timeWeight.toDouble(),
      );
      for (final tag in book.tags) {
        categoryScores.update(
          tag,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
      }
    }

    return [...books]
      ..sort((a, b) {
        final aBase = a.heatScore.toDouble();
        final bBase = b.heatScore.toDouble();
        final aScore = aBase +
            (categoryScores[a.category] ?? 0) * 3 +
            a.tags.fold<double>(
              0,
              (prev, tag) => prev + (categoryScores[tag] ?? 0),
            );
        final bScore = bBase +
            (categoryScores[b.category] ?? 0) * 3 +
            b.tags.fold<double>(
              0,
              (prev, tag) => prev + (categoryScores[tag] ?? 0),
            );
        return bScore.compareTo(aScore);
      });
  }
}

final recommendationProvider =
    FutureProvider<List<Book>>((ref) async {
  final bookRepo = ref.watch(bookRepositoryProvider);
  final shelfRepo = ref.watch(bookshelfRepositoryProvider);
  final books = await bookRepo.getAllBooks();
  final shelfWithBooks = await shelfRepo.getBookshelfWithBooks();
  final shelfItems = shelfWithBooks.map((e) => e.$1).toList();

  final engine = RecommendationEngine(
    books: books,
    shelfItems: shelfItems,
  );
  return engine.recommendForYou();
});

