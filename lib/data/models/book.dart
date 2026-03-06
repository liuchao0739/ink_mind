enum BookSourceType {
  asset,
  localFile,
  publicDomainApi,
  copyrightLink,
}

class Book {
  const Book({
    required this.id,
    required this.title,
    required this.author,
    required this.category,
    this.coverAsset,
    this.tags = const [],
    this.wordCount = 0,
    this.status = 'ongoing',
    this.intro = '',
    this.sourceType = BookSourceType.asset,
    this.heatScore = 0,
    this.remoteApiId,
    this.externalUrl,
    this.detailAsset,
    this.localFilePath,
  });

  final String id;
  final String title;
  final String author;
  final String category;
  final String? coverAsset;
  final List<String> tags;
  final int wordCount;
  final String status;
  final String intro;
  final BookSourceType sourceType;
  final int heatScore;
  final String? remoteApiId;
  final String? externalUrl;
  final String? detailAsset;
  /// 本地导入书籍时的文件路径，仅在 [BookSourceType.localFile] 下有意义。
  final String? localFilePath;

  Book copyWith({
    String? id,
    String? title,
    String? author,
    String? category,
    String? coverAsset,
    List<String>? tags,
    int? wordCount,
    String? status,
    String? intro,
    BookSourceType? sourceType,
    int? heatScore,
    String? remoteApiId,
    String? externalUrl,
    String? detailAsset,
    String? localFilePath,
  }) {
    return Book(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      category: category ?? this.category,
      coverAsset: coverAsset ?? this.coverAsset,
      tags: tags ?? this.tags,
      wordCount: wordCount ?? this.wordCount,
      status: status ?? this.status,
      intro: intro ?? this.intro,
      sourceType: sourceType ?? this.sourceType,
      heatScore: heatScore ?? this.heatScore,
      remoteApiId: remoteApiId ?? this.remoteApiId,
      externalUrl: externalUrl ?? this.externalUrl,
      detailAsset: detailAsset ?? this.detailAsset,
      localFilePath: localFilePath ?? this.localFilePath,
    );
  }

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      id: json['id'] as String,
      title: json['title'] as String,
      author: json['author'] as String? ?? '',
      category: json['category'] as String? ?? '',
      coverAsset: json['coverAsset'] as String?,
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
              const [],
      wordCount: json['wordCount'] as int? ?? 0,
      status: json['status'] as String? ?? 'ongoing',
      intro: json['intro'] as String? ?? '',
      sourceType: _parseSourceType(json['sourceType'] as String?),
      heatScore: json['heatScore'] as int? ?? 0,
      remoteApiId: json['remoteApiId'] as String?,
      externalUrl: json['externalUrl'] as String?,
      detailAsset: json['detailAsset'] as String?,
      localFilePath: json['localFilePath'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'category': category,
      'coverAsset': coverAsset,
      'tags': tags,
      'wordCount': wordCount,
      'status': status,
      'intro': intro,
      'sourceType': sourceType.name,
      'heatScore': heatScore,
      'remoteApiId': remoteApiId,
      'externalUrl': externalUrl,
      'detailAsset': detailAsset,
      'localFilePath': localFilePath,
    };
  }

  static BookSourceType _parseSourceType(String? value) {
    switch (value) {
      case 'asset':
        return BookSourceType.asset;
      case 'localFile':
        return BookSourceType.localFile;
      case 'publicDomainApi':
        return BookSourceType.publicDomainApi;
      case 'copyrightLink':
        return BookSourceType.copyrightLink;
      default:
        return BookSourceType.asset;
    }
  }
}

