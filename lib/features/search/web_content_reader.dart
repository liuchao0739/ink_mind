import 'package:flutter/material.dart';
import '../../data/models/book.dart';
import '../../data/models/chapter.dart';

/// 网页内容阅读器
/// 用于阅读从网页抓取的内容
class WebContentReader extends StatefulWidget {
  const WebContentReader({
    super.key,
    required this.book,
    required this.chapters,
  });

  final Book book;
  final List<Chapter> chapters;

  @override
  State<WebContentReader> createState() => _WebContentReaderState();
}

class _WebContentReaderState extends State<WebContentReader> {
  int _currentChapterIndex = 0;
  double _fontSize = 16.0;
  double _lineHeight = 1.6;

  Chapter get _currentChapter => 
    widget.chapters[_currentChapterIndex];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _currentChapter.title,
          style: const TextStyle(fontSize: 16),
        ),
        backgroundColor: Colors.grey.shade100,
        elevation: 0,
        actions: [
          // 字体大小调整
          PopupMenuButton<double>(
            icon: const Icon(Icons.text_fields),
            tooltip: '字体大小',
            onSelected: (size) => setState(() => _fontSize = size),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 14.0, child: Text('小')),
              const PopupMenuItem(value: 16.0, child: Text('中')),
              const PopupMenuItem(value: 18.0, child: Text('大')),
              const PopupMenuItem(value: 20.0, child: Text('特大')),
            ],
          ),
          // 章节列表
          IconButton(
            icon: const Icon(Icons.list),
            tooltip: '章节列表',
            onPressed: _showChapterList,
          ),
        ],
      ),
      body: Column(
        children: [
          // 进度指示器
          LinearProgressIndicator(
            value: (_currentChapterIndex + 1) / widget.chapters.length,
            backgroundColor: Colors.grey.shade200,
          ),
          
          // 内容区域
          Expanded(
            child: PageView.builder(
              controller: PageController(initialPage: _currentChapterIndex),
              onPageChanged: (index) {
                setState(() => _currentChapterIndex = index);
              },
              itemCount: widget.chapters.length,
              itemBuilder: (context, index) {
                return _buildContentPage(widget.chapters[index]);
              },
            ),
          ),
          
          // 底部导航
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              border: Border(
                top: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 上一章
                  TextButton.icon(
                    onPressed: _currentChapterIndex > 0
                        ? () => _goToChapter(_currentChapterIndex - 1)
                        : null,
                    icon: const Icon(Icons.arrow_back_ios, size: 16),
                    label: const Text('上一章'),
                  ),
                  
                  // 章节进度
                  Text(
                    '${_currentChapterIndex + 1} / ${widget.chapters.length}',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                  
                  // 下一章
                  TextButton.icon(
                    onPressed: _currentChapterIndex < widget.chapters.length - 1
                        ? () => _goToChapter(_currentChapterIndex + 1)
                        : null,
                    icon: const Text('下一章'),
                    label: const Icon(Icons.arrow_forward_ios, size: 16),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentPage(Chapter chapter) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 章节标题
          Text(
            chapter.title,
            style: TextStyle(
              fontSize: _fontSize + 4,
              fontWeight: FontWeight.bold,
              height: _lineHeight,
            ),
          ),
          const SizedBox(height: 24),
          
          // 分隔线
          Divider(color: Colors.grey.shade300),
          const SizedBox(height: 24),
          
          // 正文内容
          SelectableText(
            chapter.content ?? '',
            style: TextStyle(
              fontSize: _fontSize,
              height: _lineHeight,
              color: Colors.grey.shade900,
            ),
          ),
          
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  void _goToChapter(int index) {
    setState(() => _currentChapterIndex = index);
  }

  void _showChapterList() {
    showModalBottomSheet(
      context: context,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '章节列表 (${widget.chapters.length})',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: widget.chapters.length,
                  itemBuilder: (context, index) {
                    final chapter = widget.chapters[index];
                    final isCurrent = index == _currentChapterIndex;
                    return ListTile(
                      selected: isCurrent,
                      selectedTileColor: Colors.blue.shade50,
                      leading: isCurrent
                          ? Icon(Icons.play_arrow, color: Colors.blue.shade700)
                          : Text('${index + 1}'),
                      title: Text(
                        chapter.title,
                        style: TextStyle(
                          fontWeight: isCurrent ? FontWeight.bold : null,
                          color: isCurrent ? Colors.blue.shade700 : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _goToChapter(index);
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
