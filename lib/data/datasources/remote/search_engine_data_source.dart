import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import '../../models/book.dart';
import '../../models/chapter.dart';
import 'universal_book_data_source.dart';

/// 搜索引擎数据源抽象类
abstract class SearchEngineDataSource extends UniversalBookDataSource {
  Future<List<SearchResult>> searchWeb(String keyword);
  Future<BookContent> fetchWebContent(String url);
}

/// 搜索结果模型
class SearchResult {
  final String title;
  final String url;
  final String? snippet;
  final String source;
  final DateTime? publishedDate;

  SearchResult({
    required this.title,
    required this.url,
    this.snippet,
    required this.source,
    this.publishedDate,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'url': url,
    'snippet': snippet,
    'source': source,
    'publishedDate': publishedDate?.toIso8601String(),
  };

  factory SearchResult.fromJson(Map<String, dynamic> json) => SearchResult(
    title: json['title'],
    url: json['url'],
    snippet: json['snippet'],
    source: json['source'],
    publishedDate: json['publishedDate'] != null 
      ? DateTime.parse(json['publishedDate']) 
      : null,
  );
}

/// 网页内容模型
class BookContent {
  final String title;
  final String? author;
  final String content;
  final String url;
  final DateTime fetchedAt;
  final List<Chapter>? chapters;

  BookContent({
    required this.title,
    this.author,
    required this.content,
    required this.url,
    required this.fetchedAt,
    this.chapters,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'author': author,
    'content': content,
    'url': url,
    'fetchedAt': fetchedAt.toIso8601String(),
    'chapters': chapters?.map((c) => c.toJson()).toList(),
  };
}
