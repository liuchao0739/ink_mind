import 'package:flutter/widgets.dart';

/// 表示一页在整段正文中的起止位置（半开区间 [start, end)）。
class PageSlice {
  const PageSlice({
    required this.start,
    required this.end,
  });

  final int start;
  final int end;
}

/// 简单的分页工具，根据给定的样式与可用区域，将一整段文本拆分为多页。
class PageComposer {
  const PageComposer._();

  /// 将 [text] 按照 [style]、可用宽高等信息分页。
  ///
  /// [maxWidth] / [maxHeight] 是整个可用区域的尺寸，
  /// [padding] 为内容区内边距，分页计算会扣除该内边距。
  static List<PageSlice> paginate({
    required String text,
    required TextStyle style,
    required double maxWidth,
    required double maxHeight,
    EdgeInsets padding = EdgeInsets.zero,
  }) {
    if (text.isEmpty) {
      return const <PageSlice>[];
    }
    if (maxWidth <= 0 || maxHeight <= 0) {
      return <PageSlice>[
        PageSlice(start: 0, end: text.length),
      ];
    }

    final contentWidth = maxWidth - padding.horizontal;
    final contentHeight = maxHeight - padding.vertical;
    if (contentWidth <= 0 || contentHeight <= 0) {
      return <PageSlice>[
        PageSlice(start: 0, end: text.length),
      ];
    }

    final painter = TextPainter(
      textDirection: TextDirection.ltr,
      maxLines: null,
    );

    final slices = <PageSlice>[];
    var start = 0;

    while (start < text.length) {
      final span = TextSpan(
        text: text.substring(start),
        style: style,
      );
      painter.text = span;
      painter.layout(maxWidth: contentWidth);

      // 估算当前页在给定高度内能容纳的最大 offset。
      final position = painter.getPositionForOffset(
        Offset(contentWidth, contentHeight),
      );
      var relativeEnd = position.offset;

      // 防止极端情况下 offset 为 0 导致死循环，至少向前推进 1 个字符。
      if (relativeEnd <= 0) {
        relativeEnd = 1;
      }

      var end = start + relativeEnd;
      if (end > text.length) {
        end = text.length;
      }

      slices.add(PageSlice(start: start, end: end));
      start = end;
    }

    return slices;
  }
}

