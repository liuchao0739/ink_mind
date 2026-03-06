import 'package:intl/intl.dart';

import '../datasources/local_storage/hive_reading_stats_data_source.dart';
import '../models/reading_stats.dart';
import '../models/book.dart';

class StatsRepository {
  StatsRepository({
    HiveReadingStatsDataSource? localDataSource,
  }) : _localDataSource =
            localDataSource ?? HiveReadingStatsDataSource();

  final HiveReadingStatsDataSource _localDataSource;

  Future<void> addReadingSession({
    required Duration duration,
    required Book book,
  }) async {
    if (duration.inSeconds <= 0) return;
    final dateString =
        DateFormat('yyyy-MM-dd').format(DateTime.now());
    final existing = await _localDataSource.getByDate(dateString);
    final minutes = duration.inMinutes > 0 ? duration.inMinutes : 1;
    final words = book.wordCount ~/ 100;
    final categories = <String>{
      if (existing != null) ...existing.mainCategories,
      book.category,
    }.toList();

    final updated = (existing ??
            ReadingStats(
              dateString: dateString,
            ))
        .copyWith(
      minutes: (existing?.minutes ?? 0) + minutes,
      words: (existing?.words ?? 0) + words,
      booksRead: (existing?.booksRead ?? 0) + 1,
      mainCategories: categories,
    );

    await _localDataSource.save(updated);
  }

  Future<List<ReadingStats>> loadRecentStats({int days = 14}) {
    return _localDataSource.loadRecent(days: days);
  }
}

