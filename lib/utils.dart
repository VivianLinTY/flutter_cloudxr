import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:encrypt/encrypt.dart' as Encrypt;
import 'package:encrypt/encrypt.dart';

import 'constants.dart';
import 'httpService.dart';
import 'log.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttertoast/fluttertoast.dart';

import 'main.dart';

const _tag = "Utils";
const prefCentralServer = "central_server";
const prefToken = "token";

const String _key = "compal32lengthsupersecrettooken1";

class Utils {
  String? deviceId;
  SharedPreferences? _prefs;
  String baseUrl = "http://192.168.3.55:5000/";
  int localStatus = edgeCodeUnassigned;
  Encrypt.Encrypter? _encrypter;

  /// private constructor
  Utils._();

  /// the one and only instance of this singleton
  static final instance = Utils._();

  Future init() async {
    final key = Encrypt.Key.fromUtf8(_key);
    _encrypter = Encrypt.Encrypter(
        Encrypt.AES(key, mode: Encrypt.AESMode.cbc, padding: 'PKCS7'));

    deviceId = await _getId();
    _prefs ??= await SharedPreferences.getInstance();
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
    _prefs!.setString(key, value.isNotEmpty ? _aesEncode(value) : value);
    Log.d(_tag, "setSharePString key=$key value=$value");
  }

  String? getSharePString(String key) {
    String? data = _prefs!.getString(key);
    return null == data || data.isEmpty ? data : _aesDecode(data);
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
        Navigator.pushAndRemoveUntil<dynamic>(
          context,
          MaterialPageRoute<dynamic>(
              builder: (BuildContext context) => const LoginPage()),
          (route) => false, //if you want to disable back feature set to false
        );
      } catch (_) {
        Navigator.pushNamed(context, "/");
      }
    }
  }

  Future<Map<String, dynamic>> sendGetRequest(String path) async {
    String? centralServer = getSharePString(prefCentralServer);
    if (null == centralServer) {
      setSharePString(prefCentralServer, baseUrl);
    } else {
      baseUrl = centralServer;
    }

    String? token = getSharePString(prefToken);
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
      Log.d(_tag, jsonString);
      if (jsonString.isNotEmpty) {
        map = jsonDecode(jsonString);
        _handleResponseCode(map);
      }
    } catch (e) {
      Log.d(_tag, "path=$path, error=$e");
    }

    return map;
  }

  Future<Map<String, dynamic>> sendPostRequest(
      String path, Map<String, dynamic> data) async {
    String? centralServer = getSharePString(prefCentralServer);
    if (null == centralServer) {
      setSharePString(prefCentralServer, baseUrl);
    } else {
      baseUrl = centralServer;
    }

    String? token = getSharePString(prefToken);
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
      Log.d(_tag, jsonString);
      if (jsonString.isNotEmpty) {
        map = jsonDecode(jsonString);
        _handleResponseCode(map);
      }
    } catch (e) {
      Log.d(_tag, "path=$path, data=$data, error=$e");
    }

    return map;
  }

  Future<Map<String, dynamic>> sendDeleteRequest(String path) async {
    String? token = getSharePString(prefToken);
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
      Log.d(_tag, jsonString);
      if (jsonString.isNotEmpty) {
        map = jsonDecode(jsonString);
        _handleResponseCode(map);
      }
    } catch (e) {
      Log.d(_tag, "path=$path, error=$e");
    }

    return map;
  }

  _handleResponseCode(Map<String, dynamic> map) {
    if (map.containsKey('resp_code')) {
      int respCode = map['resp_code'];
      if (centralCodeSuccess != respCode) {
        showToast(Constants.getCentralCodeError(respCode));
        if (centralCodeTokenInvalid == respCode) {
          _goToLogin();
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

  String _aesEncode(String content) {
    final iv = IV.fromLength(16);
    Encrypted encrypted = _encrypter!.encrypt(content, iv: iv);
    return encrypted.base64;
  }

  String _aesDecode(String content) {
    final iv = IV.fromLength(16);
    String decrypted =
        _encrypter!.decrypt(Encrypted.fromBase64(content), iv: iv);
    return decrypted;
  }
}
