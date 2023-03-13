import 'package:cloudxr_flutter/myHomePage.dart';
import 'package:cloudxr_flutter/utils.dart';
import 'package:flutter/material.dart';

import 'constants.dart';
import 'log.dart';

const _tag = "Main";
const TextStyle _popupTextStyle = TextStyle(fontSize: 20, color: Colors.black);

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    Future keepAlive() async {
      while (true) {
        int status = Utils.instance.localStatus;
        Log.d(_tag, "keepAlive localStatus $status");
        Map<String, dynamic> params = {};
        params['device_status'] = status;
        params['status_des'] = "";
        await Utils.instance.sendPostRequest(context, "devices/status", params);
        await Future.delayed(const Duration(seconds: 30));
      }
    }

    void initialize() async {
      await Utils.instance.init();
      await keepAlive();
    }

    initialize();
    return MaterialApp(
      title: 'Compal CloudXR',
      theme: ThemeData(
          scaffoldBackgroundColor: Colors.transparent,
          colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.blue)
              .copyWith(background: Colors.transparent)),
      home: const LoginPage(),
    );
  }
}

Future<bool> _onBackPressed(BuildContext context) async {
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

class LoginPage extends StatelessWidget {
  const LoginPage({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    bool savePressed = false;
    Utils.instance.localStatus = deviceCodeUnassigned;

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
        onWillPop: () => _onBackPressed(context),
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
                  TextButton(
                      onPressed: () async {
                        if (savePressed) {
                          return;
                        }
                        savePressed = true;
                        if (accountTextController.text.isNotEmpty &&
                            passwordTextController.text.isNotEmpty) {
                          Map<String, dynamic> params = {};
                          params['account'] = accountTextController.text;
                          params['password'] = passwordTextController.text;
                          params['device_type'] = deviceTypeMobile;
                          params['uuid'] = await Utils.instance.deviceId;
                          Map<String, dynamic> gameJson = await Utils.instance
                              .sendPostRequest(
                                  context, "devices/login", params);
                          if (gameJson.containsKey('data')) {
                            Map<String, dynamic> data = gameJson['data'];
                            await Utils.instance
                                .setSharePString(prefToken, data['token']);
                            if (context.mounted) {
                              Navigator.pushAndRemoveUntil<dynamic>(
                                context,
                                MaterialPageRoute<dynamic>(
                                    builder: (BuildContext context) =>
                                        const AppList()),
                                (route) =>
                                    false, //if you want to disable back feature set to false
                              );
                            }
                          }
                        }
                        savePressed = false;
                      },
                      child: const Text("login",
                          style: TextStyle(
                              fontSize: 30,
                              backgroundColor: Colors.white60,
                              color: Colors.black,
                              letterSpacing: 3)))
                ])))));
  }
}

class AppList extends StatefulWidget {
  const AppList({Key? key}) : super(key: key);

  @override
  State<AppList> createState() => _MyAppListState();
}

class _MyAppListState extends State<AppList> {
  late Function _onSuccessCallback;
  bool _showAppList = true;
  bool _showServerField = false;

  Future<void> _connectToEdgeServer(
      String type, Map<String, dynamic> gameInfo) async {
    String id = gameInfo["id"];
    Map<String, dynamic> gameJson = await Utils.instance
        .sendPostRequest(context, "devices/$type/$id/reserve", {});
    if (gameJson.containsKey('data')) {
      Map<String, dynamic> data = gameJson['data'];
      if (data.containsKey('game_server_ip')) {
        _onSuccessCallback(data['game_server_ip'], id, type);
      }
    }
  }

  Widget _getItem(BuildContext context, Map<String, dynamic> list, int position,
      String type) {
    Map<String, dynamic> gameInfo = list["$position"];
    return GestureDetector(
        child: Padding(
            padding: const EdgeInsets.all(5),
            child: Column(children: [
              Image.network(gameInfo["img_url"], width: 270, height: 120,
                  errorBuilder: (context, error, stackTrace) {
                return const SizedBox(width: 270, height: 120);
              }),
              Text(gameInfo["title"])
            ])),
        onTap: () {
          setState(() {
            _showAppList = false;
          });
          _connectToEdgeServer(type, gameInfo);
        });
  }

  Widget _getList(String type, EdgeInsets padding) {
    return Container(
        width: 290,
        padding: padding,
        alignment: Alignment.center,
        child: FutureBuilder<Map<String, dynamic>>(
            //Get game list
            future: Utils.instance.sendGetRequest(context, type),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Text("loading $type...", style: _popupTextStyle);
              } else if (snapshot.connectionState == ConnectionState.done) {
                if (snapshot.hasData) {
                  Map<String, dynamic> gameJson = snapshot.data!;
                  if (!gameJson.containsKey('data')) {
                    return const Text('Data empty.', style: _popupTextStyle);
                  }
                  Map<String, dynamic> data = gameJson['data'];
                  int listSize = data['total_num'];
                  return ListView.builder(
                      itemCount: listSize,
                      itemBuilder: (BuildContext context, int position) {
                        return _getItem(context, data['app'], position, type);
                      });
                }
              } else if (snapshot.hasError) {
                return Text('loading $type error!!', style: _popupTextStyle);
              }
              return Text('loading $type...', style: _popupTextStyle);
            }));
  }

  @override
  void initState() {
    Utils.instance.localStatus = deviceCodeUnassigned;
    super.initState();
    Log.d(_tag, "initState");
    _onSuccessCallback = (ip, id, type) {
      Navigator.pushAndRemoveUntil<dynamic>(
        context,
        MaterialPageRoute<dynamic>(
          builder: (BuildContext context) => MyHomePage(cloudXrIP: ip),
        ),
        (route) => false, //if you want to disable back feature set to false
      );
    };
  }

  @override
  void dispose() {
    super.dispose();
    Log.d(_tag, "dispose");
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    int index = 0;

    final serverTextController =
        TextEditingController(text: Utils.instance.baseUrl);
    final TextField serverText = TextField(
        controller: serverTextController,
        decoration: const InputDecoration(
            filled: true,
            fillColor: Colors.white70,
            hintText: "Central server IP & Port"));

    return WillPopScope(
        onWillPop: () => _onBackPressed(context),
        child: Scaffold(
            backgroundColor: Colors.black,
            body: Stack(children: [
              Center(
                  child: _showAppList
                      ? Container(
                          color: const Color(0xffdddddd),
                          width: 300,
                          height: 300,
                          child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // _getList("games",
                                //     const EdgeInsets.fromLTRB(5, 10, 10, 10)),
                                _getList("apps",
                                    const EdgeInsets.fromLTRB(10, 10, 5, 10)),
                              ]))
                      : const CircularProgressIndicator()),
              Container(
                  alignment: Alignment.bottomRight,
                  child: TextButton(
                      onPressed: () {
                        index++;
                        if (index > 4) {
                          setState(() {
                            _showServerField = true;
                          });
                        }
                      },
                      child: const SizedBox(width: 30, height: 30))),
              _showServerField
                  ? Row(children: [
                      SizedBox(width: 500, child: serverText),
                      TextButton(
                          onPressed: () async {
                            await Utils.instance.setSharePString(
                                prefCentralServer, serverTextController.text);
                            setState(() {
                              _showServerField = false;
                            });
                          },
                          child: const Text("save",
                              style: TextStyle(
                                  fontSize: 30,
                                  backgroundColor: Colors.white60,
                                  color: Colors.black,
                                  letterSpacing: 3)))
                    ])
                  : Container(width: 0)
            ])));
  }
}
