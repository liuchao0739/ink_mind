import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/book.dart';
import '../../data/models/chapter.dart';
import '../../data/models/reading_progress.dart';
import '../../data/models/ai_highlight.dart';
import '../../data/models/user_preference.dart';
import '../../data/repositories/book_repository.dart';
import '../../data/repositories/reading_repository.dart';
import '../bookshelf/bookshelf_providers.dart';
import '../home/home_page.dart';
import '../ai/highlights/highlight_service.dart';
import '../ai/tts/tts_service.dart';
import '../stats/stats_page.dart';
import 'page_composer.dart';

final readerControllerProvider =
    StateNotifierProvider.family<ReaderController, ReaderState, Book>(
  (ref, book) {
    final bookRepo = ref.watch(bookRepositoryProvider);
    final readingRepo = ReadingRepository();
    final controller = ReaderController(
      book: book,
      bookRepository: bookRepo,
      readingRepository: readingRepo,
    );
    controller.init();
    return controller;
  },
);

class ReaderState {
  const ReaderState({
    required this.book,
    this.chapters = const [],
    this.currentChapterIndex = 0,
    this.currentPageIndex = 0,
    this.pageCountPerChapter = const [],
    this.scrollOffset = 0.0,
    this.preference = const UserPreference(),
    this.isLoading = true,
    this.errorMessage,
  });

  final Book book;
  final List<Chapter> chapters;
  final int currentChapterIndex;
  final int currentPageIndex;
  final List<int> pageCountPerChapter;
  final double scrollOffset;
  final UserPreference preference;
  final bool isLoading;
  final String? errorMessage;

