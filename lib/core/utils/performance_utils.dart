import 'dart:async';
import 'dart:developer';
import 'package:flutter/foundation.dart';

/// 性能监控工具
class PerformanceMonitor {
  PerformanceMonitor._privateConstructor();
  static final PerformanceMonitor _instance = PerformanceMonitor._privateConstructor();
  factory PerformanceMonitor() => _instance;

  final Map<String, Stopwatch> _timers = {};
  final Map<String, int> _callCounts = {};
  final Map<String, List<int>> _executionTimes = {};

  /// 开始计时
  void startTimer(String key) {
    _timers[key] = Stopwatch()..start();
  }

  /// 结束计时并返回执行时间（毫秒）
  int stopTimer(String key) {
    final stopwatch = _timers[key];
    if (stopwatch == null) {
      return 0;
    }
    stopwatch.stop();
    final elapsed = stopwatch.elapsedMilliseconds;
    _timers.remove(key);
    
    // 记录执行时间
    if (!_executionTimes.containsKey(key)) {
      _executionTimes[key] = [];
    }
    _executionTimes[key]!.add(elapsed);
    
    // 增加调用计数
    _callCounts[key] = (_callCounts[key] ?? 0) + 1;
    
    // 打印执行时间（仅在开发模式下）
    if (kDebugMode) {
      print('[$key] 执行时间: $elapsed ms');
    }
    
    return elapsed;
  }

  /// 记录方法执行
  Future<T> measure<T>(String key, Future<T> Function() function) async {
    startTimer(key);
    try {
      return await function();
    } finally {
      stopTimer(key);
    }
  }

  /// 同步方法执行时间测量
  T measureSync<T>(String key, T Function() function) {
    startTimer(key);
    try {
      return function();
    } finally {
      stopTimer(key);
    }
  }

  /// 获取性能报告
  Map<String, dynamic> getPerformanceReport() {
    final report = <String, dynamic>{};
    
    _executionTimes.forEach((key, times) {
      if (times.isEmpty) return;
      
      times.sort();
      final count = times.length;
      final total = times.reduce((a, b) => a + b);
      final average = total ~/ count;
      final min = times.first;
      final max = times.last;
      
      report[key] = {
        'count': count,
        'total': total,
        'average': average,
        'min': min,
        'max': max,
      };
    });
    
    return report;
  }

  /// 打印性能报告
  void printPerformanceReport() {
    final report = getPerformanceReport();
    if (report.isEmpty) {
      print('性能报告：暂无数据');
      return;
    }
    
    print('\n=== 性能报告 ===');
    report.forEach((key, data) {
      print('$key:');
      print('  调用次数: ${data['count']}');
      print('  总时间: ${data['total']} ms');
      print('  平均时间: ${data['average']} ms');
      print('  最小时间: ${data['min']} ms');
      print('  最大时间: ${data['max']} ms');
    });
    print('=== 性能报告结束 ===\n');
  }

  /// 重置性能数据
  void reset() {
    _timers.clear();
    _callCounts.clear();
    _executionTimes.clear();
  }
}

/// 并发处理工具
class ConcurrencyUtils {
  /// 并发执行任务
  static Future<List<T>> parallel<T>(List<Future<T>> futures) async {
    return await Future.wait(futures);
  }

  /// 限制并发数执行任务
  static Future<List<T>> limitedParallel<T>(
    List<Future<T> Function()> tasks,
    int concurrencyLimit,
  ) async {
    final results = <T>[];
    final running = <Future<T>>[];
    final pending = List.from(tasks);

    while (pending.isNotEmpty || running.isNotEmpty) {
      // 启动新任务
      while (pending.isNotEmpty && running.length < concurrencyLimit) {
        final task = pending.removeAt(0);
        final future = task();
        running.add(future);
      }

      // 等待任一任务完成
      if (running.isNotEmpty) {
        final completed = await Future.any(running);
        results.add(completed);
        // 重新创建running列表，移除已完成的任务
        running.removeWhere((f) => f == completed);
      }
    }

    return results;
  }

  /// 分批处理任务
  static Future<List<T>> batchProcess<T>(
    List<dynamic> items,
    Future<T> Function(dynamic) processFunction,
    int batchSize,
  ) async {
    final results = <T>[];
    for (int i = 0; i < items.length; i += batchSize) {
      final batch = items.sublist(
        i,
        i + batchSize > items.length ? items.length : i + batchSize,
      );
      final batchResults = await Future.wait(batch.map(processFunction));
      results.addAll(batchResults);
    }
    return results;
  }
}

/// 内存管理工具
class MemoryUtils {
  /// 强制垃圾回收
  static void forceGC() {
    if (kDebugMode) {
      // 在开发模式下触发垃圾回收
      // 注意：这只是一个提示，不能保证立即执行
      Timeline.startSync('GC');
      Timeline.finishSync();
    }
  }

  /// 检查内存使用情况（仅在开发模式下）
  static void checkMemoryUsage() {
    if (kDebugMode) {
      // 这里可以添加内存使用情况的检查逻辑
      // 例如使用 dart:developer 中的内存分析工具
      print('内存使用情况检查');
    }
  }
}
