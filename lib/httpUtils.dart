import 'dart:convert';

import 'package:cloudxr_flutter/ui/appList.dart';
import 'package:cloudxr_flutter/ui/loginPage.dart';
import 'package:cloudxr_flutter/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'constants.dart';
import 'httpService.dart';
import 'log.dart';
import 'main.dart';

const _tag = "HttpUtils";

class HttpUtils {
  String baseUrl = "http://172.16.40.139:3001/";
  int localStatus = deviceCodeUnassigned; //local cloudxr status
  int edgeStatus = -1;  //record edge status from central server
  int lastLocalStatus = -1; //last status sync to central server

  /// private constructor
  HttpUtils._();

  /// the one and only instance of this singleton
  static final instance = HttpUtils._();

  Future<Map<String, dynamic>> syncStatus(bool retry) async {
    int status = localStatus;
    Log.d(_tag, "keepAlive localStatus $status");
    Map<String, dynamic> params = {};
    params[TAG_DEVICE_STATUS] = status;
    params[TAG_STATUS_DESC] = "";
    Map<String, dynamic> responseJson = retry
        ? await retryPostRequest("devices/status", params)
        : await sendPostRequest("devices/status", params);
    if (centralCodeSuccess == responseJson[TAG_RESPONSE_CODE]) {
      lastLocalStatus = localStatus;
      if (null != responseJson[TAG_DATA][TAG_EDGE]) {
        edgeStatus = responseJson[TAG_DATA][TAG_EDGE][TAG_STATUS];
      } else {
        edgeStatus = -1;
      }
    }
    return responseJson;
  }

  Future<Map<String, dynamic>> retryPostRequest(
      String path, Map<String, dynamic> data) async {
    int index = 0;
    int retryTimes = 3;
    while (index < retryTimes) {
      Map<String, dynamic> gameJson =
          await sendPostRequestRetry(path, data, index != retryTimes - 1);
      int respCode = gameJson[TAG_RESPONSE_CODE];
      if (centralCodeSuccess == respCode) {
        return gameJson;
      }
      await Future.delayed(const Duration(milliseconds: 1000));
      index++;
    }
    return {};
  }

  Future<Map<String, dynamic>> sendPostRequest(
      String path, Map<String, dynamic> data) async {
    return await sendPostRequestRetry(path, data, false);
  }

  Future<Map<String, dynamic>> sendPostRequestRetry(
      String path, Map<String, dynamic> data, bool retry) async {
    String? centralServer = Utils.instance.getSharePString(prefCentralServer);
    if (null == centralServer) {
      Utils.instance.setSharePString(prefCentralServer, baseUrl);
    } else {
      baseUrl = centralServer;
    }

    String? token = Utils.instance.getSharePString(prefToken);
    if (!_isLoginApi(path) && token == null) {
      _goToLogin();
      return {};
    }

    Map<String, dynamic> map = {};
    try {
      HttpService httpService = HttpService();
      final response = await httpService
          .post(path, data, !_isLoginApi(path))
          .timeout(const Duration(seconds: 15));
      String jsonString = json.encode(response.data);
      Log.d(_tag, "post path=$path, response=$jsonString, data=$data");
      if (jsonString.isNotEmpty) {
        map = jsonDecode(jsonString);
        await handleResponseCodeRetry(map, retry);
      }
    } catch (e) {
      Log.d(_tag, "post path=$path, data=$data, error=$e");
    }

    return map;
  }

  Future<Map<String, dynamic>> sendDeleteRequest(String path) async {
    String? token = Utils.instance.getSharePString(prefToken);
    if (token == null) {
      _goToLogin();
      return {};
    }

    Map<String, dynamic> map = {};
    try {
      HttpService httpService = HttpService();
      final response =
          await httpService.delete(path).timeout(const Duration(seconds: 15));
      String jsonString = json.encode(response.data);
      Log.d(_tag, "delete path=$path, response=$jsonString");
      if (jsonString.isNotEmpty) {
        map = jsonDecode(jsonString);
        handleResponseCode(map);
      }
    } catch (e) {
      Log.d(_tag, "delete path=$path, error=$e");
    }

    return map;
  }

