import 'package:hive_flutter/hive_flutter.dart';

class SearchHistoryDataSource {
  static const String _boxName = 'search_history';
  late Box<String> _box;

  Future<void> init() async {
    _box = await Hive.openBox<String>(_boxName);
  }

  Future<List<String>> getHistory() async {
    await init();
    return _box.values.toList().reversed.toList();
  }

  Future<void> addHistory(String keyword) async {
    await init();
    // 先移除重复的关键词
    await _box.delete(keyword);
    // 添加到最前面
    await _box.put(keyword, keyword);
    // 限制历史记录数量为10条
    if (_box.length > 10) {
      final keys = _box.keys.toList();
      for (int i = 0; i < _box.length - 10; i++) {
        await _box.delete(keys[i]);
      }
    }
  }

  Future<void> clearHistory() async {
    await init();
    await _box.clear();
  }

  Future<void> removeHistory(String keyword) async {
    await init();
    await _box.delete(keyword);
  }
}
