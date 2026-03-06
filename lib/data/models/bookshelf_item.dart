class BookshelfItem {
  const BookshelfItem({
    required this.bookId,
    required this.addedAtMillis,
    this.lastReadAtMillis,
    this.pinTop = false,
    this.groupName,
  });

  final String bookId;
  final int addedAtMillis;
  final int? lastReadAtMillis;
  final bool pinTop;
  final String? groupName;

  BookshelfItem copyWith({
    String? bookId,
    int? addedAtMillis,
    int? lastReadAtMillis,
    bool? pinTop,
    String? groupName,
  }) {
    return BookshelfItem(
      bookId: bookId ?? this.bookId,
      addedAtMillis: addedAtMillis ?? this.addedAtMillis,
      lastReadAtMillis: lastReadAtMillis ?? this.lastReadAtMillis,
      pinTop: pinTop ?? this.pinTop,
      groupName: groupName ?? this.groupName,
    );
  }

  factory BookshelfItem.fromJson(Map<String, dynamic> json) {
    return BookshelfItem(
      bookId: json['bookId'] as String,
      addedAtMillis: json['addedAtMillis'] as int? ?? 0,
      lastReadAtMillis: json['lastReadAtMillis'] as int?,
      pinTop: json['pinTop'] as bool? ?? false,
      groupName: json['groupName'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bookId': bookId,
      'addedAtMillis': addedAtMillis,
      'lastReadAtMillis': lastReadAtMillis,
      'pinTop': pinTop,
      'groupName': groupName,
    };
  }
}

