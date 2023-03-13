import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';

import 'constants.dart';
import 'httpService.dart';
import 'log.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttertoast/fluttertoast.dart';

import 'main.dart';

const _tag = "Utils";
const prefCentralServer = "central_server";
const prefToken = "token";

class Utils {
  String? deviceId;
  SharedPreferences? prefs;
  String baseUrl = "http://192.168.3.55:5000/";
  int localStatus = edgeCodeUnassigned;

  /// private constructor
  Utils._();

  /// the one and only instance of this singleton
  static final instance = Utils._();

  Future init() async {
    deviceId = await _getId();
    prefs ??= await SharedPreferences.getInstance();
  }

  Future<String?> _getId() async {
    var deviceInfo = DeviceInfoPlugin();
    if (Platform.isIOS) {
      // import 'dart:io'
      var iosDeviceInfo = await deviceInfo.iosInfo;
      return iosDeviceInfo.identifierForVendor; // unique ID on iOS
    } else if (Platform.isAndroid) {
      var androidDeviceInfo = await deviceInfo.androidInfo;
      return androidDeviceInfo.androidId; // unique ID on Android
    }
    return null;
  }

  Future<void> setSharePString(String key, String value) async {
    prefs!.setString(key, value);
    Log.d(_tag, "setSharePString key=$key value=$value");
  }

  bool _isLoginApi(String path) {
    return path.contains("login");
  }

  void _goToLogin(BuildContext context) {
    if (context.mounted) {
      Navigator.pushAndRemoveUntil<dynamic>(
        context,
        MaterialPageRoute<dynamic>(
            builder: (BuildContext context) => const LoginPage()),
        (route) => false, //if you want to disable back feature set to false
      );
    }
  }

  Future<Map<String, dynamic>> sendGetRequest(
      BuildContext context, String path) async {
    String? centralServer = prefs!.getString(prefCentralServer);
    if (null == centralServer) {
      prefs!.setString(prefCentralServer, baseUrl);
    } else {
      baseUrl = centralServer;
    }

    String? token = prefs!.getString(prefToken);
    if (token == null) {
      _goToLogin(context);
      return {};
    }

    Map<String, dynamic> map = {};
    try {
      HttpService httpService = HttpService();
      final response =
          await httpService.get(path).timeout(const Duration(seconds: 15));
      String jsonString = json.encode(response.data);
      Log.d(_tag, jsonString);
      if (jsonString.isNotEmpty) {
        map = jsonDecode(jsonString);
        _handleResponseCode(context, map);
      }
    } catch (e) {
      Log.d(_tag, "path=$path, error=$e");
    }

    return map;
  }

  Future<Map<String, dynamic>> sendPostRequest(
      BuildContext context, String path, Map<String, dynamic> data) async {
    String? centralServer = prefs!.getString(prefCentralServer);
    if (null == centralServer) {
      prefs!.setString(prefCentralServer, baseUrl);
    } else {
      baseUrl = centralServer;
    }

    String? token = prefs!.getString(prefToken);
    if (!_isLoginApi(path) && token == null) {
      _goToLogin(context);
      return {};
    }

    Map<String, dynamic> map = {};
    try {
      HttpService httpService = HttpService();
      final response = await httpService
          .post(path, data, !_isLoginApi(path))
          .timeout(const Duration(seconds: 15));
      String jsonString = json.encode(response.data);
      Log.d(_tag, jsonString);
      if (jsonString.isNotEmpty) {
        map = jsonDecode(jsonString);
        _handleResponseCode(context, map);
      }
    } catch (e) {
      Log.d(_tag, "path=$path, data=$data, error=$e");
    }

    return map;
  }

  Future<Map<String, dynamic>> sendDeleteRequest(
      BuildContext context, String path) async {
    String? token = prefs!.getString(prefToken);
    if (token == null) {
      _goToLogin(context);
      return {};
    }

    Map<String, dynamic> map = {};
    try {
      HttpService httpService = HttpService();
      final response =
          await httpService.delete(path).timeout(const Duration(seconds: 15));
      String jsonString = json.encode(response.data);
      Log.d(_tag, jsonString);
      if (jsonString.isNotEmpty) {
        map = jsonDecode(jsonString);
        _handleResponseCode(context, map);
      }
    } catch (e) {
      Log.d(_tag, "path=$path, error=$e");
    }

    return map;
  }

  _handleResponseCode(BuildContext context, Map<String, dynamic> map) {
    if (map.containsKey('resp_code')) {
      int respCode = map['resp_code'];
      if (centralCodeSuccess != respCode) {
        showToast(Constants.getCentralCodeError(respCode));
        if (centralCodeTokenInvalid == respCode) {
          _goToLogin(context);
        }
      }
    } else if (map.containsKey('data')) {
      Map<String, dynamic> data = map['data'];
      if (data.containsKey('edge_status')) {
        showToast(Constants.getEdgeStatus(data['edge_status']));
      }
    }
  }

  showToast(String message) {
    Fluttertoast.showToast(
        msg: message,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        fontSize: 16.0);
  }
}
