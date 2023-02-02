import 'dart:convert';

import 'package:cloudxr_flutter/myHomePage.dart';
import 'package:cloudxr_flutter/utils.dart';
import 'package:flutter/material.dart';

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
    return MaterialApp(
      title: 'Compal CloudXR',
      theme: ThemeData(
          primarySwatch: Colors.blue,
          scaffoldBackgroundColor: Colors.transparent,
          backgroundColor: Colors.transparent),
      home: const MyAppList(),
    );
  }
}

class MyAppList extends StatefulWidget {
  const MyAppList({Key? key}) : super(key: key);

  @override
  State<MyAppList> createState() => _MyAppListState();
}

class _MyAppListState extends State<MyAppList> {
  late Function _onSuccessCallback;
  bool _showAppList = true;
  bool _hasLaunchedGame = false;

  Future<void> _connectToEdgeServer(
      String type, Map<String, dynamic> gameInfo) async {
    String id = gameInfo["content_id"];
    String response;
    if (gameInfo["already_launched"]) {
      response = await Utils.sendGetRequest("$type/$id/resume");
    } else {
      if (_hasLaunchedGame) {
        await Utils.sendGetRequest("/close");
        _hasLaunchedGame = false;
      }
      response = await Utils.sendGetRequest("$type/$id/launch");
    }
    Map<String, dynamic> gameJson = jsonDecode(response);
    if (gameJson["status"]) {
      _onSuccessCallback(gameJson["game_server_ip"], id, type);
    } else {
      Future.delayed(const Duration(milliseconds: 2000), () {
        _connectToEdgeServer(type, gameInfo);
      });
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
              Text(gameInfo["content_title"])
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
        child: FutureBuilder<String>(
            //Get game list
            future: Utils.sendGetRequest(type),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Text("loading $type...", style: _popupTextStyle);
              } else if (snapshot.connectionState == ConnectionState.done) {
                if (snapshot.hasData) {
                  Map<String, dynamic> gameJson = jsonDecode(snapshot.data!);
                  int listSize = gameJson["total_num"];
                  if (gameJson["status"]) {
                    for (int i = 0; i < listSize; i++) {
                      Map<String, dynamic> gameInfo = gameJson[type]["$i"];
                      if (gameInfo["already_launched"]) {
                        _hasLaunchedGame = true;
                        break;
                      }
                    }
                    return ListView.builder(
                        itemCount: listSize,
                        itemBuilder: (BuildContext context, int position) {
                          return _getItem(context, gameJson[type], position,
                              type);
                        });
                  } else {
                    Future.delayed(const Duration(milliseconds: 2000), () {
                      return _getList(type, padding);
                    });
                  }
                }
              } else if (snapshot.hasError) {
                return Text('loading $type error!!', style: _popupTextStyle);
              }
              return Text('loading $type...', style: _popupTextStyle);
            }));
  }

  @override
  void initState() {
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
    _hasLaunchedGame = false;
    return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
            child: _showAppList
                ? Container(
                    color: const Color(0xffdddddd),
                    width: 610,
                    height: 300,
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _getList("games",
                              const EdgeInsets.fromLTRB(5, 10, 10, 10)),
                          _getList(
                              "apps", const EdgeInsets.fromLTRB(10, 10, 5, 10)),
                        ]))
                : const CircularProgressIndicator()));
  }
}
