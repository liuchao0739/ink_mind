import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../../data/datasources/local_storage/hive_ai_highlight_data_source.dart';
import '../../../data/models/ai_highlight.dart';
import '../../../data/models/chapter.dart';
import '../../../data/models/book.dart';

class HighlightService {
  HighlightService({
    HiveAiHighlightDataSource? localDataSource,
  }) : _localDataSource = localDataSource ?? HiveAiHighlightDataSource();

  final HiveAiHighlightDataSource _localDataSource;

  Future<AiHighlight?> getHighlight({
    required Book book,
    required Chapter chapter,
  }) async {
    final cached =
        await _localDataSource.getHighlight(book.id, chapter.index);
    if (cached != null && cached.sentences.isNotEmpty) {
      return cached;
    }

    final assetHighlight = await _loadFromAsset(book, chapter.index);
    if (assetHighlight != null) {
      await _localDataSource.saveHighlight(assetHighlight);
      return assetHighlight;
    }

    final heuristic = _buildHeuristicHighlight(book, chapter);
    if (heuristic.sentences.isNotEmpty) {
      await _localDataSource.saveHighlight(heuristic);
      return heuristic;
    }
    return null;
  }

  Future<AiHighlight?> _loadFromAsset(Book book, int chapterIndex) async {
    final mapping = <String, String>{};
    final path = mapping[book.id];
    if (path == null) return null;

    try {
      final raw = await rootBundle.loadString(path);
      final jsonMap = json.decode(raw) as Map<String, dynamic>;
      final items = jsonMap['highlights'] as List<dynamic>? ?? [];
      for (final item in items) {
        final map = item as Map<String, dynamic>;
        if ((map['chapterIndex'] as int? ?? 0) == chapterIndex) {
          return AiHighlight(
            bookId: book.id,
            chapterIndex: chapterIndex,
            sentences:
                (map['sentences'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
            summary: map['summary'] as String?,
          );
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  AiHighlight _buildHeuristicHighlight(Book book, Chapter chapter) {
    final text = chapter.content ?? '';
    if (text.isEmpty) {
      return AiHighlight(bookId: book.id, chapterIndex: chapter.index);
    }

    final roughSentences = text
        .split(RegExp(r'[。！？!?]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final keywords = ['然而', '因此', '但是', '只见', '忽然', '原来'];
    final scored = <(String, double)>[];
    for (final s in roughSentences) {
      var score = s.length / 10;
      for (final k in keywords) {
        if (s.contains(k)) score += 3;
      }
      if (s.length > 80) score += 1;
      scored.add((s, score));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));

    final topSentences =
        scored.take(3).map((e) => e.$1).toList(growable: false);

    return AiHighlight(
      bookId: book.id,
      chapterIndex: chapter.index,
      sentences: topSentences,
    );
  }
}

