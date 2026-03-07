import 'package:dio/dio.dart';
import '../../models/book.dart';
import '../../models/chapter.dart';
import '../../../core/network/api_client.dart';
import 'novel_book_data_source.dart';

/// 中国哲学书电子化计划数据源 (ctext.org)
/// 提供大量中文古籍，公益性无反爬
class CtextDataSource implements NovelBookDataSource {
  CtextDataSource({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient(baseUrl: _baseUrl);

  static const String _baseUrl = 'https://ctext.org';
  final ApiClient _apiClient;

  /// CookieJar 用于维护会话
  final Map<String, List<String>> _cookies = {};

  /// 创建一个带自定义 headers 的 Dio 实例用于 ctext.org
  Dio _createCtextDio({String? referer}) {
    final dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 60),
        responseType: ResponseType.plain,
        validateStatus: (status) => status != null && status < 500,
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
          'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
          'Accept-Encoding': 'gzip, deflate, br',
          'Connection': 'keep-alive',
          'Referer': referer ?? '$_baseUrl/',
          'Sec-Fetch-Dest': 'document',
          'Sec-Fetch-Mode': 'navigate',
          'Sec-Fetch-Site': 'same-origin',
          'Sec-Fetch-User': '?1',
          'Upgrade-Insecure-Requests': '1',
        },
      ),
    );

    // 添加 cookie 拦截器
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final host = options.uri.host;
        if (_cookies.containsKey(host)) {
          options.headers['Cookie'] = _cookies[host]!.join('; ');
        }
        handler.next(options);
      },
      onResponse: (response, handler) {
        final host = response.requestOptions.uri.host;
        final setCookie = response.headers['set-cookie'];
        if (setCookie != null && setCookie.isNotEmpty) {
          _cookies[host] = setCookie;
        }
        handler.next(response);
      },
    ));

    return dio;
  }

  /// 先访问书籍主页建立会话，再访问章节
  Future<String> _fetchWithSession(String url, String bookUrl) async {
    try {
      // 第一步：访问书籍主页建立会话
      final sessionDio = _createCtextDio(referer: '$_baseUrl/');
      await sessionDio.get(bookUrl);

      // 第二步：访问章节页
      final chapterDio = _createCtextDio(referer: bookUrl);
      final response = await chapterDio.get(url);

      if (response.statusCode == 200) {
        return response.data ?? '';
      } else {
        print('Ctext: Chapter request returned status ${response.statusCode}');
        return '';
      }
    } catch (e) {
      print('Ctext: _fetchWithSession error: $e');
      return '';
    }
  }

  @override
  Future<List<Book>> searchRemote(String keyword) async {
    if (keyword.trim().isEmpty) return const [];

    try {
      print('Ctext: Searching for $keyword');
      final encodedKeyword = Uri.encodeComponent(keyword);
      final url = '$_baseUrl/search?remap=1&bq=$encodedKeyword';

      final response = await _apiClient.getTextFromUrl(url);
      final books = _parseSearchResults(response, keyword);
      print('Ctext: Found ${books.length} books');
      return books;
    } catch (e) {
      print('Ctext: Search error: $e');
      return const [];
    }
  }

  List<Book> _parseSearchResults(String html, String keyword) {
    final books = <Book>[];
    final seenTitles = <String>{};

    // ctext.org 搜索结果解析
    // 格式1: <a href="hongloumeng">红楼梦</a> (短链接)
    // 格式2: <a href="/books/zhs">红楼梦</a> (完整路径)
    // 格式3: <a href="/texts/zhs/000.ztml">红楼梦</a> (章节)
    final regex = RegExp(r'<a href="([^"]+)">([^<]+)</a>');
    final matches = regex.allMatches(html);

    for (final match in matches) {
      if (match.groupCount >= 2) {
        var path = match.group(1) ?? '';
        final title = match.group(2)?.trim() ?? '';

        // 过滤无效链接
        if (path.isEmpty || title.isEmpty || title.length < 2) continue;
        if (seenTitles.contains(title)) continue;

        // 排除工具页面
        if (path.startsWith('/tools/') || path.startsWith('/board/') || path.startsWith('/area/')) continue;
        // 排除导航链接
        if (title.contains('上一章') || title.contains('下一章')) continue;
        if (title.contains('第') && title.contains('章')) continue;

        // 如果是短链接，添加前缀
        if (!path.startsWith('/')) {
          path = '/$path';
        }

        // 排除章节页
        if (path.contains('chapter') || path.contains('page') || path.contains('.ztml')) continue;

        // 标题包含搜索关键词（不区分大小写）
        final keywordLower = keyword.toLowerCase();
        final titleLower = title.toLowerCase();

        // 匹配关键词或者包含中文
        final hasChinese = RegExp(r'[\u4e00-\u9fa5]').hasMatch(title);
        final isMatch = titleLower.contains(keywordLower) || keywordLower.contains(titleLower) || hasChinese;

        if (!isMatch) continue;

        seenTitles.add(title);

        books.add(Book(
          id: 'ctext_${path.replaceAll('/', '_')}',
          title: title,
          author: '未知',
          category: '古籍',
          intro: '来自中国哲学书电子化计划 (ctext.org)',
          sourceType: BookSourceType.publicDomainApi,
          remoteApiId: path,
          heatScore: 0,
        ));

        if (books.length >= 10) break;
      }
    }

    return books;
  }

  @override
  Future<(Book, List<Chapter>)> fetchPublicDomainBook(String apiBookId) async {
    try {
      final book = await fetchNovelDetail(apiBookId);
      final chapters = await fetchChapterList(apiBookId);
      return (book, chapters);
    } catch (e) {
      return (
        const Book(id: '', title: '', author: '', category: ''),
        <Chapter>[],
      );
    }
  }

  @override
  Future<Book> fetchNovelDetail(String bookId) async {
    try {
      // 确保 bookId 以 / 开头
      final fullPath = bookId.startsWith('/') ? bookId : '/$bookId';
      final url = '$_baseUrl$fullPath';
      final response = await _apiClient.getTextFromUrl(url);

      final titleRegex = RegExp(r'<title>(.+?) - Chinese Text Project</title>');
      final titleMatch = titleRegex.firstMatch(response);
      final title = titleMatch?.group(1)?.trim() ?? '未知标题';

      return Book(
        id: 'ctext_${bookId.replaceAll('/', '_')}',
        title: title,
        author: '未知',
        category: '古籍',
        intro: '来自中国哲学书电子化计划',
        sourceType: BookSourceType.publicDomainApi,
        remoteApiId: bookId,
      );
    } catch (e) {
      throw Exception('Failed to fetch book detail: $e');
    }
  }

  @override
  Future<List<Chapter>> fetchChapterList(String bookId) async {
    try {
      // 确保 bookId 以 / 开头
      final fullPath = bookId.startsWith('/') ? bookId : '/$bookId';
      final url = '$_baseUrl$fullPath';
      final response = await _apiClient.getTextFromUrl(url);

      final chapters = <Chapter>[];
      // 使用更宽松的正则来匹配链接
      final regex = RegExp(r'<a[^>]+href="([^"]+)"[^>]*>([^<]*)</a>', dotAll: true);
      final matches = regex.allMatches(response);
      print('Ctext: Found ${matches.length} total link matches');

      var index = 0;
      for (final match in matches) {
        if (match.groupCount >= 2) {
          final path = match.group(1) ?? '';
          final title = match.group(2)?.trim() ?? '';

          // 调试输出
          if (index < 5) {
            print('Ctext: Link[$index]: path=$path, title=$title');
          }

          // 过滤：必须是章节链接（包含/ch）
          if (path.isEmpty || title.isEmpty) continue;
          if (!path.contains('/ch')) continue;
          if (title.contains('上一章') || title.contains('下一章')) continue;
          if (!RegExp(r'[\u4e00-\u9fa5]').hasMatch(title)) continue;

          // 添加前导斜杠以形成完整路径
          final fullPath = '/$path';

          chapters.add(Chapter(
            id: 'ctext_chapter_${fullPath.replaceAll('/', '_')}',
            bookId: 'ctext_${bookId.replaceAll('/', '_')}',
            index: index,
            title: title,
            content: '',
          ));

          index++;
          if (index >= 120) break;
        }
      }

      print('Ctext: Parsed $index chapters');
      return chapters;
    } catch (e) {
      return const [];
    }
  }

  @override
  Future<String> fetchChapterContent(String chapterId, String bookId) async {
    try {
      // 转换 chapterId 到实际路径
      // chapterId 格式: ctext_chapter__hongloumeng_ch1 -> hongloumeng/ch1
      String path;
      if (chapterId.startsWith('ctext_chapter_')) {
        // 去掉前缀，把 _ 转换回 /
        final pathPart = chapterId.substring('ctext_chapter_'.length);
        path = pathPart.replaceAll('_', '/');
      } else {
        path = chapterId.startsWith('/') ? chapterId.substring(1) : chapterId;
      }
      // 移除可能存在的开头斜杠
      if (path.startsWith('/')) {
        path = path.substring(1);
      }
      // 直接拼接 URL
      final url = '$_baseUrl/$path';
      print('Ctext: Fetching chapter from URL: $url');

      // 从 bookId 提取书籍路径
      String bookPath = bookId;
      if (bookId.startsWith('ctext_')) {
        bookPath = bookId.substring('ctext_'.length).replaceAll('_', '/');
      }
      // 确保 bookPath 以 / 开头
      if (!bookPath.startsWith('/')) {
        bookPath = '/$bookPath';
      }
      final bookUrl = '$_baseUrl$bookPath';

      // 使用带会话的请求方式
      final responseText = await _fetchWithSession(url, bookUrl);
      if (responseText.isEmpty) {
        return '';
      }

      final patterns = [
        RegExp(r'<div id="content2">(.+?)</div>\s*<div', dotAll: true),
        RegExp(r'<div class="ctext">(.+?)</div>', dotAll: true),
        RegExp(r'<div class="main">(.+?)</div>', dotAll: true),
      ];

      for (final pattern in patterns) {
        final match = pattern.firstMatch(responseText);
        if (match != null && match.groupCount >= 1) {
          var content = match.group(1)!;
          content = content.replaceAll(RegExp(r'<br\s*/?>'), '\n');
          content = content.replaceAll(RegExp(r'<[^>]*>'), '');
          content = content.replaceAll('&nbsp;', ' ');
          content = content.replaceAll(RegExp(r'\n{3,}'), '\n\n');
          content = content.trim();

          if (content.length > 50) {
            return content;
          }
        }
      }

      return '';
    } catch (e) {
      print('Ctext: Fetch chapter content error: $e');
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
}
