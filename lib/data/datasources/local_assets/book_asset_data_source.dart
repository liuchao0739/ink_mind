import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../../data/models/book.dart';
import '../../../data/models/chapter.dart';

class BookAssetDataSource {
  const BookAssetDataSource();

  Future<List<Book>> loadCatalog() async {
    final raw = await rootBundle.loadString('assets/books/catalog.json');
    final jsonMap = json.decode(raw) as Map<String, dynamic>;
    final booksJson = jsonMap['books'] as List<dynamic>? ?? [];
    return booksJson
        .map((e) => Book.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<(Book, List<Chapter>)> loadBookDetail(String detailAssetPath) async {
    final raw = await rootBundle.loadString(detailAssetPath);
    final jsonMap = json.decode(raw) as Map<String, dynamic>;
    final bookJson = jsonMap['book'] as Map<String, dynamic>;
    final chaptersJson = jsonMap['chapters'] as List<dynamic>? ?? [];
    final book = Book.fromJson(bookJson);
    final chapters = chaptersJson
        .map((e) => Chapter.fromJson(e as Map<String, dynamic>))
        .toList();
    return (book, chapters);
  }
}

