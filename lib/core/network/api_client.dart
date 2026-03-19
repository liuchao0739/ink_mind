import 'dart:convert';
import 'dart:math';
import 'dart:async';

import 'package:dio/dio.dart';

/// 统一的网络异常类型，便于 UI 和日志识别。
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.url, this.cause});

  final String message;
  final int? statusCode;
  final String? url;
  final Object? cause;

  @override
  String toString() {
    final code = statusCode != null ? ' (HTTP $statusCode)' : '';
    final u = url != null ? ' [$url]' : '';
    return 'ApiException$code$u: $message';
  }
}

/// 网络请求配置类
class NetworkConfig {
  const NetworkConfig({
    this.userAgents = const [],
    this.proxies = const [],
    this.requestInterval = const Duration(milliseconds: 500),
    this.retryCount = 3,
    this.enableCookie = true,
  });

  /// 用户代理列表
  final List<String> userAgents;

  /// 代理列表
  final List<String> proxies;

  /// 请求间隔
  final Duration requestInterval;

  /// 重试次数
  final int retryCount;

  /// 是否启用Cookie
  final bool enableCookie;
}

/// 非常轻量的 HTTP 客户端封装，统一超时与日志，支持反爬措施。
class ApiClient {
  ApiClient({
    required String baseUrl,
    Dio? dio,
    NetworkConfig? config,
  }) : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl,
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 30),
                sendTimeout: const Duration(seconds: 15),
                responseType: ResponseType.json,
              ),
            ),
            _config = config ?? const NetworkConfig() {
    _setupInterceptors();
  }

  final Dio _dio;
  final NetworkConfig _config;
  final Random _random = Random();
  DateTime? _lastRequestTime;

  /// 获取 Dio 实例（用于高级自定义请求）
  Dio get dio => _dio;

  /// 随机获取用户代理
  String _getRandomUserAgent() {
    if (_config.userAgents.isEmpty) {
      // 更丰富的用户代理列表
      return [
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1.1 Safari/605.1.15',
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:89.0) Gecko/20100101 Firefox/89.0',
        'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        'Mozilla/5.0 (iPhone; CPU iPhone OS 14_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1.1 Mobile/15E148 Safari/604.1',
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/92.0.4515.131 Safari/537.36',
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1.2 Safari/605.1.15',
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:90.0) Gecko/20100101 Firefox/90.0',
        'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/92.0.4515.131 Safari/537.36',
        'Mozilla/5.0 (iPhone; CPU iPhone OS 14_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1.2 Mobile/15E148 Safari/604.1',
      ][_random.nextInt(10)];
    }
    return _config.userAgents[_random.nextInt(_config.userAgents.length)];
  }

  /// 随机获取代理
  String? _getRandomProxy() {
    if (_config.proxies.isEmpty) {
      return null;
    }
    return _config.proxies[_random.nextInt(_config.proxies.length)];
  }

  /// 控制请求间隔
  Future<void> _controlRequestInterval() async {
    if (_lastRequestTime != null) {
      final elapsed = DateTime.now().difference(_lastRequestTime!);
      if (elapsed < _config.requestInterval) {
        await Future.delayed(_config.requestInterval - elapsed);
      }
    }
    _lastRequestTime = DateTime.now();
  }

  /// 设置拦截器
  void _setupInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // 控制请求间隔，增加随机性
          await _controlRequestInterval();

          // 设置随机用户代理
          options.headers['User-Agent'] = _getRandomUserAgent();

          // 添加更多的HTTP头，模拟真实浏览器
          options.headers['Accept'] = 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8';
          options.headers['Accept-Language'] = 'zh-CN,zh;q=0.8,en-US;q=0.5,en;q=0.3';
          // 仅在调用方未显式指定时才设置压缩头
          options.headers['Accept-Encoding'] ??= 'gzip, deflate, br';
          options.headers['Connection'] = 'keep-alive';
          options.headers['Upgrade-Insecure-Requests'] = '1';
          options.headers['Cache-Control'] = 'max-age=0';
          
          // 添加Referer头
          options.headers['Referer'] = 'https://www.google.com/';
          
          // 添加Origin头
          if (options.uri.host.isNotEmpty) {
            options.headers['Origin'] = 'https://${options.uri.host}';
          }

          // 设置随机代理
          final proxy = _getRandomProxy();
          if (proxy != null) {
            // Dio 中的代理设置方式
            options.headers['Proxy'] = proxy;
          }

          // 简单控制台日志，方便调试。
          // 直接使用 options.uri，避免 baseUrl + path 在完整 URL 场景下被错误拼接。
          // ignore: avoid_print
          print(
            '[HTTP] → ${options.method} ${options.uri}',
          );
          handler.next(options);
        },
        onResponse: (response, handler) {
          // ignore: avoid_print
          print(
            '[HTTP] ← ${response.statusCode} ${response.requestOptions.method} '
            '${response.requestOptions.uri} '
            '(len=${response.data is String ? (response.data as String).length : response.data.toString().length})',
          );
          handler.next(response);
        },
        onError: (e, handler) {
          // ignore: avoid_print
          print(
            '[HTTP] ✗ ${e.response?.statusCode ?? ''} '
            '${e.requestOptions.method} ${e.requestOptions.uri}: '
            'type=${e.type} message=${e.message} error=${e.error}',
          );
          handler.next(e);
        },
      ),
    );

    // 启用Cookie管理
    if (_config.enableCookie) {
      _dio.interceptors.add(CookieManager(CookieJar()));
    }
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    int retryCount = 0;
    while (true) {
      try {
        final response = await _dio.get<Map<String, dynamic>>(
          path,
          queryParameters: query,
        );
        final status = response.statusCode ?? 0;
        if (status < 200 || status >= 300) {
          throw ApiException(
            'Unexpected status code',
            statusCode: status,
            url: response.requestOptions.uri.toString(),
          );
        }

        final data = response.data;
        if (data != null) {
          return data;
        }

        // 某些服务器会把 JSON 当字符串返回。
        if (response.data is String) {
          final decoded = json.decode(response.data as String) as Map<String, dynamic>;
          return decoded;
        }

        throw ApiException(
          'Response is not a JSON object',
          statusCode: status,
          url: response.requestOptions.uri.toString(),
        );
      } on DioException catch (e) {
        retryCount++;
        if (retryCount <= _config.retryCount) {
          // 等待一段时间后重试
          await Future.delayed(Duration(milliseconds: 1000 * retryCount));
          continue;
        }
        final status = e.response?.statusCode;
        throw ApiException(
          e.message ?? 'Network error',
          statusCode: status,
          url: e.requestOptions.uri.toString(),
          cause: e,
        );
      } catch (e) {
        retryCount++;
        if (retryCount <= _config.retryCount) {
          // 等待一段时间后重试
          await Future.delayed(Duration(milliseconds: 1000 * retryCount));
          continue;
        }
        throw ApiException(
          'Unknown error: $e',
          url: path,
          cause: e,
        );
      }
    }
  }

  Future<String> getTextFromUrl(String url) async {
    int retryCount = 0;
    while (true) {
      try {
        final response = await _dio.get<String>(
          url,
          options: Options(
            responseType: ResponseType.plain,
            headers: {
              // 覆盖拦截器中的 Accept-Encoding，避免收到 brotli/gzip 压缩内容
              'Accept-Encoding': 'identity',
            },
            // 文本下载通常体积较大、服务器在海外，适当放宽超时。
            connectTimeout: const Duration(seconds: 20),
            receiveTimeout: const Duration(seconds: 60),
          ),
        );
        final status = response.statusCode ?? 0;
        if (status < 200 || status >= 300) {
          throw ApiException(
            'Unexpected status code',
            statusCode: status,
            url: response.requestOptions.uri.toString(),
          );
        }
        return response.data ?? '';
      } on DioException catch (e) {
        retryCount++;
        if (retryCount <= _config.retryCount) {
          // 等待一段时间后重试
          await Future.delayed(Duration(milliseconds: 1000 * retryCount));
          continue;
        }
        final status = e.response?.statusCode;
        throw ApiException(
          e.message ?? 'Network error',
          statusCode: status,
          url: e.requestOptions.uri.toString(),
          cause: e,
        );
      } catch (e) {
        retryCount++;
        if (retryCount <= _config.retryCount) {
          // 等待一段时间后重试
          await Future.delayed(Duration(milliseconds: 1000 * retryCount));
          continue;
        }
        throw ApiException(
          'Unknown error: $e',
          url: url,
          cause: e,
        );
      }
    }
  }
}

/// 简单的Cookie管理器
class CookieManager extends Interceptor {
  CookieManager(this.cookieJar);

  final CookieJar cookieJar;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final cookies = cookieJar.getCookies(options.uri.host);
    if (cookies.isNotEmpty) {
      options.headers['Cookie'] = cookies.join('; ');
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final headers = response.headers;
    final cookies = headers['set-cookie'] ?? [];
    for (final cookie in cookies) {
      cookieJar.setCookie(response.requestOptions.uri.host, cookie);
    }
    handler.next(response);
  }
}

/// 简单的Cookie存储
class CookieJar {
  final Map<String, List<String>> _cookies = {};

  void setCookie(String domain, String cookie) {
    if (!_cookies.containsKey(domain)) {
      _cookies[domain] = [];
    }
    _cookies[domain]!.add(cookie);
  }

  List<String> getCookies(String domain) {
    return _cookies[domain] ?? [];
  }

  void clear() {
    _cookies.clear();
  }
}
