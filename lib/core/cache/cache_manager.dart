import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import '../../data/models/book.dart';
import '../../data/models/chapter.dart';

/// 缓存管理器
/// 负责管理书籍内容的本地缓存，包括章节内容、搜索结果等
class CacheManager {
  CacheManager._privateConstructor();
  static final CacheManager _instance = CacheManager._privateConstructor();
  factory CacheManager() => _instance;

  late Directory _cacheDir;
  bool _initialized = false;

  /// 初始化缓存目录
  Future<void> initialize() async {
    if (_initialized) return;
    
    final appDir = await getApplicationDocumentsDirectory();
    _cacheDir = Directory('${appDir.path}/cache');
    if (!_cacheDir.existsSync()) {
      _cacheDir.createSync(recursive: true);
    }
    
    _initialized = true;
  }

  /// 缓存章节内容
  Future<void> cacheChapterContent(String chapterId, String content) async {
    await initialize();
    
    final file = File('${_cacheDir.path}/chapter_$chapterId.txt');
    await file.writeAsString(content);
  }

  /// 获取缓存的章节内容
  Future<String?> getCachedChapterContent(String chapterId) async {
    await initialize();
    
    final file = File('${_cacheDir.path}/chapter_$chapterId.txt');
    if (file.existsSync()) {
      return await file.readAsString();
    }
    return null;
  }

  /// 缓存书籍信息
  Future<void> cacheBook(Book book) async {
    await initialize();
    
    final file = File('${_cacheDir.path}/book_${book.id}.json');
    await file.writeAsString(json.encode(book.toJson()));
  }

  /// 获取缓存的书籍信息
  Future<Book?> getCachedBook(String bookId) async {
    await initialize();
    
    final file = File('${_cacheDir.path}/book_$bookId.json');
    if (file.existsSync()) {
      final jsonString = await file.readAsString();
      final jsonMap = json.decode(jsonString) as Map<String, dynamic>;
      return Book.fromJson(jsonMap);
    }
    return null;
  }

  /// 缓存搜索结果
  Future<void> cacheSearchResults(String keyword, List<Book> books) async {
    await initialize();
    
    final file = File('${_cacheDir.path}/search_${keyword.hashCode}.json');
    final data = {
      'keyword': keyword,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'books': books.map((book) => book.toJson()).toList(),
    };
    await file.writeAsString(json.encode(data));
  }

  /// 获取缓存的搜索结果
  Future<List<Book>?> getCachedSearchResults(String keyword) async {
    await initialize();
    
    final file = File('${_cacheDir.path}/search_${keyword.hashCode}.json');
    if (file.existsSync()) {
      final jsonString = await file.readAsString();
      final jsonMap = json.decode(jsonString) as Map<String, dynamic>;
      final timestamp = jsonMap['timestamp'] as int;
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // 搜索结果缓存1小时
      if (now - timestamp < 3600000) {
        final booksJson = jsonMap['books'] as List<dynamic>;
        return booksJson.map((json) => Book.fromJson(json as Map<String, dynamic>)).toList();
      }
    }
    return null;
  }

  /// 缓存章节列表
  Future<void> cacheChapterList(String bookId, List<Chapter> chapters) async {
    await initialize();
    
    final file = File('${_cacheDir.path}/chapters_$bookId.json');
    final data = {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'chapters': chapters.map((chapter) => chapter.toJson()).toList(),
    };
    await file.writeAsString(json.encode(data));
  }

  /// 获取缓存的章节列表
  Future<List<Chapter>?> getCachedChapterList(String bookId) async {
    await initialize();
    
    final file = File('${_cacheDir.path}/chapters_$bookId.json');
    if (file.existsSync()) {
      final jsonString = await file.readAsString();
      final jsonMap = json.decode(jsonString) as Map<String, dynamic>;
      final timestamp = jsonMap['timestamp'] as int;
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // 章节列表缓存24小时
      if (now - timestamp < 86400000) {
        final chaptersJson = jsonMap['chapters'] as List<dynamic>;
        return chaptersJson.map((json) => Chapter.fromJson(json as Map<String, dynamic>)).toList();
      }
    }
    return null;
  }

  /// 预加载章节内容
  Future<void> preloadChapters(String bookId, List<Chapter> chapters, {int preloadCount = 3}) async {
    await initialize();
    
    // 预加载当前章节前后的章节
    for (int i = 0; i < chapters.length && i < preloadCount; i++) {
      final chapter = chapters[i];
      // 这里可以实现预加载逻辑，比如异步获取章节内容并缓存
      // 为了避免阻塞，这里只是示例
    }
  }

  /// 清理过期缓存
  Future<void> cleanExpiredCache() async {
    await initialize();
    
    final files = _cacheDir.listSync();
    final now = DateTime.now().millisecondsSinceEpoch;
    
    for (final file in files) {
      if (file is File) {
        final filename = file.path.split('/').last;
        
        // 清理过期的搜索结果
        if (filename.startsWith('search_')) {
          try {
            final jsonString = await file.readAsString();
            final jsonMap = json.decode(jsonString) as Map<String, dynamic>;
            final timestamp = jsonMap['timestamp'] as int;
            if (now - timestamp > 3600000) {
              file.deleteSync();
            }
          } catch (e) {
            // 解析失败，删除文件
            file.deleteSync();
          }
        }
        
        // 清理过期的章节列表
        else if (filename.startsWith('chapters_')) {
          try {
            final jsonString = await file.readAsString();
            final jsonMap = json.decode(jsonString) as Map<String, dynamic>;
            final timestamp = jsonMap['timestamp'] as int;
            if (now - timestamp > 86400000) {
              file.deleteSync();
            }
          } catch (e) {
            // 解析失败，删除文件
            file.deleteSync();
          }
        }
      }
    }
  }

  /// 清理所有缓存
  Future<void> clearAllCache() async {
    await initialize();
    
    final files = _cacheDir.listSync();
    for (final file in files) {
      if (file is File) {
        file.deleteSync();
      }
    }
  }

  /// 获取缓存大小
  Future<int> getCacheSize() async {
    await initialize();
    
    int size = 0;
    final files = _cacheDir.listSync();
    for (final file in files) {
      if (file is File) {
        size += file.lengthSync();
      }
    }
    return size;
  }

  /// 智能缓存管理
  Future<void> manageCache({int maxCacheSize = 1024 * 1024 * 100}) async { // 100MB
    await initialize();
    
    final currentSize = await getCacheSize();
    if (currentSize > maxCacheSize) {
      // 清理最旧的缓存
      final files = _cacheDir.listSync();
      final fileInfos = <(File, int)>[];
      
      for (final file in files) {
        if (file is File) {
          fileInfos.add((file, file.lastModifiedSync().millisecondsSinceEpoch));
        }
      }
      
      // 按修改时间排序
      fileInfos.sort((a, b) => a.$2.compareTo(b.$2));
      
      // 删除最旧的文件，直到缓存大小低于限制
      int currentSizeTemp = currentSize;
      for (final (file, _) in fileInfos) {
        if (currentSizeTemp <= maxCacheSize) break;
        final fileSize = file.lengthSync();
        file.deleteSync();
        currentSizeTemp -= fileSize;
      }
    }
  }
}
