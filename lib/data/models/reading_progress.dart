class ReadingProgress {
  const ReadingProgress({
    required this.bookId,
    required this.chapterIndex,
    required this.updatedAtMillis,
    this.scrollOffset = 0.0,
    this.pageIndex,
  });

  final String bookId;
  final int chapterIndex;
  final double scrollOffset;
  final int? pageIndex;
  final int updatedAtMillis;

  ReadingProgress copyWith({
    String? bookId,
    int? chapterIndex,
    double? scrollOffset,
    int? pageIndex,
    int? updatedAtMillis,
  }) {
    return ReadingProgress(
      bookId: bookId ?? this.bookId,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      scrollOffset: scrollOffset ?? this.scrollOffset,
      pageIndex: pageIndex ?? this.pageIndex,
      updatedAtMillis: updatedAtMillis ?? this.updatedAtMillis,
    );
  }

  factory ReadingProgress.fromJson(Map<String, dynamic> json) {
    return ReadingProgress(
      bookId: json['bookId'] as String,
      chapterIndex: json['chapterIndex'] as int? ?? 0,
      scrollOffset: (json['scrollOffset'] as num?)?.toDouble() ?? 0.0,
      pageIndex: json['pageIndex'] as int?,
      updatedAtMillis: json['updatedAtMillis'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bookId': bookId,
      'chapterIndex': chapterIndex,
      'scrollOffset': scrollOffset,
      'pageIndex': pageIndex,
      'updatedAtMillis': updatedAtMillis,
    };
  }
}

