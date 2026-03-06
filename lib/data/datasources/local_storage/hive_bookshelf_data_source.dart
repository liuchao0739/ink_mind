import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/hive_boxes.dart';
import '../../models/bookshelf_item.dart';

class HiveBookshelfDataSource {
  Box<Map>? _box;

  Future<Box<Map>> _ensureBox() async {
    final existing = _box;
    if (existing != null && existing.isOpen) {
      return existing;
    }
    final box = await Hive.openBox<Map>(HiveBoxes.bookshelf);
    _box = box;
    return box;
  }

  Future<List<BookshelfItem>> loadAll() async {
    final box = await _ensureBox();
    return box.values
        .map((value) => BookshelfItem.fromJson(Map<String, dynamic>.from(value)))
        .toList()
      ..sort(
        (a, b) => (b.lastReadAtMillis ?? b.addedAtMillis)
            .compareTo(a.lastReadAtMillis ?? a.addedAtMillis),
      );
  }

  Future<void> upsert(BookshelfItem item) async {
    final box = await _ensureBox();
    await box.put(item.bookId, item.toJson());
  }

  Future<void> remove(String bookId) async {
    final box = await _ensureBox();
    await box.delete(bookId);
  }

  Future<bool> exists(String bookId) async {
    final box = await _ensureBox();
    return box.containsKey(bookId);
  }
}

