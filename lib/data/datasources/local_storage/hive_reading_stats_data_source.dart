import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/hive_boxes.dart';
import '../../models/reading_stats.dart';

class HiveReadingStatsDataSource {
  Box<Map>? _box;

  Future<Box<Map>> _ensureBox() async {
    final existing = _box;
    if (existing != null && existing.isOpen) {
      return existing;
    }
    final box = await Hive.openBox<Map>(HiveBoxes.readingStats);
    _box = box;
    return box;
  }

  Future<ReadingStats?> getByDate(String dateString) async {
    final box = await _ensureBox();
    final raw = box.get(dateString);
    if (raw == null) return null;
    return ReadingStats.fromJson(Map<String, dynamic>.from(raw));
  }

  Future<void> save(ReadingStats stats) async {
    final box = await _ensureBox();
    await box.put(stats.dateString, stats.toJson());
  }

  Future<List<ReadingStats>> loadRecent({int days = 14}) async {
    final box = await _ensureBox();
    final list = box.values
        .map((e) => ReadingStats.fromJson(Map<String, dynamic>.from(e)))
        .toList()
      ..sort((a, b) => b.dateString.compareTo(a.dateString));
    if (list.length <= days) return list;
    return list.sublist(0, days);
  }
}

