import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/book.dart';
import '../home/home_page.dart';
import '../reader/reader_page.dart';
import 'bookshelf_providers.dart';

class BookshelfPage extends ConsumerWidget {
  const BookshelfPage({super.key});

  String _sourceLabel(BookSourceType type) {
    switch (type) {
      case BookSourceType.asset:
        return '资产';
      case BookSourceType.localFile:
        return '本地导入';
      case BookSourceType.publicDomainApi:
        return '公版在线';
      case BookSourceType.copyrightLink:
        return '正版链接';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookshelfAsync = ref.watch(bookshelfJoinedProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('书架'),
      ),
      body: bookshelfAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  '书架为空，去书城添加几本喜欢的书吧～',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
              ),
            );
          }
          return ListView(
            children: [
              ...items.map((item) {
                final (shelfItem, book) = item;
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
                            // 从书架移除书籍
                            await ref.read(bookshelfItemsProvider.notifier).toggle(book);
                          },
                          icon: const Icon(
                            Icons.bookmark,
                            size: 20,
                            color: Colors.yellow,
                          ),
                          tooltip: '从书架移除',
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
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              '加载书架失败：$error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

