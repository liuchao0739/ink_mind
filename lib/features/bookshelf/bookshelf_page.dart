import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bookshelf_providers.dart';

class BookshelfPage extends ConsumerWidget {
  const BookshelfPage({super.key});

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
              child: Text('书架为空，去书城添加几本喜欢的书吧～'),
            );
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final (shelfItem, book) = items[index];
              return ListTile(
                leading: const Icon(Icons.menu_book),
                title: Text(book.title),
                subtitle: Text(
                  '${book.author} · ${book.category}',
                ),
                trailing: Text(
                  shelfItem.lastReadAtMillis == null
                      ? '未阅读'
                      : '在读',
                  style: const TextStyle(color: Colors.blueGrey),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Text('加载书架失败：$error'),
        ),
      ),
    );
  }
}

