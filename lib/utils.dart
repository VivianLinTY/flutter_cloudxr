import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

import 'httpService.dart';
import 'log.dart';

const _tag = "Utils";

class Utils {
  static String? _deviceID;

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

  static Future<String> sendGetRequest(String path) async {
    _deviceID ??= await _getId();
    if (null != _deviceID) {
      path = "$path?id=${_deviceID!}";
    }
    HttpService httpService = HttpService();
    final response = await httpService.get(path);
    String jsonStr = json.encode(response.data);
    Log.d(_tag, jsonStr);
    return jsonStr;
  }
}
