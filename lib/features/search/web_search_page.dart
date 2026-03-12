import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../bookshelf/bookshelf_providers.dart';
import '../../data/models/book.dart';
import 'web_search_service.dart';
import 'web_content_reader.dart';

/// 全网搜索页面
class WebSearchPage extends ConsumerStatefulWidget {
  const WebSearchPage({super.key});

  @override
  ConsumerState<WebSearchPage> createState() => _WebSearchPageState();
}

class _WebSearchPageState extends ConsumerState<WebSearchPage> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _performSearch() {
    final keyword = _searchController.text.trim();
    if (keyword.isNotEmpty) {
      ref.read(searchProvider.notifier).search(keyword);
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('全网搜索'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // 搜索栏
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: '搜索书籍、文章...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(searchProvider.notifier).clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
              onSubmitted: (_) => _performSearch(),
              textInputAction: TextInputAction.search,
            ),
          ),

          // 搜索提示
          if (!searchState.isLoading && 
              searchState.results.isEmpty && 
              searchState.currentKeyword == null)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search,
                      size: 80,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '输入关键词搜索全网资源',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '支持搜索文章、小说、博客等内容',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 加载中
          if (searchState.isLoading)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('正在搜索全网资源...'),
                  ],
                ),
              ),
            ),

          // 错误提示
          if (searchState.error != null)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red.shade300,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      searchState.error!,
                      style: TextStyle(color: Colors.red.shade600),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _performSearch,
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
            ),

          // 搜索结果列表
          if (!searchState.isLoading && searchState.results.isNotEmpty)
            Expanded(
              child: ListView.builder(
                itemCount: searchState.results.length,
                itemBuilder: (context, index) {
                  final book = searchState.results[index];
                  return _SearchResultCard(
                    book: book,
                    onTap: () => _openBook(context, book),
                    onAddToShelf: () => _addToBookshelf(context, book),
                  );
                },
              ),
            ),

          // 无结果提示
          if (!searchState.isLoading && 
              searchState.results.isEmpty && 
              searchState.currentKeyword != null &&
              searchState.error == null)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.find_in_page,
                      size: 64,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '未找到 "${searchState.currentKeyword}" 相关结果',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '试试其他关键词或检查网络连接',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _openBook(BuildContext context, book) async {
    // 显示加载提示
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('正在获取内容...'),
          ],
        ),
      ),
    );

    try {
      final service = ref.read(webSearchServiceProvider);
      final result = await service.fetchBookWithChapters(book.id);

      if (mounted) Navigator.pop(context);

        if (result != null) {
        final (fetchedBook, chapters) = result;
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => WebContentReader(
                book: fetchedBook.copyWith(
                  id: book.id,
                  title: book.title,
                ),
                chapters: chapters,
              ),
            ),
          );
        }
      } else {
        // 无法获取内容，尝试用外部链接打开
        if (mounted) {
          _showCannotFetchDialog(context, book);
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('获取内容失败: $e')),
        );
      }
    }
  }

  void _showCannotFetchDialog(BuildContext context, book) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('无法直接获取内容'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('该网站需要特殊处理，您可以：'),
            const SizedBox(height: 16),
            if (book.externalUrl != null)
              Text(
                '源地址: ${book.externalUrl}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          if (book.externalUrl != null)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // TODO: 使用 url_launcher 打开外部链接
              },
              child: const Text('在浏览器中打开'),
            ),
        ],
      ),
    );
  }

  void _addToBookshelf(BuildContext context, dynamic book) {
    ref.read(bookshelfItemsProvider.notifier).toggle(book as Book);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已添加《${book.title}》到书架')),
    );
  }
}

/// 搜索结果卡片
class _SearchResultCard extends StatelessWidget {
  final Book book;
  final VoidCallback onTap;
  final VoidCallback onAddToShelf;

  const _SearchResultCard({
    required this.book,
    required this.onTap,
    required this.onAddToShelf,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 封面占位
              Container(
                width: 60,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.article, color: Colors.grey),
              ),
              const SizedBox(width: 12),

              // 内容
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '来源: ${book.author ?? '网络'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    if (book.intro.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        book.intro,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              // 操作按钮
              Column(
                children: [
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: onAddToShelf,
                    tooltip: '加入书架',
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
