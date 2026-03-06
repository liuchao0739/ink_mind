class AiHighlight {
  const AiHighlight({
    required this.bookId,
    required this.chapterIndex,
    this.sentences = const [],
    this.summary,
  });

  final String bookId;
  final int chapterIndex;
  final List<String> sentences;
  final String? summary;

  AiHighlight copyWith({
    String? bookId,
    int? chapterIndex,
    List<String>? sentences,
    String? summary,
  }) {
    return AiHighlight(
      bookId: bookId ?? this.bookId,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      sentences: sentences ?? this.sentences,
      summary: summary ?? this.summary,
    );
  }

  factory AiHighlight.fromJson(Map<String, dynamic> json) {
    return AiHighlight(
      bookId: json['bookId'] as String,
      chapterIndex: json['chapterIndex'] as int? ?? 0,
      sentences: (json['sentences'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      summary: json['summary'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bookId': bookId,
      'chapterIndex': chapterIndex,
      'sentences': sentences,
      'summary': summary,
    };
  }
}

