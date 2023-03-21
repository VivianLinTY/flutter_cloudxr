import 'dart:convert';
import 'dart:io';

import 'package:cloudxr_flutter/httpUtils.dart';
import 'package:cloudxr_flutter/log.dart';
import 'package:cloudxr_flutter/utils.dart';
import 'package:dio/dio.dart';

import 'constants.dart';

const _tag = "HttpService";

class HttpService {
  late Dio _dio;

  HttpService() {
    _dio = Dio(BaseOptions(baseUrl: HttpUtils.instance.baseUrl));

    _initializeInterceptors();
  }

  Future<Response> get(String path) async {
    Response response;
    try {
      _dio.options.headers[TAG_AUTHORIZATION] =
          Utils.instance.getSharePString(prefToken);
      response = await _dio.get(path);
    } on DioError catch (e) {
      if (null != e.response) {
        Log.e(_tag, "get ${e.message} ${e.response!.data}");
        HttpUtils.instance.handleResponseCode(e.response!.data);
      } else {
        Log.e(_tag, e.message);
      }
      throw Exception(e.message);
    }
    return response;
  }

  Future<Response> post(
      String path, Map<String, dynamic> data, bool needToken) async {
    Response response;
    try {
      if (needToken) {
        _dio.options.headers[TAG_AUTHORIZATION] =
            Utils.instance.getSharePString(prefToken);
      }
      response = await _dio.post(
        path,
        data: jsonEncode(data),
        options: Options(
            headers: {HttpHeaders.contentTypeHeader: "application/json"}),
      );

    } on DioError catch (e) {
      if (null != e.response) {
        Log.e(_tag, "post ${e.message} ${e.response!.data}");
        HttpUtils.instance.handleResponseCode(e.response!.data);
      } else {
        Log.e(_tag, e.message);
      }
      throw Exception(e.message);
    }
    return response;
  }

  Future<Response> delete(String path) async {
    Response response;
    try {
      _dio.options.headers[TAG_AUTHORIZATION] =
          Utils.instance.getSharePString(prefToken);
      response = await _dio.delete(path);
    } on DioError catch (e) {
      if (null != e.response) {
        Log.e(_tag, "delete ${e.message} ${e.response!.data}");
        HttpUtils.instance.handleResponseCode(e.response!.data);
      } else {
        Log.e(_tag, e.message);
      }
      throw Exception(e.message);
    }
    return response;
  }

  _initializeInterceptors() {
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
