import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/book.dart';
import '../../data/repositories/book_repository.dart';
import '../bookshelf/bookshelf_page.dart';
import '../bookshelf/bookshelf_providers.dart';
import '../reader/reader_page.dart';
import '../ai/recommendation/recommendation_engine.dart';
import '../stats/stats_page.dart';

final bookRepositoryProvider = Provider<BookRepository>((ref) {
  return BookRepository();
});

final _searchKeywordProvider = StateProvider<String>((ref) => '');

final _bookListProvider = FutureProvider<List<Book>>((ref) async {
  final repo = ref.watch(bookRepositoryProvider);
  final keyword = ref.watch(_searchKeywordProvider);
  if (keyword.isEmpty) {
    return repo.getAllBooks();
  }
  return repo.searchBooks(keyword);
});

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = ref.watch(_bookListProvider);
    final bookshelfState = ref.watch(bookshelfItemsProvider);
    final recommendAsync = ref.watch(recommendationProvider);
    final onShelfIds = bookshelfState.maybeWhen(
      data: (items) => items.map((e) => e.bookId).toSet(),
      orElse: () => <String>{},
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('墨智 · InkMind'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const StatsPage(),
                ),
              );
            },
            icon: const Icon(Icons.insights_outlined),
            tooltip: '阅读画像',
          ),
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const BookshelfPage(),
                ),
              );
            },
            icon: const Icon(Icons.bookmarks_outlined),
            tooltip: '书架',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: '搜索书名 / 作者 / 标签',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) =>
                  ref.read(_searchKeywordProvider.notifier).state = value,
            ),
          ),
          Expanded(
            child: booksAsync.when(
              data: (books) {
                if (books.isEmpty) {
                  return const Center(child: Text('暂时没有可展示的书籍'));
                }
                return ListView(
                  children: [
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '智荐 · 为你推荐',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 160,
                      child: recommendAsync.when(
                        data: (recoBooks) {
                          final display =
                              recoBooks.isEmpty ? books : recoBooks;
                          return ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemBuilder: (context, index) {
                              final book = display[index];
                              return InkWell(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => ReaderPage(book: book),
                                    ),
                                  );
                                },
                                child: Container(
                                  width: 140,
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                  color: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest,
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        book.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        book.author,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                      const Spacer(),
                                      Text(
                                        book.category,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 8),
                            itemCount:
                                display.length > 10 ? 10 : display.length,
                          );
                        },
                        loading: () => const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        error: (error, _) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            '推荐加载失败：$error',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ),
                    ),
                    const Divider(),
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '全部书库',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ),
                    ...books.map((book) {
                      final isOnShelf = onShelfIds.contains(book.id);
                      return ListTile(
                        leading: const Icon(Icons.menu_book_outlined),
                        title: Text(book.title),
                        subtitle: Text('${book.author} · ${book.category}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              book.status == 'completed' ? '完结' : '连载中',
                              style: TextStyle(
                                color: book.status == 'completed'
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => ReaderPage(book: book),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.menu_book),
                              tooltip: '开始阅读',
                            ),
                            IconButton(
                              onPressed: () {
                                ref
                                    .read(bookshelfRepositoryProvider)
                                    .toggleBook(book);
                                ref
                                    .read(bookshelfItemsProvider.notifier)
                                    .load();
                              },
                              icon: Icon(
                                isOnShelf
                                    ? Icons.bookmark
                                    : Icons.bookmark_border,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) {
                return Center(
                  child: Text(
                    '加载书库失败：$error',
                    textAlign: TextAlign.center,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