  ReaderState copyWith({
    List<Chapter>? chapters,
    int? currentChapterIndex,
    int? currentPageIndex,
    List<int>? pageCountPerChapter,
    double? scrollOffset,
    UserPreference? preference,
    bool? isLoading,
    String? errorMessage,
  }) {
    return ReaderState(
      book: book,
      chapters: chapters ?? this.chapters,
      currentChapterIndex: currentChapterIndex ?? this.currentChapterIndex,
      currentPageIndex: currentPageIndex ?? this.currentPageIndex,
      pageCountPerChapter: pageCountPerChapter ?? this.pageCountPerChapter,
      scrollOffset: scrollOffset ?? this.scrollOffset,
      preference: preference ?? this.preference,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class ReaderController extends StateNotifier<ReaderState> {
  ReaderController({
    required Book book,
    required BookRepository bookRepository,
    required ReadingRepository readingRepository,
  })  : _bookRepository = bookRepository,
        _readingRepository = readingRepository,
        super(ReaderState(book: book));

  final BookRepository _bookRepository;
  final ReadingRepository _readingRepository;
  final HighlightService _highlightService = HighlightService();
  final TtsService _ttsService = TtsService();

  Future<void> init() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _ttsService.init();
      final chapters = await _bookRepository.getChaptersForBook(state.book);
      final progress = await _readingRepository.getProgress(state.book.id);

      state = state.copyWith(
        chapters: chapters,
        currentChapterIndex: progress?.chapterIndex ?? 0,
        currentPageIndex: progress?.pageIndex ?? 0,
        scrollOffset: progress?.scrollOffset ?? 0.0,
        isLoading: false,
      );
    } catch (e, st) {
      // ignore: avoid_print
      print('Reader init failed for book ${state.book.id}: $e\n$st');
      state = state.copyWith(
        isLoading: false,
        errorMessage: '加载章节失败：$e',
      );
    }
  }

  Future<void> updateScroll(double offset) async {
    state = state.copyWith(scrollOffset: offset);
    await _readingRepository.saveProgress(
      ReadingProgress(
        bookId: state.book.id,
        chapterIndex: state.currentChapterIndex,
        scrollOffset: offset,
        pageIndex: state.currentPageIndex,
        updatedAtMillis: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<void> updatePage({
    required int chapterIndex,
    required int pageIndex,
  }) async {
    state = state.copyWith(
      currentChapterIndex: chapterIndex,
      currentPageIndex: pageIndex,
      scrollOffset: 0.0,
    );
    await _readingRepository.saveProgress(
      ReadingProgress(
        bookId: state.book.id,
        chapterIndex: chapterIndex,
        scrollOffset: 0.0,
        pageIndex: pageIndex,
        updatedAtMillis: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  void updatePageCountForCurrentChapter(int pageCount) {
    if (state.chapters.isEmpty) {
      return;
    }
    final chapterLength = state.chapters.length;
    final counts = List<int>.filled(chapterLength, 0);
    for (var i = 0;
        i < state.pageCountPerChapter.length && i < chapterLength;
        i++) {
      counts[i] = state.pageCountPerChapter[i];
    }
    counts[state.currentChapterIndex] = pageCount;
    state = state.copyWith(pageCountPerChapter: counts);
  }

  Future<AiHighlight?> loadHighlight() async {
    if (state.chapters.isEmpty) return null;
    final chapter = state.chapters[state.currentChapterIndex];
    return _highlightService.getHighlight(
      book: state.book,
      chapter: chapter,
    );
  }

  Future<void> readAloudCurrent() async {
    if (state.chapters.isEmpty) return;
    final text = state.chapters[state.currentChapterIndex].content ?? '';
    await _ttsService.speak(text);
  }

  Future<void> stopTts() => _ttsService.stop();

  void updatePreference(UserPreference preference) {
    state = state.copyWith(preference: preference);
  }
}

class ReaderPage extends ConsumerStatefulWidget {
  const ReaderPage({
    super.key,
    required this.book,
  });

  final Book book;

  @override
  ConsumerState<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends ConsumerState<ReaderPage> {
  PageController? _pageController;
  List<PageSlice> _pageSlices = const [];
  String? _pageChapterId;
  double? _pageFontSize;
  double? _pageLineHeight;
  Size? _pageContentSize;
  bool _chromeVisible = true;
  DateTime? _startTime;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
  }

  @override
  void dispose() {
    _recordReadingSession();
    _pageController?.dispose();
    super.dispose();
  }

  Future<void> _recordReadingSession() async {
    final start = _startTime;
    if (start == null) return;
    final duration = DateTime.now().difference(start);
    if (duration.inSeconds <= 0) return;
    final statsRepo =
        ref.read(statsRepositoryProvider);
    await statsRepo.addReadingSession(
      duration: duration,
      book: widget.book,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(readerControllerProvider(widget.book));
    final controller =
        ref.read(readerControllerProvider(widget.book).notifier);

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.errorMessage != null
              ? _buildErrorBody(state, controller)
              : state.chapters.isEmpty
                  ? _buildEmptyBody()
                  : _buildPagedReader(context, state, controller),
    );
  }

  Widget _buildPagedReader(
    BuildContext context,
    ReaderState state,
    ReaderController controller,
  ) {
    final theme = Theme.of(context);
    final isDark = state.preference.isDarkMode;
    const lightPaper = Color(0xFFF7F1E1); // 微黄纸张
    const darkPaper = Color(0xFF1E1E1E); // 深灰色背景，更适合阅读
    const lightText = Color(0xFF2C1B10); // 深棕接近黑色
    const darkText = Color(0xFFE0E0E0); // 浅灰色文字，提高可读性
    final backgroundColor = isDark ? darkPaper : lightPaper;
    final textColor = isDark ? darkText : lightText;

    return LayoutBuilder(
      builder: (context, constraints) {
        final mediaQuery = MediaQuery.of(context);
        final topSafe = mediaQuery.padding.top;
        final bottomSafe = mediaQuery.padding.bottom;
        const topChromeHeight = 72.0;
        const bottomChromeHeight = 96.0;
        final reservedTop = topSafe + topChromeHeight;
        final reservedBottom = bottomSafe + bottomChromeHeight;

        final chapters = state.chapters;
        if (chapters.isEmpty) {
          return _buildEmptyBody();
        }

        final currentChapter = chapters[state.currentChapterIndex];
        final content = currentChapter.content ?? '';
        final padding = const EdgeInsets.fromLTRB(16, 32, 16, 32);
        final textStyle = (theme.textTheme.bodyLarge ?? const TextStyle())
            .copyWith(
          fontSize: state.preference.fontSize,
          height: state.preference.lineHeight,
          color: textColor,
        );
        final contentWidth = constraints.maxWidth;
        final rawHeight = constraints.maxHeight - reservedTop - reservedBottom;
        final contentHeight = rawHeight > 0 ? rawHeight : constraints.maxHeight;
        final contentSize = Size(contentWidth, contentHeight);

        final needsRebuild = _pageChapterId != currentChapter.id ||
            _pageFontSize != state.preference.fontSize ||
            _pageLineHeight != state.preference.lineHeight ||
            _pageContentSize != contentSize;

        if (needsRebuild) {
          _pageSlices = PageComposer.paginate(
            text: content,
            style: textStyle,
            maxWidth: contentWidth,
            maxHeight: contentHeight,
            padding: padding,
          );
          if (_pageSlices.isEmpty && content.isNotEmpty) {
            _pageSlices = <PageSlice>[
              PageSlice(start: 0, end: content.length),
            ];
          }
          _pageChapterId = currentChapter.id;
          _pageFontSize = state.preference.fontSize;
          _pageLineHeight = state.preference.lineHeight;
          _pageContentSize = contentSize;

          final totalPages = _pageSlices.isEmpty ? 1 : _pageSlices.length;
          final existingCounts = state.pageCountPerChapter;
          final existingForChapter = existingCounts.length > state.currentChapterIndex
              ? existingCounts[state.currentChapterIndex]
              : 0;
          if (totalPages != existingForChapter) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              controller.updatePageCountForCurrentChapter(totalPages);
            });
          }
        }

        final totalPages = _pageSlices.isEmpty ? 1 : _pageSlices.length;
        var targetPage = state.currentPageIndex;
        if (targetPage >= totalPages) {
          targetPage = totalPages - 1;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            controller.updatePage(
              chapterIndex: state.currentChapterIndex,
              pageIndex: targetPage,
            );
          });
        }

        _ensurePageController(initialPage: targetPage);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            setState(() {
              _chromeVisible = !_chromeVisible;
            });
          },
          child: Stack(
            children: [
              Container(
                color: backgroundColor,
              ),
              Positioned.fill(
                top: reservedTop,
                bottom: reservedBottom,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: totalPages,
                  onPageChanged: (index) {
                    controller.updatePage(
                      chapterIndex: state.currentChapterIndex,
                      pageIndex: index,
                    );
                    ref
                        .read(bookshelfRepositoryProvider)
                        .updateLastRead(widget.book.id);
                  },
                  itemBuilder: (context, index) {
                    final slice = _pageSlices.isEmpty
                        ? PageSlice(start: 0, end: content.length)
                        : _pageSlices[index.clamp(0, _pageSlices.length - 1)];
                    final pageText = content.substring(slice.start, slice.end);

                    return Padding(
                      padding: padding,
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Text(
                          pageText,
                          style: textStyle,
                        ),
                      ),
                    );
                  },
                ),
              ),
              _buildTopBar(context, state, controller),
              _buildBottomBar(context, state, controller, totalPages),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopBar(
    BuildContext context,
    ReaderState state,
    ReaderController controller,
  ) {
    final theme = Theme.of(context);
    final isDark = state.preference.isDarkMode;
    const lightPaper = Color(0xFFF7F1E1);
    const darkPaper = Color(0xFF1E1E1E);
    final baseColor = isDark ? darkPaper : lightPaper;
    final textColor = isDark ? Color(0xFFE0E0E0) : Color(0xFF2C1B10);
    final iconColor = isDark ? Color(0xFFE0E0E0) : Color(0xFF2C1B10);
    final chapterTitle =
        state.chapters.isNotEmpty && state.currentChapterIndex < state.chapters.length
            ? state.chapters[state.currentChapterIndex].title
            : '';

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: _chromeVisible ? 1 : 0,
      child: IgnorePointer(
        ignoring: !_chromeVisible,
        child: Container(
          padding: const EdgeInsets.only(top: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                baseColor.withOpacity(0.96),
                baseColor.withOpacity(0.7),
                baseColor.withOpacity(0.0),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: iconColor),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.book.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(color: textColor),
                        ),
                        if (chapterTitle.isNotEmpty)
                          Text(
                            chapterTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(color: textColor),
                          ),
                      ],
                    ),
                  ),
                  if (widget.book.sourceType != BookSourceType.copyrightLink) ...[
                    IconButton(
                      icon: Icon(Icons.summarize_outlined, color: iconColor),
                      tooltip: '本章书摘（智记）',
                      onPressed: () async {
                        final highlight = await controller.loadHighlight();
                        if (!mounted || highlight == null) {
                          return;
                        }
                        _showHighlightBottomSheet(context, highlight);
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.volume_up_outlined, color: iconColor),
                      tooltip: '朗读本章（智声）',
                      onPressed: () {
                        controller.readAloudCurrent();
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(
    BuildContext context,
    ReaderState state,
    ReaderController controller,
    int totalPages,
  ) {
    final theme = Theme.of(context);
    final isDark = state.preference.isDarkMode;
    const lightPaper = Color(0xFFF7F1E1);
    const darkPaper = Color(0xFF1E1E1E);
    final baseColor = isDark ? darkPaper : lightPaper;
    final textColor = isDark ? Color(0xFFE0E0E0) : Color(0xFF2C1B10);
    final iconColor = isDark ? Color(0xFFE0E0E0) : Color(0xFF2C1B10);
    final chapterTitle =
        state.chapters.isNotEmpty && state.currentChapterIndex < state.chapters.length
            ? state.chapters[state.currentChapterIndex].title
            : '';

    final pageCountFromState =
        state.pageCountPerChapter.length > state.currentChapterIndex
            ? state.pageCountPerChapter[state.currentChapterIndex]
            : 0;
    final pageCount = pageCountFromState > 0 ? pageCountFromState : totalPages;
    final currentPage = pageCount == 0
        ? 0
        : (state.currentPageIndex + 1).clamp(1, pageCount);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: _chromeVisible ? 1 : 0,
      child: IgnorePointer(
        ignoring: !_chromeVisible,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  baseColor.withOpacity(0.0),
                  baseColor.withOpacity(0.75),
                  baseColor.withOpacity(0.97),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            chapterTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(color: textColor),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          pageCount > 0 ? '$currentPage / $pageCount 页' : '',
                          style: theme.textTheme.bodySmall?.copyWith(color: textColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: Icon(Icons.chevron_left, color: iconColor),
                          onPressed: state.currentChapterIndex > 0
                              ? () {
                                  _jumpToChapter(
                                    controller: controller,
                                    chapterIndex:
                                        state.currentChapterIndex - 1,
                                  );
                                }
                              : null,
                        ),
                        IconButton(
                          icon: Icon(Icons.menu_book_outlined, color: iconColor),
                          tooltip: '章节目录',
                          onPressed: () {
                            _showChapterList(context, state, controller);
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.chevron_right, color: iconColor),
                          onPressed: state.currentChapterIndex + 1 <
                                  state.chapters.length
                              ? () {
                                  _jumpToChapter(
                                    controller: controller,
                                    chapterIndex:
                                        state.currentChapterIndex + 1,
                                  );
                                }
                              : null,
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(Icons.text_fields, color: iconColor),
                          tooltip: '阅读设置',
                          onPressed: () {
                            _showPreferenceSheet(context, state, controller);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showHighlightBottomSheet(
    BuildContext context,
    AiHighlight highlight,
  ) {
    if (highlight.sentences.isEmpty &&
        (highlight.summary == null || highlight.summary!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('本章暂未生成书摘')),
      );
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? Colors.tealAccent : Colors.teal;
    final cardColor = isDark ? Colors.grey[800] : Colors.white;
    final textColor = isDark ? Colors.grey[100] : Colors.grey[800];

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: cardColor,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb_outline, color: primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      'AI 书摘 · 智记',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (highlight.summary != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[700] : Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      highlight.summary!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: textColor,
                            height: 1.6,
                          ),
                    ),
                  ),
                if (highlight.sentences.isNotEmpty)
                  ...[
                    const SizedBox(height: 20),
                    Text(
                      '精彩摘录',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 12),
                    ...highlight.sentences.map(
                      (s) => Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[700] : Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border(left: BorderSide(color: primaryColor, width: 3)),
                          ),
                          child: Text(
                            s,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: textColor,
                                  height: 1.5,
                                ),
                          ),
                        ),
                      ),
                    ),
                  ],
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyBody() {
    if (widget.book.sourceType == BookSourceType.copyrightLink &&
        widget.book.externalUrl != null &&
        widget.book.externalUrl!.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                '本书为官方正版链接资源，正文不在应用内存储。',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () async {
                  try {
                    final uri = Uri.parse(widget.book.externalUrl!);
                    await launchUrl(
                      uri,
                      mode: LaunchMode.externalApplication,
                    );
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('打开链接失败：$e')),
                    );
                  }
                },
                icon: const Icon(Icons.open_in_new),
                label: const Text('前往官方阅读'),
              ),
            ],
          ),
        ),
      );
    }

    return const Center(
      child: Text('本书暂无可阅读章节'),
    );
  }

  Widget _buildErrorBody(
    ReaderState state,
    ReaderController controller,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              state.errorMessage ?? '加载失败',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                controller.init();
              },
              child: const Text('重试加载章节'),
            ),
          ],
        ),
      ),
    );
  }

  void _ensurePageController({required int initialPage}) {
    if (_pageController == null) {
      _pageController = PageController(initialPage: initialPage);
      return;
    }
    final controller = _pageController!;
    if (controller.hasClients) {
      final current =
          controller.page != null ? controller.page!.round() : controller.initialPage;
      if (current != initialPage) {
        controller.jumpToPage(initialPage);
      }
    }
  }

  Future<void> _jumpToChapter({
    required ReaderController controller,
    required int chapterIndex,
  }) async {
    if (!mounted) return;
    final notifier = ref.read(bookshelfRepositoryProvider);
    await controller.updatePage(
      chapterIndex: chapterIndex,
      pageIndex: 0,
    );
    notifier.updateLastRead(widget.book.id);
    _pageChapterId = null;
  }

  void _showChapterList(
    BuildContext context,
    ReaderState state,
    ReaderController controller,
  ) {
    final isDark = state.preference.isDarkMode;
    final backgroundColor = isDark ? Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Color(0xFFE0E0E0) : Colors.black;
    final selectedColor = isDark ? Color(0xFF333333) : Colors.grey[100];
    final selectedTextColor = isDark ? Color(0xFFE0E0E0) : Colors.black;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: backgroundColor,
      builder: (context) {
        return SafeArea(
          child: ListView.separated(
            itemCount: state.chapters.length,
            separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? Colors.grey[700] : Colors.grey[200]),
            itemBuilder: (context, index) {
              final chapter = state.chapters[index];
              final isCurrent = index == state.currentChapterIndex;
              return ListTile(
                title: Text(
                  chapter.title.isNotEmpty ? chapter.title : '第 ${index + 1} 章',
                  style: TextStyle(color: isCurrent ? selectedTextColor : textColor),
                ),
                selected: isCurrent,
                selectedTileColor: selectedColor,
                onTap: () async {
                  Navigator.of(context).pop();
                  await _jumpToChapter(
                    controller: controller,
                    chapterIndex: index,
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  void _showPreferenceSheet(
    BuildContext context,
    ReaderState state,
    ReaderController controller,
  ) {
    final current = state.preference;
    var tempFontSize = current.fontSize;
    var tempLineHeight = current.lineHeight;
    var tempDarkMode = current.isDarkMode;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? Colors.tealAccent : Colors.teal;
    final cardColor = isDark ? Colors.grey[800] : Colors.white;
    final textColor = isDark ? Colors.grey[100] : Colors.grey[800];

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: cardColor,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.text_fields, color: primaryColor),
                      const SizedBox(width: 8),
                      Text(
                        '阅读设置',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[700] : Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.format_size, color: primaryColor, size: 18),
                                const SizedBox(width: 8),
                                Text('字体大小', style: TextStyle(color: textColor)),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                tempFontSize.toStringAsFixed(0),
                                style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Slider(
                          value: tempFontSize,
                          min: 12,
                          max: 28,
                          activeColor: primaryColor,
                          inactiveColor: isDark ? Colors.grey[600] : Colors.grey[300],
                          onChanged: (value) {
                            setModalState(() {
                              tempFontSize = value;
                            });
                            controller.updatePreference(
                              state.preference.copyWith(fontSize: value),
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.format_line_spacing, color: primaryColor, size: 18),
                                const SizedBox(width: 8),
                                Text('行距', style: TextStyle(color: textColor)),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                tempLineHeight.toStringAsFixed(1),
                                style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Slider(
                          value: tempLineHeight,
                          min: 1.2,
                          max: 2.0,
                          activeColor: primaryColor,
                          inactiveColor: isDark ? Colors.grey[600] : Colors.grey[300],
                          onChanged: (value) {
                            setModalState(() {
                              tempLineHeight = value;
                            });
                            controller.updatePreference(
                              state.preference.copyWith(lineHeight: value),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[700] : Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.nightlight_round, color: primaryColor, size: 18),
                            const SizedBox(width: 8),
                            Text('夜间模式', style: TextStyle(color: textColor)),
                          ],
                        ),
                        Switch(
                          value: tempDarkMode,
                          activeColor: primaryColor,
                          onChanged: (value) {
                            setModalState(() {
                              tempDarkMode = value;
                            });
                            controller.updatePreference(
                              state.preference.copyWith(isDarkMode: value),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

