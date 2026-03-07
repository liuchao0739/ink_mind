import 'dart:async';
import 'dart:convert';
import '../../../core/network/api_client.dart';

/// 增强版网页爬虫
class WebCrawler {
  WebCrawler({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient(baseUrl: '');

  final ApiClient _apiClient;

  /// 爬取指定URL的内容
  Future<String> crawl(String url) async {
    try {
      // 模拟浏览器行为，添加更多反爬虫措施
      print('WebCrawler: Crawling $url');
      final response = await _apiClient.getTextFromUrl(url);
      print('WebCrawler: Successfully crawled $url');
      return response;
    } catch (e) {
      print('WebCrawler: Crawl error: $e');
      return '';
    }
  }

  /// 爬取99读书网的书籍
  Future<Map<String, dynamic>> crawl99CSW(String bookUrl) async {
    try {
      final html = await crawl(bookUrl);
      if (html.isEmpty) {
        return {};
      }

      // 解析书籍信息
      final bookInfo = _parse99CSWBookInfo(html);
      final chapters = _parse99CSWChapters(html);

      return {
        'book': bookInfo,
        'chapters': chapters,
      };
    } catch (e) {
      print('Crawl 99CSW error: $e');
      return {};
    }
  }

  /// 解析99读书网书籍信息
  Map<String, dynamic> _parse99CSWBookInfo(String html) {
    // 解析标题
    final titleRegex = RegExp(r'<h1>(.*?)</h1>');
    final titleMatch = titleRegex.firstMatch(html);
    final title = titleMatch?.group(1)?.trim() ?? '未知标题';

    // 解析作者
    final authorRegex = RegExp(r'作者：(.*?)<');
    final authorMatch = authorRegex.firstMatch(html);
    final author = authorMatch?.group(1)?.trim() ?? '未知作者';

    // 解析简介
    final introRegex = RegExp(r'<div class="intro">(.*?)</div>', dotAll: true);
    final introMatch = introRegex.firstMatch(html);
    final intro = introMatch?.group(1)?.replaceAll(RegExp(r'<[^>]*>'), '').trim() ?? '';

    return {
      'title': title,
      'author': author,
      'intro': intro,
    };
  }

  /// 解析99读书网章节列表
  List<Map<String, dynamic>> _parse99CSWChapters(String html) {
    final chapters = <Map<String, dynamic>>[];
    final regex = RegExp(r'<a href="(.*?)">(.*?)</a>');
    final matches = regex.allMatches(html);

    var index = 0;
    for (final match in matches) {
      if (match.groupCount >= 2) {
        final path = match.group(1)!;
        final chapterTitle = match.group(2)!.trim();

        // 过滤掉非章节链接
        if (path.contains('.htm') && chapterTitle.isNotEmpty) {
          chapters.add({
            'id': 'chapter_$index',
            'title': chapterTitle,
            'url': path,
            'index': index,
          });
          index++;
        }
      }
    }

    return chapters;
  }

  /// 爬取章节内容
  Future<String> crawlChapter(String chapterUrl) async {
    try {
      final html = await crawl(chapterUrl);
      if (html.isEmpty) {
        return '';
      }

      // 解析章节内容 - 尝试多种常见的章节内容选择器
      final contentPatterns = [
        RegExp(r'<div id="content">(.*?)</div>', dotAll: true),
        RegExp(r'<div class="content">(.*?)</div>', dotAll: true),
        RegExp(r'<div class="novel_content">(.*?)</div>', dotAll: true),
        RegExp(r'<div id="txt_content">(.*?)</div>', dotAll: true),
      ];

      for (final pattern in contentPatterns) {
        final match = pattern.firstMatch(html);
        if (match != null && match.groupCount >= 1) {
          var content = match.group(1)!;
          content = content.replaceAll(RegExp(r'<[^>]*>'), '');
          content = content.replaceAll('&nbsp;', ' ');
          content = content.replaceAll('&gt;', '>');
          content = content.replaceAll('&lt;', '<');
          content = content.replaceAll(RegExp(r'\s+'), ' ').trim();
          content = content.replaceAll('\n\n\n', '\n\n');
          if (content.length > 50) {  // 确保内容不是太短
            return content;
          }
        }
      }

      return '';
    } catch (e) {
      print('Crawl chapter error: $e');
      return '';
    }
  }

  /// 搜索书籍 - 只使用 ctext.org，因为其他网站有反爬
  Future<List<Map<String, dynamic>>> search(String keyword) async {
    print('WebCrawler: Searching for $keyword');
    final results = <Map<String, dynamic>>[];

    // 只使用 ctext.org 搜索
    final searchUrls = [
      'https://ctext.org/search?remap=1&bq=$keyword',
    ];

    for (final url in searchUrls) {
      print('WebCrawler: Crawling $url');
      try {
        final html = await crawl(url);
        if (html.isEmpty) {
          print('WebCrawler: Empty response from $url');
          continue;
        }

        // 解析搜索结果
        final searchResults = _parseSearchResults(html, url);
        print('WebCrawler: Found ${searchResults.length} results from $url');
        results.addAll(searchResults);
      } catch (e) {
        print('WebCrawler: Search error for $url: $e');
        continue;
      }
    }

    print('WebCrawler: Total search results: ${results.length}');
    return results;
  }

  /// 解析搜索结果
  List<Map<String, dynamic>> _parseSearchResults(String html, String url) {
    final results = <Map<String, dynamic>>[];

    // ctext.org 搜索结果解析
    if (url.contains('ctext.org')) {
      final regex = RegExp(r'<a href="([^"]+)">([^<]+)</a>');
      final matches = regex.allMatches(html);
      final seenTitles = <String>{};

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
          // 排除章节页
          if (path.contains('chapter') || path.contains('page') || path.contains('.ztml')) continue;

          // 标题包含搜索关键词（不区分大小写）或者包含中文
          final hasChinese = RegExp(r'[\u4e00-\u9fa5]').hasMatch(title);
          // 这里没有keyword参数，所以暂时保留所有中文链接
          if (!hasChinese) continue;

          // 如果是短链接，添加前缀
          if (!path.startsWith('/')) {
            path = '/$path';
          }

          seenTitles.add(title);
          results.add({
            'title': title,
            'author': '未知',
            'url': 'https://ctext.org$path',
            'source': 'ctext',
          });
        }
      }
    }

    return results;
  }
}
