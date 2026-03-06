class Chapter {
  const Chapter({
    required this.id,
    required this.bookId,
    required this.index,
    required this.title,
    this.content,
    this.contentAssetPath,
  });

  final String id;
  final String bookId;
  final int index;
  final String title;

  /// Optional inline content for small demo chapters.
  final String? content;

  /// For larger books, content can live in a separate asset or file.
  final String? contentAssetPath;

  Chapter copyWith({
    String? id,
    String? bookId,
    int? index,
    String? title,
    String? content,
    String? contentAssetPath,
  }) {
    return Chapter(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      index: index ?? this.index,
      title: title ?? this.title,
      content: content ?? this.content,
      contentAssetPath: contentAssetPath ?? this.contentAssetPath,
    );
  }

  factory Chapter.fromJson(Map<String, dynamic> json) {
    return Chapter(
      id: json['id'] as String,
      bookId: json['bookId'] as String,
      index: json['index'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      content: json['content'] as String?,
      contentAssetPath: json['contentAssetPath'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bookId': bookId,
      'index': index,
      'title': title,
      'content': content,
      'contentAssetPath': contentAssetPath,
    };
  }
}

