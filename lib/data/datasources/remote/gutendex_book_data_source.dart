import '../../models/book.dart';
import '../../models/chapter.dart';
import '../../../core/network/api_client.dart';
import 'remote_book_data_source.dart';

/// Real public-domain book source using Project Gutenberg via Gutendex API.
/// Fetches complete book text and parses into chapters for in-app reading.
class GutendexBookDataSource implements RemoteBookDataSource {
  GutendexBookDataSource({ApiClient? apiClient})
      : _apiClient =
            apiClient ?? ApiClient(baseUrl: _gutendexBase);

  static const String _gutendexBase = 'https://gutendex.com';

  final ApiClient _apiClient;

  String? _getTextUrl(Map<String, dynamic> formats) {
    return formats['text/plain; charset=utf-8'] as String? ??
        formats['text/plain'] as String? ??
        formats['text/plain; charset=us-ascii'] as String?;
  }

  @override
  Future<List<Book>> searchRemote(String keyword) async {
    if (keyword.trim().isEmpty) return const [];

    final decoded = await _apiClient.getJson(
      '/books',
      query: <String, dynamic>{
        'search': keyword.trim(),
        'mime_type': 'text/plain',
      },
    );
    final results = decoded['results'] as List<dynamic>? ?? [];

    final books = <Book>[];
    final seenIds = <int>{};

    for (final r in results) {
      final map = r as Map<String, dynamic>;
      if (map['media_type'] != 'Text') continue;

      final id = map['id'] as int?;
      if (id == null || seenIds.contains(id)) continue;
      seenIds.add(id);

      final formats = map['formats'] as Map<String, dynamic>?;
      if (_getTextUrl(formats ?? {}) == null) continue;

      final authors = map['authors'] as List<dynamic>? ?? [];
      final author = authors.isNotEmpty
          ? (authors[0] as Map<String, dynamic>)['name'] as String? ?? ''
          : '';

      final subjects = map['subjects'] as List<dynamic>? ?? [];
      final tags = subjects
          .take(5)
          .map((s) => s.toString().split(' -- ').first)
          .where((s) => s.length < 20)
          .toList();

      final summaries = map['summaries'] as List<dynamic>? ?? [];
      final intro = summaries.isNotEmpty
          ? summaries[0].toString().replaceAll('(This is an automatically generated summary.)', '').trim()
          : '';

      books.add(Book(
        id: 'gutenberg_$id',
        title: map['title'] as String? ?? 'Unknown',
        author: author,
        category: tags.isNotEmpty ? tags.first : '公版书',
        tags: tags,
        wordCount: 0,
        status: 'completed',
        intro: intro,
        sourceType: BookSourceType.publicDomainApi,
        heatScore: (map['download_count'] as int? ?? 0) ~/ 1000,
        remoteApiId: id.toString(),
        detailAsset: null,
      ));
    }

    return books;
  }

  @override
  Future<(Book, List<Chapter>)> fetchPublicDomainBook(String apiBookId) async {
    final id = int.tryParse(apiBookId);
    if (id == null) {
      return (_emptyBook(apiBookId), const <Chapter>[]);
    }

    final decoded =
        await _apiClient.getJson('/books/$id');
    final formats = decoded['formats'] as Map<String, dynamic>?;
    final textUrl = _getTextUrl(formats ?? {});

    if (textUrl == null || textUrl.isEmpty) {
      return (_bookFromGutendex(decoded, apiBookId), const <Chapter>[]);
    }

    var text = await _apiClient.getTextFromUrl(textUrl);
    // 防止极端长文本导致内存压力，简单截断到 5MB 左右。
    const maxBytes = 5 * 1024 * 1024;
    if (text.length > maxBytes) {
      text = text.substring(0, maxBytes);
    }

    final chapters = _parseChapters(text, 'gutenberg_$apiBookId', apiBookId);

    final book = _bookFromGutendex(decoded, apiBookId);

    if (chapters.isEmpty) {
      return (book, [
        Chapter(
          id: '${apiBookId}_ch0',
          bookId: book.id,
          index: 0,
          title: book.title,
          content: text,
        ),
      ]);
    }

    return (book, chapters);
  }

