import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/hive_boxes.dart';
import '../../models/reading_progress.dart';

class HiveReadingProgressDataSource {
  Box<Map>? _box;

  Future<Box<Map>> _ensureBox() async {
    final existing = _box;
    if (existing != null && existing.isOpen) {
      return existing;
    }
    final box = await Hive.openBox<Map>(HiveBoxes.readingProgress);
    _box = box;
    return box;
  }

  Future<ReadingProgress?> getProgress(String bookId) async {
    final box = await _ensureBox();
    final raw = box.get(bookId);
    if (raw == null) {
      return null;
    }
    return ReadingProgress.fromJson(Map<String, dynamic>.from(raw));
  }

  Future<void> saveProgress(ReadingProgress progress) async {
    final box = await _ensureBox();
    await box.put(progress.bookId, progress.toJson());
  }
}

