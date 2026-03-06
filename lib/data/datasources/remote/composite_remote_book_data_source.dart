import '../../models/book.dart';
import '../../models/chapter.dart';
import 'remote_book_data_source.dart';

/// 组合多个远程书源的实现，统一对外暴露为一个 [RemoteBookDataSource]。
///
/// - `searchRemote`：并发查询多个数据源并合并结果（按 `id` 去重）；
/// - `fetchPublicDomainBook`：按顺序依次尝试各个数据源，返回第一个成功解析出章节的结果。
class CompositeRemoteBookDataSource implements RemoteBookDataSource {
  CompositeRemoteBookDataSource({
    required List<RemoteBookDataSource> sources,
  }) : _sources = List.unmodifiable(sources);

  final List<RemoteBookDataSource> _sources;

  @override
  Future<List<Book>> searchRemote(String keyword) async {
    if (keyword.trim().isEmpty || _sources.isEmpty) {
      return const [];
    }

    final futures = _sources.map((s) => s.searchRemote(keyword));
    final results = await Future.wait(futures, eagerError: false);

    final merged = <String, Book>{};
    for (final list in results) {
      for (final book in list) {
        // 后加入的来源不会覆盖先前同 ID 的书籍，避免意外覆盖本地/更完整的数据。
        merged.putIfAbsent(book.id, () => book);
      }
    }
    return merged.values.toList();
  }

  @override
  Future<(Book, List<Chapter>)> fetchPublicDomainBook(String apiBookId) async {
    if (_sources.isEmpty) {
      return (
        const Book(
          id: '',
          title: '',
          author: '',
          category: '',
        ),
        const <Chapter>[],
      );
    }

    for (final source in _sources) {
      final result = await source.fetchPublicDomainBook(apiBookId);
      final chapters = result.$2;
      if (chapters.isNotEmpty) {
        return result;
      }
    }

    // 全部失败时返回最后一次尝试的 Book（通常至少包含元数据），章节为空。
    final last = await _sources.last.fetchPublicDomainBook(apiBookId);
    return (last.$1, const <Chapter>[]);
  }
}