  Book _emptyBook(String apiBookId) {
    return Book(
      id: 'gutenberg_$apiBookId',
      title: '',
      author: '',
      category: '',
      sourceType: BookSourceType.publicDomainApi,
      remoteApiId: apiBookId,
    );
  }

  Book _bookFromGutendex(Map<String, dynamic> decoded, String apiBookId) {
    final authors = decoded['authors'] as List<dynamic>? ?? [];
    final author = authors.isNotEmpty
        ? (authors[0] as Map<String, dynamic>)['name'] as String? ?? ''
        : '';

    final subjects = decoded['subjects'] as List<dynamic>? ?? [];
    final tags = subjects
        .take(5)
        .map((s) => s.toString().split(' -- ').first)
        .where((s) => s.length < 20)
        .toList();

    final summaries = decoded['summaries'] as List<dynamic>? ?? [];
    final intro = summaries.isNotEmpty
        ? summaries[0].toString().replaceAll('(This is an automatically generated summary.)', '').trim()
        : '';

    return Book(
      id: 'gutenberg_$apiBookId',
      title: decoded['title'] as String? ?? 'Unknown',
      author: author,
      category: tags.isNotEmpty ? tags.first : '公版书',
      tags: tags,
      wordCount: 0,
      status: 'completed',
      intro: intro,
      sourceType: BookSourceType.publicDomainApi,
      heatScore: (decoded['download_count'] as int? ?? 0) ~/ 1000,
      remoteApiId: apiBookId,
      detailAsset: null,
    );
  }

  List<Chapter> _parseChapters(String text, String bookId, String apiBookId) {
    text = _stripGutenbergBoilerplate(text);
    if (text.isEmpty) return [];

    final chapterPattern = RegExp(
      r'^(?:Chapter|CHAPTER)\s+([IVXLCDM]+|\d+|[Oo]ne|[Tt]wo|[Tt]hree|[Ff]our|[Ff]ive|[Ss]ix|[Ss]even|[Ee]ight|[Nn]ine|[Tt]en|[Ee]leven|[Tt]welve)\b[^\n]*',
      multiLine: true,
      caseSensitive: false,
    );

    final matchList = chapterPattern.allMatches(text).toList();
    if (matchList.isEmpty) {
      if (text.length > 200) {
        return [
          Chapter(
            id: '${apiBookId}_ch0',
            bookId: bookId,
            index: 0,
            title: 'Full Text',
            content: text,
          ),
        ];
      }
      return [];
    }

    final chapters = <Chapter>[];
    var index = 0;

    for (var i = 0; i < matchList.length; i++) {
      final m = matchList[i];
      final nextStart =
          i + 1 < matchList.length ? matchList[i + 1].start : text.length;
      final content = text.substring(m.end, nextStart).trim();
      if (content.length > 50) {
        chapters.add(Chapter(
          id: '${apiBookId}_ch$index',
          bookId: bookId,
          index: index,
          title: m.group(0)?.trim() ?? 'Chapter ${index + 1}',
          content: content,
        ));
        index++;
      }
    }

    if (chapters.isEmpty && text.length > 200) {
      return [
        Chapter(
          id: '${apiBookId}_ch0',
          bookId: bookId,
          index: 0,
          title: 'Full Text',
          content: text,
        ),
      ];
    }

    return chapters;
  }

  String _stripGutenbergBoilerplate(String text) {
    const startMarkers = [
      '*** START OF THIS PROJECT GUTENBERG EBOOK',
      '*** START OF THE PROJECT GUTENBERG EBOOK',
      '***START OF THE PROJECT GUTENBERG EBOOK',
    ];
    const endMarkers = [
      '*** END OF THIS PROJECT GUTENBERG EBOOK',
      '*** END OF THE PROJECT GUTENBERG EBOOK',
      '***END OF THE PROJECT GUTENBERG EBOOK',
      'End of Project Gutenberg',
      'End of the Project Gutenberg',
    ];

    var start = 0;
    for (final m in startMarkers) {
      final i = text.indexOf(m);
      if (i != -1) {
        final newline = text.indexOf('\n', i);
        start = newline != -1 ? newline + 1 : i + m.length;
        break;
      }
    }

    var end = text.length;
    for (final m in endMarkers) {
      final i = text.indexOf(m, start);
      if (i != -1 && i < end) {
        end = i;
      }
    }

    return text.substring(start, end).trim();
  }
}
