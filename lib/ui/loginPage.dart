import 'package:cloudxr_flutter/utils.dart';
import 'package:flutter/material.dart';

import '../constants.dart';
import '../httpUtils.dart';
import '../log.dart';
import 'appList.dart';

const _tag = "LoginPage";

class LoginPage extends StatelessWidget {
  static const String LoginPageRoute = 'LoginPage';

  const LoginPage({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    Utils.instance.currentRouteName = LoginPageRoute;
    bool savePressed = false;
    HttpUtils.instance.localStatus = deviceCodeUnassigned;

    final accountTextController = TextEditingController();
    final TextField accountText = TextField(
        controller: accountTextController,
        decoration: const InputDecoration(
            filled: true, fillColor: Colors.white70, hintText: "Account"));
    final passwordTextController = TextEditingController();
    final TextField passwordText = TextField(
        controller: passwordTextController,
        decoration: const InputDecoration(
            filled: true, fillColor: Colors.white70, hintText: "Password"));

    return WillPopScope(
        onWillPop: () => Utils.instance.showLeaveAppAlert(context),
        child: Scaffold(
            backgroundColor: Colors.black,
            body: Center(
                child: SingleChildScrollView(
                    //Fixed overflowed by column
                    child: Column(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                  SizedBox(width: 300, child: accountText),
                  const SizedBox(height: 10),
                  SizedBox(width: 300, child: passwordText),
                  const SizedBox(height: 10),
                  IconButton(
                      icon: const Icon(Icons.login, color: Colors.white, size: 30),
                      onPressed: () async {
                        Log.v(_tag, "onPressed $savePressed");
                        if (savePressed) {
                          return;
                        }
                        savePressed = true;
                        if (accountTextController.text.isNotEmpty &&
                            passwordTextController.text.isNotEmpty) {
                          Map<String, dynamic> params = {};
                          params[TAG_ACCOUNT] = accountTextController.text;
                          params[TAG_PASSWORD] = passwordTextController.text;
                          params[TAG_DEVICE_TYPE] = deviceTypeMobile;
                          params[TAG_UUID] = await Utils.instance.deviceId;
                          Map<String, dynamic> gameJson = await HttpUtils
                              .instance
                              .sendPostRequest("devices/login", params);
                          if (gameJson.containsKey(TAG_DATA)) {
                            Map<String, dynamic> data = gameJson[TAG_DATA];
                            await Utils.instance
                                .setSharePString(prefToken, data[TAG_TOKEN]);
                            if (context.mounted) {
                              Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute<dynamic>(
                                      builder: (BuildContext context) =>
                                          const AppList()));
                            }
                          }
                        }
                        savePressed = false;
                      })
                ])))));
  }
}
