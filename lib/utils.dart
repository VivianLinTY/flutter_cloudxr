import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:encrypt/encrypt.dart' as Encrypt;
import 'package:encrypt/encrypt.dart';

import 'log.dart';
import 'main.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttertoast/fluttertoast.dart';

const _tag = "Utils";
const prefCentralServer = "central_server";
const prefToken = "token";

const String _key = "compal32lengthsupersecrettooken1";

class Utils {
  String? deviceId;
  SharedPreferences? _prefs;
  Encrypt.Encrypter? _encrypter;
  String currentRouteName = LaunchPage.LaunchPageRoute;

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

  showToast(String message) {
    Fluttertoast.showToast(
        msg: message,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        fontSize: 16.0);
  }

  bool hasToken() {
    String? token = Utils.instance.getSharePString(prefToken);
    return null != token && token.isNotEmpty;
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

  Future<bool> showLeaveAppAlert(BuildContext context) async {
    return (await showDialog(
          context: context,
          builder: (context) => AlertDialog(
              title: const Text('Are you sure?'),
              content: const Text('Do you want to exit an App'),
              actions: <Widget>[
                GestureDetector(
                  onTap: () => Navigator.pop(context, false),
                  child: const Text("NO"),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => Navigator.pop(context, true),
                  child: const Text("YES"),
                )
              ]),
        )) ??
        false;
  }
}
