import 'dart:convert';

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

/// 非常轻量的 HTTP 客户端封装，统一超时与日志。
class ApiClient {
  ApiClient({
    required String baseUrl,
    Dio? dio,
  }) : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl,
                connectTimeout: const Duration(seconds: 5),
                receiveTimeout: const Duration(seconds: 20),
                sendTimeout: const Duration(seconds: 10),
                responseType: ResponseType.json,
              ),
            ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
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
  }

  final Dio _dio;

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? query,
  }) async {
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
        final decoded =
            json.decode(response.data as String) as Map<String, dynamic>;
        return decoded;
      }

      throw ApiException(
        'Response is not a JSON object',
        statusCode: status,
        url: response.requestOptions.uri.toString(),
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      throw ApiException(
        e.message ?? 'Network error',
        statusCode: status,
        url: e.requestOptions.uri.toString(),
        cause: e,
      );
    } catch (e) {
      throw ApiException(
        'Unknown error: $e',
        url: path,
        cause: e,
      );
    }
  }

  Future<String> getTextFromUrl(String url) async {
    try {
      final response = await _dio.get<String>(
        url,
        options: Options(
          responseType: ResponseType.plain,
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
      final status = e.response?.statusCode;
      throw ApiException(
        e.message ?? 'Network error',
        statusCode: status,
        url: e.requestOptions.uri.toString(),
        cause: e,
      );
    } catch (e) {
      throw ApiException(
        'Unknown error: $e',
        url: url,
        cause: e,
      );
    }
  }
}

