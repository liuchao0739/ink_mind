class UserPreference {
  const UserPreference({
    this.isDarkMode = false,
    this.fontSize = 16.0,
    this.lineHeight = 1.5,
    this.ttsRate = 1.0,
  });

  final bool isDarkMode;
  final double fontSize;
  final double lineHeight;
  final double ttsRate;

  UserPreference copyWith({
    bool? isDarkMode,
    double? fontSize,
    double? lineHeight,
    double? ttsRate,
  }) {
    return UserPreference(
      isDarkMode: isDarkMode ?? this.isDarkMode,
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      ttsRate: ttsRate ?? this.ttsRate,
    );
  }

  factory UserPreference.fromJson(Map<String, dynamic> json) {
    return UserPreference(
      isDarkMode: json['isDarkMode'] as bool? ?? false,
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 16.0,
      lineHeight: (json['lineHeight'] as num?)?.toDouble() ?? 1.5,
      ttsRate: (json['ttsRate'] as num?)?.toDouble() ?? 1.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isDarkMode': isDarkMode,
      'fontSize': fontSize,
      'lineHeight': lineHeight,
      'ttsRate': ttsRate,
    };
  }
}

