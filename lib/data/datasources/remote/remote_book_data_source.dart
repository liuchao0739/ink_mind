import '../../models/book.dart';
import '../../models/chapter.dart';

/// 抽象的远程书源接口，方便接入公版/古籍 API 或公开小说 API。
abstract class RemoteBookDataSource {
  Future<List<Book>> searchRemote(String keyword);

  Future<(Book, List<Chapter>)> fetchPublicDomainBook(String apiBookId);
}

/// 默认占位实现：不返回任何远程书籍，便于在无配置时安全降级。
class NullRemoteBookDataSource implements RemoteBookDataSource {
  const NullRemoteBookDataSource();

  @override
  Future<List<Book>> searchRemote(String keyword) async {
    return const [];
  }

  @override
  Future<(Book, List<Chapter>)> fetchPublicDomainBook(String apiBookId) async {
    return (
      const Book(
        id: '',
        title: '',
        author: '',
        category: '',
      ),
      <Chapter>[],
    );
  }
}

