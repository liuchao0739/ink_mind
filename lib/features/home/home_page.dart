import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/book.dart';
import '../../data/repositories/book_repository.dart';
import '../../data/datasources/remote/gutendex_book_data_source.dart';
import '../../data/datasources/remote/composite_remote_book_data_source.dart';
import '../../data/datasources/remote/ctext_book_data_source.dart';
import '../bookshelf/bookshelf_page.dart';
import '../bookshelf/bookshelf_providers.dart';
import '../reader/reader_page.dart';
import '../ai/recommendation/recommendation_engine.dart';
import '../stats/stats_page.dart';
import '../../data/datasources/local_storage/hive_search_history_data_source.dart';

final bookRepositoryProvider = Provider<BookRepository>((ref) {
  print('HomePage: Creating BookRepository');
  // 使用真实数据源
  final remote = CompositeRemoteBookDataSource(
    sources: [
      GutendexBookDataSource(),  // 英文公版书
      CtextDataSource(),         // 中文古籍 (ctext.org)
    ],
  );
  final repo = BookRepository(remoteDataSource: remote);
  print('HomePage: BookRepository created');
  return repo;
});

final _searchKeywordProvider = StateProvider<String>((ref) => '');

final _searchHistoryProvider = FutureProvider<List<String>>((ref) async {
  final dataSource = SearchHistoryDataSource();
  return dataSource.getHistory();
});

final _searchSuggestionsProvider = FutureProvider<List<String>>((ref) async {
  final keyword = ref.watch(_searchKeywordProvider);
  if (keyword.isEmpty) return [];
  
  // 这里可以实现更复杂的搜索建议逻辑
  // 目前使用简单的模拟数据
  final suggestions = [
    '$keyword 小说',
    '$keyword 最新',
    '$keyword 完结',
    '${keyword}传',
    '${keyword}记',
  ];
  return suggestions;
});

final _bookListProvider = FutureProvider<List<Book>>((ref) async {
  final repo = ref.watch(bookRepositoryProvider);
  final keyword = ref.watch(_searchKeywordProvider);
  print('HomePage: Searching for keyword: $keyword');
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: '搜索书名获取小说（如 斗破苍穹、斗罗大陆）',
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    suffixIcon: ref.watch(_bookListProvider).isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : IconButton(
                            icon: const Icon(Icons.search),
                            onPressed: () async {
                              final keyword = ref.read(_searchKeywordProvider.notifier).state;
                              print('HomePage: Search button pressed with keyword: $keyword');
                              if (keyword.trim().isNotEmpty) {
                                // 添加到搜索历史
                                final dataSource = SearchHistoryDataSource();
                                await dataSource.addHistory(keyword);
                                // 刷新历史记录
                                ref.refresh(_searchHistoryProvider);
                                // 触发搜索
                                print('HomePage: Refreshing book list provider');
                                ref.refresh(_bookListProvider);
                              }
                            },
                          ),
                  ),
                  onChanged: (value) =>
                      ref.read(_searchKeywordProvider.notifier).state = value,
                  onSubmitted: (value) async {
                    if (value.trim().isNotEmpty) {
                      print('HomePage: Search submitted with keyword: $value');
                      // 添加到搜索历史
                      final dataSource = SearchHistoryDataSource();
                      await dataSource.addHistory(value);
                      // 刷新历史记录
                      ref.refresh(_searchHistoryProvider);
                      // 触发搜索
                      print('HomePage: Refreshing book list provider');
                      ref.refresh(_bookListProvider);
                    }
                  },
                ),
                const SizedBox(height: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ref.watch(_searchHistoryProvider).when(
                      data: (history) {
                        if (history.isEmpty) return Container();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '搜索历史',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    final dataSource = SearchHistoryDataSource();
                                    await dataSource.clearHistory();
                                    ref.refresh(_searchHistoryProvider);
                                  },
                                  child: Text(
                                    '清除',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: Colors.blue),
                                  ),
                                ),
                              ],
                            ),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: history.map((keyword) {
                                return InkWell(
                                  onTap: () {
                                    ref.read(_searchKeywordProvider.notifier).state = keyword;
                                  },
                                  child: Chip(
                                    label: Text(keyword),
                                    onDeleted: () async {
                                      final dataSource = SearchHistoryDataSource();
                                      await dataSource.removeHistory(keyword);
                                      ref.refresh(_searchHistoryProvider);
                                    },
                                  ),
                                );
                              }).toList() as List<Widget>,
                            ),
                            const SizedBox(height: 8),
                          ],
                        );
                      },
                      loading: () => Container(),
                      error: (error, stack) => Container(),
                    ),
                    ref.watch(_searchSuggestionsProvider).when(
                      data: (suggestions) {
                        if (suggestions.isEmpty) return Container();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '搜索建议',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: suggestions.map((suggestion) {
                                return InkWell(
                                  onTap: () {
                                    ref.read(_searchKeywordProvider.notifier).state = suggestion;
                                  },
                                  child: Chip(
                                    label: Text(suggestion),
                                  ),
                                );
                              }).toList() as List<Widget>,
                            ),
                          ],
                        );
                      },
                      loading: () => Container(),
                      error: (error, stack) => Container(),
                    ),
                  ],
                ),
              ],
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
                        '搜索书名获取小说\n（如 斗破苍穹、斗罗大陆、pride）',
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
                                    color: Colors.grey[800],
                                    border: Border.all(
                                      color: Colors.grey[600]!,
                                      width: 1,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        book.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        book.author,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.grey[300],
                                          fontSize: 14,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        book.category,
                                        style: TextStyle(
                                          color: Colors.grey[400],
                                          fontSize: 12,
                                        ),
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
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        elevation: 2,
                        color: Colors.grey[800],
                        child: ListTile(
                          leading: Container(
                            width: 48,
                            height: 64,
                            decoration: BoxDecoration(
                              color: Colors.grey[700],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Icon(
                              Icons.menu_book_outlined, 
                              size: 24,
                              color: Colors.white,
                            ),
                            alignment: Alignment.center,
                          ),
                          title: Text(
                            book.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                '${book.author} · ${book.category}',
                                style: TextStyle(
                                  color: Colors.grey[300],
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Wrap(
                                spacing: 8,
                                runSpacing: 2,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[700],
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      _sourceLabel(book.sourceType),
                                      style: TextStyle(
                                        color: Colors.grey[300],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  if (book.heatScore != null && book.heatScore! > 0) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[700],
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.local_fire_department_outlined, 
                                            size: 12, 
                                            color: Colors.orange,
                                          ),
                                          const SizedBox(width: 2),
                                          Text(
                                            '热度 ${book.heatScore}',
                                            style: TextStyle(
                                              color: Colors.grey[300],
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
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
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 16),
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
                                icon: const Icon(
                                  Icons.menu_book,
                                  size: 20,
                                  color: Colors.white,
                                ),
                                tooltip: '开始阅读',
                              ),
                              IconButton(
                                onPressed: () async {
                                  // 使用BookshelfNotifier的toggle方法，确保状态更新的一致性
                                  final bookshelfNotifier = ref.read(bookshelfItemsProvider.notifier);
                                  await bookshelfNotifier.toggle(book);
                                },
                                icon: Icon(
                                  isOnShelf
                                      ? Icons.bookmark
                                      : Icons.bookmark_border,
                                  size: 20,
                                  color: isOnShelf ? Colors.yellow : Colors.white,
                                ),
                                tooltip: isOnShelf ? '从书架移除' : '加入书架',
                              ),
                            ],
                          ),
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


