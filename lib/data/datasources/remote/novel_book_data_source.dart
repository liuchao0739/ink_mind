import '../../models/book.dart';
import '../../models/chapter.dart';
import 'remote_book_data_source.dart';

/// 网络小说数据源接口，扩展自RemoteBookDataSource
/// 用于实现各种网络小说API的数据源
abstract class NovelBookDataSource extends RemoteBookDataSource {
  /// 获取小说详情
  Future<Book> fetchNovelDetail(String novelId);

  /// 获取小说章节列表
  Future<List<Chapter>> fetchChapterList(String novelId);

  /// 获取章节内容
  Future<String> fetchChapterContent(String chapterId, String novelId);

  /// 检查数据源是否可用
  Future<bool> isAvailable();
}
