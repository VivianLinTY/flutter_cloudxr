import 'package:cloudxr_flutter/log.dart';
import 'package:dio/dio.dart';

const _tag = "HttpService";

class HttpService {
  late Dio _dio;

  final baseUrl = "http://192.168.3.55:5000/";

  HttpService() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
    ));

    initializeInterceptors();
  }

  Future<Response> _request(String path, {required String method}) async {
    Response response;
    try {
      response = await _dio.request(path, options: Options(method: method));
    } on DioError catch (e) {
      Log.e(_tag, e.message);
      throw Exception(e.message);
    }

    return response;
  }

  Future<Response> get(String path) async {
    return _request(path, method: "get");
  }

  initializeInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          Log.d(_tag, "${options.method} ${options.path}");
          return handler.next(options);
        },
        onResponse: (response, handler) {
          return handler.next(response);
        },
        onError: (DioError e, handler) {
          return handler.next(e);
        },
      ),
    );
  }
}