import '../../models/book.dart';
import '../../models/chapter.dart';
import '../../../core/network/api_client.dart';
import 'novel_book_data_source.dart';

/// 通用小说API数据源实现
class NovelApiDataSource implements NovelBookDataSource {
  NovelApiDataSource({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient(baseUrl: _baseUrl);

  static const String _baseUrl = 'https://api.pingcc.cn';
  final ApiClient _apiClient;

  @override
  Future<List<Book>> searchRemote(String keyword) async {
    if (keyword.trim().isEmpty) return const [];

    try {
      print('NovelApi: Searching for $keyword');
      final response = await _apiClient.getJson(
        '/novel/search',
        query: {'keyword': keyword},
      );
      print('NovelApi: Received response: $response');
      
      final books = _parseSearchResults(response);
      print('NovelApi: Found ${books.length} books');
      return books;
    } catch (e) {
      print('NovelApi: Search error: $e');
      // 忽略错误，返回空列表
      return const [];
    }
  }

  @override
  Future<(Book, List<Chapter>)> fetchPublicDomainBook(String apiBookId) async {
    try {
      final book = await fetchNovelDetail(apiBookId);
      final chapters = await fetchChapterList(apiBookId);
      return (book, chapters);
    } catch (e) {
      print('NovelApi: Fetch book error: $e');
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
  }

  @override
  Future<Book> fetchNovelDetail(String novelId) async {
    try {
      final response = await _apiClient.getJson(
        '/novel/detail',
        query: {'id': novelId},
      );
      return _parseNovelDetail(response, novelId);
    } catch (e) {
      throw Exception('Failed to fetch novel detail: $e');
    }
  }

  @override
  Future<List<Chapter>> fetchChapterList(String novelId) async {
    try {
      final response = await _apiClient.getJson(
        '/novel/chapters',
        query: {'id': novelId},
      );
      return _parseChapterList(response, novelId);
    } catch (e) {
      print('NovelApi: Fetch chapters error: $e');
      return const [];
    }
  }

  @override
  Future<String> fetchChapterContent(String chapterId, String novelId) async {
    try {
      final response = await _apiClient.getJson(
        '/novel/content',
        query: {'id': chapterId, 'novel_id': novelId},
      );
      return _parseChapterContent(response);
    } catch (e) {
      print('NovelApi: Fetch content error: $e');
      return '';
    }
  }

  @override
  Future<bool> isAvailable() async {
    try {
      await _apiClient.getJson('/novel/search', query: {'keyword': 'test'});
      return true;
    } catch (e) {
      return false;
    }
  }

  List<Book> _parseSearchResults(Map<String, dynamic> data) {
    final books = <Book>[];
    final list = data['data'] as List<dynamic>? ?? [];

    for (final item in list) {
      if (item is Map<String, dynamic>) {
        final id = item['id']?.toString() ?? '';
        final title = item['title']?.toString() ?? '';
        final author = item['author']?.toString() ?? '';
        final category = item['category']?.toString() ?? '玄幻';
        final intro = item['intro']?.toString() ?? '';
        final status = item['status']?.toString() ?? '连载中';
        final heatScore = int.tryParse(item['heat']?.toString() ?? '0') ?? 0;

        books.add(Book(
          id: 'novelapi_$id',
          title: title,
          author: author,
          category: category,
          intro: intro,
          sourceType: BookSourceType.publicDomainApi,
          remoteApiId: id,
          heatScore: heatScore,
          status: status,
        ));
      }
    }

    return books;
  }

  Book _parseNovelDetail(Map<String, dynamic> data, String novelId) {
    final info = data['data'] as Map<String, dynamic>? ?? {};
    final title = info['title']?.toString() ?? '未知标题';
    final author = info['author']?.toString() ?? '未知作者';
    final category = info['category']?.toString() ?? '玄幻';
    final intro = info['intro']?.toString() ?? '';
    final status = info['status']?.toString() ?? '连载中';
    final heatScore = int.tryParse(info['heat']?.toString() ?? '0') ?? 0;

    return Book(
      id: 'novelapi_$novelId',
      title: title,
      author: author,
      category: category,
      intro: intro,
      sourceType: BookSourceType.publicDomainApi,
      remoteApiId: novelId,
      heatScore: heatScore,
      status: status,
    );
  }

  List<Chapter> _parseChapterList(Map<String, dynamic> data, String novelId) {
    final chapters = <Chapter>[];
    final list = data['data'] as List<dynamic>? ?? [];

    var index = 0;
    for (final item in list) {
      if (item is Map<String, dynamic>) {
        final id = item['id']?.toString() ?? '';
        final title = item['title']?.toString() ?? '';

        chapters.add(Chapter(
          id: 'novelapi_chapter_$id',
          bookId: 'novelapi_$novelId',
          index: index,
          title: title,
          content: '',
        ));
        index++;
      }
    }

    return chapters;
  }

  String _parseChapterContent(Map<String, dynamic> data) {
    return data['data']?.toString() ?? '';
  }
}
