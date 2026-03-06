import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/book.dart';
import '../../data/repositories/book_repository.dart';
import '../../data/datasources/remote/gutendex_book_data_source.dart';
import '../../data/datasources/remote/composite_remote_book_data_source.dart';
import '../bookshelf/bookshelf_page.dart';
import '../bookshelf/bookshelf_providers.dart';
import '../reader/reader_page.dart';
import '../ai/recommendation/recommendation_engine.dart';
import '../stats/stats_page.dart';

final bookRepositoryProvider = Provider<BookRepository>((ref) {
  final remote = CompositeRemoteBookDataSource(
    sources: [
      GutendexBookDataSource(),
    ],
  );
  return BookRepository(remoteDataSource: remote);
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
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_rounded),
            SizedBox(width: 8),
            Text('墨智 · InkMind'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () async {
              try {
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['txt'],
                );
                if (result == null || result.files.isEmpty) {
                  return;
                }
                final path = result.files.single.path;
                if (path == null || path.isEmpty) {
                  return;
                }
                final repo = ref.read(bookRepositoryProvider);
                final book = await repo.addLocalBookFromFile(path);
                // 刷新列表，展示新导入的书。
                // ignore: unused_result
                ref.refresh(_bookListProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('已导入本地书籍：${book.title}'),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('导入失败：$e'),
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.file_open_outlined),
            tooltip: '导入本地 TXT',
          ),
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
                hintText: '搜索书名获取完整公版书（如 pride、sherlock）',
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
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        '搜索书名获取完整公版书\n（如 pride、sherlock、adventure）',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
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
                        subtitle: Text(
                          '${book.author} · ${book.category} · ${_sourceLabel(book.sourceType)}',
                        ),
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
                              onPressed: () async {
                                if (book.sourceType ==
                                        BookSourceType.copyrightLink &&
                                    book.externalUrl != null &&
                                    book.externalUrl!.isNotEmpty) {
                                  try {
                                    final uri = Uri.parse(book.externalUrl!);
                                    await launchUrl(
                                      uri,
                                      mode: LaunchMode.externalApplication,
                                    );
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content:
                                            Text('打开链接失败：$e'),
                                      ),
                                    );
                                  }
                                } else {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => ReaderPage(book: book),
                                    ),
                                  );
                                }
                              },
                              icon: Icon(
                                book.sourceType ==
                                        BookSourceType.copyrightLink
                                    ? Icons.open_in_new
                                    : Icons.menu_book,
                              ),
                              tooltip: book.sourceType ==
                                      BookSourceType.copyrightLink
                                  ? '前往官方阅读'
                                  : '开始阅读',
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
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '加载书库失败：$error',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () {
                            // 触发重新加载，FutureProvider 会自动重建。
                            // ignore: unused_result
                            ref.refresh(_bookListProvider);
                          },
                          child: const Text('重试'),
                        ),
                      ],
                    ),
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

String _sourceLabel(BookSourceType type) {
  switch (type) {
    case BookSourceType.asset:
      return '本地示例';
    case BookSourceType.localFile:
      return '本地导入';
    case BookSourceType.publicDomainApi:
      return '公版在线';
    case BookSourceType.copyrightLink:
      return '正版链接';
  }
}


