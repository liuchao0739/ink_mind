import '../../models/book.dart';
import '../../models/chapter.dart';
import '../../../core/network/api_client.dart';
import 'novel_book_data_source.dart';

/// 笔趣阁数据源实现
class BiQuGeBookDataSource implements NovelBookDataSource {
  BiQuGeBookDataSource({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient(baseUrl: _baseUrl);

  static const String _baseUrl = 'https://www.biquge5200.cc';
  final ApiClient _apiClient;

  @override
  Future<List<Book>> searchRemote(String keyword) async {
    if (keyword.trim().isEmpty) return const [];

    try {
      print('BiQuGe: Searching for $keyword');
      final response = await _apiClient.getTextFromUrl('$_baseUrl/search.php?keyword=${Uri.encodeComponent(keyword)}');
      print('BiQuGe: Received response length: ${response.length}');
      final books = _parseSearchResults(response);
      print('BiQuGe: Found ${books.length} books');
      return books;
    } catch (e) {
      print('BiQuGe: Search error: $e');
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
      return const [];
    }
  }

  @override
  Future<String> fetchChapterContent(String chapterId, String novelId) async {
    try {
      final response = await _apiClient.getTextFromUrl('$_baseUrl$chapterId');
      return _parseChapterContent(response);
    } catch (e) {
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

  List<Book> _parseSearchResults(String html) {
    final books = <Book>[];
    final regex = RegExp(r'<li>.*?<a href="(.*?)".*?>(.*?)</a>.*?<span class="s2">(.*?)</span>', dotAll: true);
    final matches = regex.allMatches(html);

    for (final match in matches) {
      if (match.groupCount >= 3) {
        final path = match.group(1)!;
        final title = match.group(2)!.replaceAll(RegExp(r'<[^>]*>'), '').trim();
        final author = match.group(3)!.trim();

        books.add(Book(
          id: 'biquge_${path.replaceAll('/', '')}',
          title: title,
          author: author,
          category: '网络小说',
          sourceType: BookSourceType.publicDomainApi, // 使用相同的类型，实际是网络小说
          remoteApiId: path,
        ));
      }
    }

    return books;
  }

  Book _parseNovelDetail(String html, String novelId) {
    final titleRegex = RegExp(r'<h1>(.*?)</h1>');
    final authorRegex = RegExp(r'<meta property="og:novel:author" content="(.*?)"/>');
    final introRegex = RegExp(r'<div id="intro">(.*?)</div>', dotAll: true);

    final titleMatch = titleRegex.firstMatch(html);
    final authorMatch = authorRegex.firstMatch(html);
    final introMatch = introRegex.firstMatch(html);

    final title = titleMatch?.group(1)?.trim() ?? '未知标题';
    final author = authorMatch?.group(1)?.trim() ?? '未知作者';
    final intro = introMatch?.group(1)?.replaceAll(RegExp(r'<[^>]*>'), '').trim() ?? '';

    return Book(
      id: 'biquge_${novelId.replaceAll('/', '')}',
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
    final regex = RegExp(r'<dd><a href="(.*?)">(.*?)</a></dd>');
    final matches = regex.allMatches(html);

    var index = 0;
    for (final match in matches) {
      if (match.groupCount >= 2) {
        final path = match.group(1)!;
        final chapterTitle = match.group(2)!.trim();

        chapters.add(Chapter(
          id: 'biquge_chapter_${path.replaceAll('/', '')}',
          bookId: 'biquge_${novelId.replaceAll('/', '')}',
          index: index,
          title: chapterTitle,
          content: '', // 内容将在需要时获取
        ));
        index++;
      }
    }

    return chapters;
  }

  String _parseChapterContent(String html) {
    final regex = RegExp(r'<div id="content">(.*?)</div>', dotAll: true);
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
}
