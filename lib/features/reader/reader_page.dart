import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    this.scrollOffset = 0.0,
    this.preference = const UserPreference(),
    this.isLoading = true,
  });

  final Book book;
  final List<Chapter> chapters;
  final int currentChapterIndex;
  final double scrollOffset;
  final UserPreference preference;
  final bool isLoading;

  ReaderState copyWith({
    List<Chapter>? chapters,
    int? currentChapterIndex,
    double? scrollOffset,
    UserPreference? preference,
    bool? isLoading,
  }) {
    return ReaderState(
      book: book,
      chapters: chapters ?? this.chapters,
      currentChapterIndex: currentChapterIndex ?? this.currentChapterIndex,
      scrollOffset: scrollOffset ?? this.scrollOffset,
      preference: preference ?? this.preference,
      isLoading: isLoading ?? this.isLoading,
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
    await _ttsService.init();
    final chapters = await _bookRepository.getChaptersForBook(state.book);
    final progress =
        await _readingRepository.getProgress(state.book.id);

    state = state.copyWith(
      chapters: chapters,
      currentChapterIndex: progress?.chapterIndex ?? 0,
      scrollOffset: progress?.scrollOffset ?? 0.0,
      isLoading: false,
    );
  }

  Future<void> updateScroll(double offset) async {
    state = state.copyWith(scrollOffset: offset);
    await _readingRepository.saveProgress(
      ReadingProgress(
        bookId: state.book.id,
        chapterIndex: state.currentChapterIndex,
        scrollOffset: offset,
        updatedAtMillis: DateTime.now().millisecondsSinceEpoch,
      ),
    );
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
  final _scrollController = ScrollController();
  DateTime? _startTime;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
  }

  @override
  void dispose() {
    _recordReadingSession();
    _scrollController.dispose();
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

    useScrollSync(state, controller);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.book.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.summarize_outlined),
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
            icon: const Icon(Icons.volume_up_outlined),
            tooltip: '朗读本章（智声）',
            onPressed: () {
              controller.readAloudCurrent();
            },
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : NotificationListener<ScrollEndNotification>(
              onNotification: (notification) {
                controller.updateScroll(_scrollController.offset);
                ref
                    .read(bookshelfRepositoryProvider)
                    .updateLastRead(widget.book.id);
                return false;
              },
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    state.chapters[state.currentChapterIndex].title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    state.chapters[state.currentChapterIndex].content ?? '',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          height: state.preference.lineHeight,
                          fontSize: state.preference.fontSize,
                        ),
                  ),
                ],
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

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'AI 书摘 · 智记',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (highlight.summary != null)
                Text(
                  highlight.summary!,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              if (highlight.sentences.isNotEmpty)
                ...[
                  const SizedBox(height: 12),
                  ...highlight.sentences.map(
                    (s) => Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 4,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('· '),
                          Expanded(child: Text(s)),
                        ],
                      ),
                    ),
                  ),
                ],
            ],
          ),
        );
      },
    );
  }

  void useScrollSync(ReaderState state, ReaderController controller) {
    if (!_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients &&
            state.scrollOffset > 0 &&
            state.scrollOffset < _scrollController.position.maxScrollExtent) {
          _scrollController.jumpTo(state.scrollOffset);
        }
      });
    }
  }
}

