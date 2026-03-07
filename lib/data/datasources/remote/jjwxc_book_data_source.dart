import '../../models/book.dart';
import '../../models/chapter.dart';
import '../../../core/network/api_client.dart';
import 'universal_book_data_source.dart';

/// 晋江文学城数据源实现
class JJWXCBookDataSource implements UniversalBookDataSource {
  JJWXCBookDataSource({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient(baseUrl: _baseUrl);

  static const String _baseUrl = 'https://www.jjwxc.net';
  final ApiClient _apiClient;

  @override
  String get sourceName => '晋江文学城';

  @override
  String get baseUrl => _baseUrl;

  @override
  List<SearchType> get supportedSearchTypes => [
    SearchType.title,
    SearchType.author,
    SearchType.keyword,
  ];

  @override
  Future<List<Book>> searchRemote(String keyword) async {
    if (keyword.trim().isEmpty) return const [];

    try {
      print('JJWXC: Searching for $keyword');
      final response = await _apiClient.getTextFromUrl('$_baseUrl/search.php?kw=${Uri.encodeComponent(keyword)}');
      print('JJWXC: Received response length: ${response.length}');
      final books = _parseSearchResults(response);
      print('JJWXC: Found ${books.length} books');
      return books;
    } catch (e) {
      print('JJWXC: Search error: $e');
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
      print('JJWXC: Fetch book error: $e');
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
      final response = await _apiClient.getTextFromUrl('$_baseUrl$novelId');
      return _parseNovelDetail(response, novelId);
    } catch (e) {
      throw Exception('Failed to fetch novel detail: $e');
    }
  }

  @override
  Future<List<Chapter>> fetchChapterList(String novelId) async {
    try {
      final response = await _apiClient.getTextFromUrl('$_baseUrl$novelId');
      return _parseChapterList(response, novelId);
    } catch (e) {
      print('JJWXC: Fetch chapter list error: $e');
      return const [];
    }
  }

  @override
  Future<String> fetchChapterContent(String chapterId, String novelId) async {
    try {
      final response = await _apiClient.getTextFromUrl('$_baseUrl$chapterId');
      return _parseChapterContent(response);
    } catch (e) {
      print('JJWXC: Fetch chapter content error: $e');
      return '';
    }
  }

  @override
  Future<bool> isAvailable() async {
    try {
      await _apiClient.getTextFromUrl(_baseUrl);
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<List<Book>> advancedSearch({
    required String keyword,
    SearchType searchType = SearchType.title,
    String? author,
    String? category,
  }) async {
    // 实现高级搜索逻辑
    return await searchRemote(keyword);
  }

  @override
  Future<Map<String, String>> batchFetchChapterContent(
    List<String> chapterIds, 
    String novelId,
  ) async {
    final result = <String, String>{};
    
    for (final chapterId in chapterIds) {
      try {
        final content = await fetchChapterContent(chapterId, novelId);
        if (content.isNotEmpty) {
          result[chapterId] = content;
        }
      } catch (e) {
        print('JJWXC: Batch fetch error for chapter $chapterId: $e');
      }
    }
    
    return result;
  }

  @override
  Future<List<Book>> getRelatedBooks(String novelId) async {
    try {
      final response = await _apiClient.getTextFromUrl('$_baseUrl$novelId');
      return _parseRelatedBooks(response);
    } catch (e) {
      print('JJWXC: Get related books error: $e');
      return const [];
    }
  }

  @override
  Future<DataSourceHealthStatus> checkHealthStatus() async {
    try {
      final response = await _apiClient.getTextFromUrl(_baseUrl);
      if (response.contains('晋江文学城')) {
        return DataSourceHealthStatus.healthy;
      } else {
        return DataSourceHealthStatus.degraded;
      }
    } catch (e) {
      return DataSourceHealthStatus.unavailable;
    }
  }

  @override
  Future<void> clearCache() async {
    // 实现缓存清除逻辑
  }

  List<Book> _parseSearchResults(String html) {
    final books = <Book>[];
    // 晋江文学城的搜索结果解析
    final regex = RegExp(r'<tr.*?><td.*?><a href="(.*?)" .*?>(.*?)</a></td>.*?<td.*?>(.*?)</td>', dotAll: true);
    final matches = regex.allMatches(html);

    for (final match in matches) {
      if (match.groupCount >= 3) {
        final path = match.group(1)!;
        final title = match.group(2)!.replaceAll(RegExp(r'<[^>]*>'), '').trim();
        final author = match.group(3)!.replaceAll(RegExp(r'<[^>]*>'), '').trim();

        books.add(Book(
          id: 'jjwxc_${path.replaceAll('/', '')}',
          title: title,
          author: author,
          category: '网络小说',
          sourceType: BookSourceType.publicDomainApi,
          remoteApiId: path,
        ));
      }
    }

    return books;
  }

  Book _parseNovelDetail(String html, String novelId) {
    final titleRegex = RegExp(r'<h1>(.*?)</h1>');
    final authorRegex = RegExp(r'<span class="authorname"><a .*?>(.*?)</a></span>');
    final introRegex = RegExp(r'<div class="novelintro">(.*?)</div>', dotAll: true);

    final titleMatch = titleRegex.firstMatch(html);
    final authorMatch = authorRegex.firstMatch(html);
    final introMatch = introRegex.firstMatch(html);

    final title = titleMatch?.group(1)?.trim() ?? '未知标题';
    final author = authorMatch?.group(1)?.trim() ?? '未知作者';
    final intro = introMatch?.group(1)?.replaceAll(RegExp(r'<[^>]*>'), '').trim() ?? '';

    return Book(
      id: 'jjwxc_${novelId.replaceAll('/', '')}',
      title: title,
      author: author,
      category: '网络小说',
      intro: intro,
      sourceType: BookSourceType.publicDomainApi,
      remoteApiId: novelId,
    );
  }

  List<Chapter> _parseChapterList(String html, String novelId) {
    final chapters = <Chapter>[];
    final regex = RegExp(r'<a href="(.*?)" .*?>(.*?)</a>', dotAll: true);
    final matches = regex.allMatches(html);

    var index = 0;
    for (final match in matches) {
      if (match.groupCount >= 2) {
        final path = match.group(1)!;
        final chapterTitle = match.group(2)!.replaceAll(RegExp(r'<[^>]*>'), '').trim();

        // 过滤掉非章节链接
        if (path.contains('/onebook.php?novelid=') && path.contains('chapterid=')) {
          chapters.add(Chapter(
            id: 'jjwxc_chapter_${path.replaceAll('/', '')}',
            bookId: 'jjwxc_${novelId.replaceAll('/', '')}',
            index: index,
            title: chapterTitle,
            content: '',
          ));
          index++;
        }
      }
    }

    return chapters;
  }

  String _parseChapterContent(String html) {
    final regex = RegExp(r'<div class="novelcontent">(.*?)</div>', dotAll: true);
    final match = regex.firstMatch(html);

    if (match != null && match.groupCount >= 1) {
      var content = match.group(1)!;
      content = content.replaceAll(RegExp(r'<[^>]*>'), '');
      content = content.replaceAll('&nbsp;', ' ');
      content = content.replaceAll('\n\n', '\n');
      content = content.trim();
      return content;
    }

    return '';
  }

  List<Book> _parseRelatedBooks(String html) {
    final books = <Book>[];
    // 解析相关推荐书籍
    final regex = RegExp(r'<div class="recommend">.*?<a href="(.*?)" .*?>(.*?)</a>.*?<span class="author">(.*?)</span>', dotAll: true);
    final matches = regex.allMatches(html);

    for (final match in matches) {
      if (match.groupCount >= 3) {
        final path = match.group(1)!;
        final title = match.group(2)!.replaceAll(RegExp(r'<[^>]*>'), '').trim();
        final author = match.group(3)!.replaceAll(RegExp(r'<[^>]*>'), '').trim();

        books.add(Book(
          id: 'jjwxc_${path.replaceAll('/', '')}',
          title: title,
          author: author,
          category: '网络小说',
          sourceType: BookSourceType.publicDomainApi,
          remoteApiId: path,
        ));
      }
    }

    return books;
  }
}
