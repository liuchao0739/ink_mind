import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/hive_boxes.dart';
import '../../models/ai_highlight.dart';

class HiveAiHighlightDataSource {
  Box<Map>? _box;

  Future<Box<Map>> _ensureBox() async {
    final existing = _box;
    if (existing != null && existing.isOpen) {
      return existing;
    }
    final box = await Hive.openBox<Map>(HiveBoxes.aiHighlights);
    _box = box;
    return box;
  }

  String _key(String bookId, int chapterIndex) =>
      '$bookId::$chapterIndex';

  Future<AiHighlight?> getHighlight(String bookId, int chapterIndex) async {
    final box = await _ensureBox();
    final raw = box.get(_key(bookId, chapterIndex));
    if (raw == null) return null;
    return AiHighlight.fromJson(Map<String, dynamic>.from(raw));
  }

  Future<void> saveHighlight(AiHighlight highlight) async {
    final box = await _ensureBox();
    await box.put(_key(highlight.bookId, highlight.chapterIndex),
        highlight.toJson());
  }
}

