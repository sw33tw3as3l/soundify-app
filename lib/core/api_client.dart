import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'token_storage.dart';

const kBaseUrl = 'https://soundify.easyfound.ir/api/v1';

class ApiError implements Exception {
  final String message;
  final int? status;
  final String? code;
  const ApiError(this.message, {this.status, this.code});

  bool get isNetwork => status == null;

  factory ApiError.from(Object e) {
    if (e is ApiError) return e;
    if (e is DioException) {
      final r = e.response;
      if (r == null) {
        final t = e.type;
        if (t == DioExceptionType.connectionTimeout ||
            t == DioExceptionType.receiveTimeout ||
            t == DioExceptionType.sendTimeout) {
          return const ApiError('زمان اتصال به سرور تمام شد. دوباره تلاش کنید.');
        }
        return const ApiError('ارتباط با سرور برقرار نشد. اینترنت خود را بررسی کنید.');
      }
      String? msg;
      String? code;
      final d = r.data;
      if (d is Map) {
        final err = d['error'];
        if (err is Map) {
          msg = err['message']?.toString();
          code = err['code']?.toString();
        } else if (err != null) {
          code = err.toString();
        }
        msg ??= d['message']?.toString() ?? d['detail']?.toString();
        code ??= d['code']?.toString();
      }
      msg ??= switch (r.statusCode) {
        401 => 'نشست شما منقضی شده است.',
        403 => 'دسترسی مجاز نیست.',
        404 => 'مورد نظر پیدا نشد.',
        409 => 'این مورد قبلاً ثبت شده است.',
        429 => 'درخواست‌های زیاد. کمی بعد تلاش کنید.',
        _ => 'خطای سرور (${r.statusCode})',
      };
      return ApiError(msg, status: r.statusCode, code: code);
    }
    return ApiError(e.toString());
  }

  @override
  String toString() => message;
}

/// Dio client: base URL, timeouts, bearer header, error mapping and an
/// interceptor that refreshes an expired access token once and retries.
class ApiClient {
  ApiClient(this.storage) {
    dio = Dio(_options());
    _plain = Dio(_options());
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (o, h) async {
        if (o.extra['auth'] != false) {
          final t = await storage.access;
          if (t != null) o.headers['Authorization'] = 'Bearer $t';
        }
        h.next(o);
      },
      onError: (e, h) async {
        final o = e.requestOptions;
        if (e.response?.statusCode == 401 && o.extra['auth'] != false && o.extra['retried'] != true) {
          final ok = await _refresh();
          if (ok) {
            o.extra['retried'] = true;
            o.headers['Authorization'] = 'Bearer ${await storage.access}';
            try {
              h.resolve(await dio.fetch(o));
            } on DioException catch (e2) {
              h.next(e2);
            }
            return;
          }
          if (_refreshRejected) onSessionExpired?.call();
        }
        h.next(e);
      },
    ));
  }

  final TokenStorage storage;
  late final Dio dio;
  late final Dio _plain;
  Future<bool>? _refreshing;
  bool _refreshRejected = false;
  VoidCallback? onSessionExpired;

  BaseOptions _options() => BaseOptions(
        baseUrl: kBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 25),
        sendTimeout: const Duration(seconds: 25),
        headers: {'Accept': 'application/json'},
      );

  Options get noAuth => Options(extra: {'auth': false});

  /// One refresh at a time; parallel 401s wait for the same result.
  Future<bool> _refresh() {
    return _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  }

  Future<bool> _doRefresh() async {
    _refreshRejected = false;
    final r = await storage.refresh;
    if (r == null) {
      _refreshRejected = true;
      return false;
    }
    try {
      final res = await _plain.post('/auth/token/refresh', data: {'refresh': r});
      final d = res.data as Map;
      await storage.save('${d['access']}', '${d['refresh'] ?? r}');
      return true;
    } on DioException catch (e) {
      final s = e.response?.statusCode;
      _refreshRejected = s == 400 || s == 401 || s == 403;
      return false;
    }
  }

  Future<T> run<T>(Future<T> Function() f) async {
    try {
      return await f();
    } on DioException catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<Map<String, dynamic>> getMap(String path, {Map<String, dynamic>? q}) =>
      run(() async => Map<String, dynamic>.from((await dio.get(path, queryParameters: q)).data as Map));

  Future<Map<String, dynamic>> postMap(String path, Map<String, dynamic> body, {bool auth = true}) =>
      run(() async {
        final r = await dio.post(path, data: body, options: auth ? null : noAuth);
        return r.data is Map ? Map<String, dynamic>.from(r.data as Map) : <String, dynamic>{};
      });

  Future<Map<String, dynamic>> patchMap(String path, Map<String, dynamic> body) => run(() async {
        final r = await dio.patch(path, data: body);
        return r.data is Map ? Map<String, dynamic>.from(r.data as Map) : <String, dynamic>{};
      });

  Future<void> delete(String path) => run(() => dio.delete(path));

  /// Reads every page of a paginated endpoint (max [maxPages] pages).
  Future<List<Map<String, dynamic>>> getAll(String path, {int maxPages = 10}) async {
    final out = <Map<String, dynamic>>[];
    for (var page = 1; page <= maxPages; page++) {
      final m = await getMap(path, q: {'page': page, 'page_size': 50});
      out.addAll(((m['results'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)));
      if (m['next'] == null) break;
    }
    return out;
  }
}
