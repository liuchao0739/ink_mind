class ReadingStats {
  const ReadingStats({
    required this.dateString,
    this.minutes = 0,
    this.words = 0,
    this.booksRead = 0,
    this.mainCategories = const [],
  });

  /// Date in yyyy-MM-dd format.
  final String dateString;
  final int minutes;
  final int words;
  final int booksRead;
  final List<String> mainCategories;

  ReadingStats copyWith({
    String? dateString,
    int? minutes,
    int? words,
    int? booksRead,
    List<String>? mainCategories,
  }) {
    return ReadingStats(
      dateString: dateString ?? this.dateString,
      minutes: minutes ?? this.minutes,
      words: words ?? this.words,
      booksRead: booksRead ?? this.booksRead,
      mainCategories: mainCategories ?? this.mainCategories,
    );
  }

  factory ReadingStats.fromJson(Map<String, dynamic> json) {
    return ReadingStats(
      dateString: json['dateString'] as String,
      minutes: json['minutes'] as int? ?? 0,
      words: json['words'] as int? ?? 0,
      booksRead: json['booksRead'] as int? ?? 0,
      mainCategories: (json['mainCategories'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dateString': dateString,
      'minutes': minutes,
      'words': words,
      'booksRead': booksRead,
      'mainCategories': mainCategories,
    };
  }
}

