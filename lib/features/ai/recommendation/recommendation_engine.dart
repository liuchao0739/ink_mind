import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/book.dart' show Book, BookSourceType;
import '../../../data/models/bookshelf_item.dart';
import '../../bookshelf/bookshelf_providers.dart';
import '../../home/home_page.dart';

/// 知名书籍列表 - 用于首页推荐
const List<Map<String, String>> _famousBooks = [
  // 英文经典
  {'title': 'Pride and Prejudice', 'author': 'Jane Austen', 'category': 'Classic Literature'},
  {'title': 'Harry Potter', 'author': 'J.K. Rowling', 'category': 'Fantasy'},
  {'title': 'The Great Gatsby', 'author': 'F. Scott Fitzgerald', 'category': 'Classic Literature'},
  {'title': '1984', 'author': 'George Orwell', 'category': 'Dystopian'},
  {'title': 'To Kill a Mockingbird', 'author': 'Harper Lee', 'category': 'Classic Literature'},
  {'title': 'The Lord of the Rings', 'author': 'J.R.R. Tolkien', 'category': 'Fantasy'},
  // 中文古籍
  {'title': '红楼梦', 'author': '曹雪芹', 'category': '古籍'},
  {'title': '西游记', 'author': '吴承恩', 'category': '古籍'},
  {'title': '三国演义', 'author': '罗贯中', 'category': '古籍'},
  {'title': '水浒传', 'author': '施耐庵', 'category': '古籍'},
  {'title': '论语', 'author': '孔子', 'category': '古籍'},
  {'title': '孟子', 'author': '孟轲', 'category': '古籍'},
];

class RecommendationEngine {
  const RecommendationEngine({
    required this.books,
    required this.shelfItems,
  });

  final List<Book> books;
  final List<BookshelfItem> shelfItems;

  List<Book> recommendForYou() {
    if (books.isEmpty) {
      // 如果没有书籍，返回知名书籍列表
      return _famousBooks.map((b) => Book(
        id: 'famous_${b['title']}',
        title: b['title']!,
        author: b['author']!,
        category: b['category']!,
        sourceType: BookSourceType.publicDomainApi,
        remoteApiId: b['title'],
      )).toList();
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

