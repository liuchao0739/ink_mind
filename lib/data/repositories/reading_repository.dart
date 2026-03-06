import '../datasources/local_storage/hive_reading_progress_data_source.dart';
import '../models/reading_progress.dart';

class ReadingRepository {
  ReadingRepository({
    HiveReadingProgressDataSource? localDataSource,
  }) : _localDataSource =
            localDataSource ?? HiveReadingProgressDataSource();

  final HiveReadingProgressDataSource _localDataSource;

  Future<ReadingProgress?> getProgress(String bookId) {
    return _localDataSource.getProgress(bookId);
  }

  Future<void> saveProgress(ReadingProgress progress) {
    return _localDataSource.saveProgress(progress);
  }
}