  Future<Map<String, dynamic>> sendGetRequest(String path) async {
    String? centralServer = Utils.instance.getSharePString(prefCentralServer);
    if (null == centralServer) {
      Utils.instance.setSharePString(prefCentralServer, baseUrl);
    } else {
      baseUrl = centralServer;
    }

    String? token = Utils.instance.getSharePString(prefToken);
    if (token == null) {
      _goToLogin();
      return {};
    }

    Map<String, dynamic> map = {};
    try {
      HttpService httpService = HttpService();
      final response =
          await httpService.get(path).timeout(const Duration(seconds: 15));
      String jsonString = json.encode(response.data);
      Log.d(_tag, "get path=$path, response=$jsonString");
      if (jsonString.isNotEmpty) {
        map = jsonDecode(jsonString);
        handleResponseCode(map);
      }
    } catch (e) {
      Log.d(_tag, "get path=$path, error=$e");
    }

    return map;
  }

  void handleResponseCode(Map<String, dynamic> map) {
    handleResponseCodeRetry(map, false);
  }

  Future<void> handleResponseCodeRetry(
      Map<String, dynamic> map, bool retry) async {
    if (map.containsKey(TAG_RESPONSE_CODE)) {
      int respCode = map[TAG_RESPONSE_CODE];
      if (centralCodeSuccess != respCode) {
        if (!retry) {
          if (map.containsKey(TAG_ERROR)) {
            Map<String, dynamic> error = map[TAG_ERROR];
            Utils.instance.showToast(error[TAG_DESCRIPTION]);
          } else {
            Utils.instance.showToast(Constants.getCentralCodeError(respCode));
          }
        }
        await errorHandleForEdgeStatus(respCode, retry);
      } else {
        if (map.containsKey(TAG_DATA)) {
          Map<String, dynamic> data = map[TAG_DATA];
          if (data.containsKey(TAG_EDGE_STATUS)) {
            Utils.instance
                .showToast(Constants.getEdgeStatus(data[TAG_EDGE_STATUS]));
          }
        }
      }
    }
  }

  Future<void> errorHandleForEdgeStatus(int status, bool retry) async {
    switch (status) {
      case centralCodeLoginDuplicate:
        if (Utils.instance.hasToken()) {
          await sendPostRequest("devices/logout", {});
        }
        break;
      case centralCodeResourceOccupied:
        await sendDeleteRequest("devices/reserve");
        break;
      case centralCodeTokenInvalid:
        _goToLogin();
        break;
      case centralCodeUnknownError:
        //already playing
        break;
      default:
        if (!retry) {
          Log.d(_tag, "currentRouteName is ${Utils.instance.currentRouteName}");
          if (Utils.instance.currentRouteName == AppList.AppListRoute) {
            return;
          }
          BuildContext? context = NavigationService.navigatorKey.currentContext;
          if (null == context) {
            Log.d(_tag, "context is null.");
            return;
          }
          if (context.mounted) {
            try {
              Navigator.pushReplacement(
                  context,
                  MaterialPageRoute<dynamic>(
                      builder: (BuildContext context) => const AppList()));
            } catch (_) {}
          }
        }
    }
  }

  bool _isLoginApi(String path) {
    return path.contains("login");
  }

  void _goToLogin() {
    Utils.instance.setSharePString(prefToken, "");
    BuildContext? context = NavigationService.navigatorKey.currentContext;
    if (null == context) {
      Log.d(_tag, "context is null.");
      return;
    }
    if (context.mounted) {
      try {
        Navigator.pushReplacement(
            context,
            MaterialPageRoute<dynamic>(
                builder: (BuildContext context) => const LoginPage()));
      } catch (_) {
        Navigator.pushNamed(context, "/");
      }
    }
  }
}
