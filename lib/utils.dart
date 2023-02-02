import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

import 'httpService.dart';
import 'log.dart';

import 'package:shared_preferences/shared_preferences.dart';

const _tag = "Utils";
const prefCentralServer = "central_server";

class Utils {
  static SharedPreferences? _prefs;
  static String? _deviceID;
  static String baseUrl = "http://192.168.3.55:5000/";

  static Future<String?> _getId() async {
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

  static Future<void> setSharePString(String key, String value) async {
    _prefs ??= await SharedPreferences.getInstance();
    _prefs!.setString(key, value);
    Log.d(_tag, "setSharePString key=$key value=$value");
  }

  static Future<String> sendGetRequest(String path) async {
    _deviceID ??= await _getId();
    _prefs ??= await SharedPreferences.getInstance();

    if (null != _deviceID) {
      path = "$path?id=${_deviceID!}";
    }

    String? centralServer = _prefs!.getString(prefCentralServer);
    if (null == centralServer) {
      _prefs!.setString(prefCentralServer, baseUrl);
    } else {
      baseUrl = centralServer;
    }

    HttpService httpService = HttpService();
    final response = await httpService.get(path);
    String jsonStr = json.encode(response.data);
    Log.d(_tag, jsonStr);
    return jsonStr;
  }
}
