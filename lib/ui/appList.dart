import 'package:cloudxr_flutter/ui/cloudXrPage.dart';
import 'package:cloudxr_flutter/utils.dart';
import 'package:flutter/material.dart';

import '../appInfo.dart';
import '../constants.dart';
import '../httpUtils.dart';

class AppList extends StatefulWidget {
  static const String AppListRoute = 'AppList';

  const AppList({Key? key}) : super(key: key);

  @override
  State<AppList> createState() => _MyAppListState();
}

class _MyAppListState extends State<AppList> {
  late Function _onSuccessCallback;
  bool _showAppList = true;
  bool _showServerField = false;

  final TextStyle _popupTextStyle =
      const TextStyle(fontSize: 20, color: Colors.black);

  Future<void> _connectToEdgeServer(String type, AppInfo appInfo) async {
    int id = appInfo.id;
    Map<String, dynamic> gameJson = await HttpUtils.instance
        .retryPostRequest("devices/$type/$id/reserve", {});
    if (gameJson.containsKey(TAG_DATA)) {
      Map<String, dynamic> data = gameJson[TAG_DATA];
      if (data.containsKey(TAG_GAME_SERVER_IP)) {
        _onSuccessCallback(data[TAG_GAME_SERVER_IP], id, type);
      }
    } else {
      if (mounted) {
        setState(() {
          _showAppList = true;
        });
      }
    }
  }

  Widget _getItem(
      BuildContext context, List<dynamic> list, int position, String type) {
    AppInfo gameInfo = list[position];
    return GestureDetector(
        child: Padding(
            padding: const EdgeInsets.all(5),
            child: Column(children: [
              Image.network(gameInfo.img_url, width: 270, height: 120,
                  errorBuilder: (context, error, stackTrace) {
                return const SizedBox(width: 270, height: 120);
              }),
              Text(gameInfo.title)
            ])),
        onTap: () {
          setState(() {
            _showAppList = false;
          });
          _connectToEdgeServer(type, gameInfo);
        },
        behavior: HitTestBehavior.opaque);
  }

  Widget _getList(String type, EdgeInsets padding) {
    return Container(
        width: 290,
        padding: padding,
        alignment: Alignment.center,
        child: FutureBuilder<Map<String, dynamic>>(
            //Get game list
            future: HttpUtils.instance.sendGetRequest(type),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Text("loading $type...", style: _popupTextStyle);
              } else if (snapshot.connectionState == ConnectionState.done) {
                if (snapshot.hasData) {
                  Map<String, dynamic> gameJson = snapshot.data!;
                  if (!gameJson.containsKey(TAG_DATA)) {
                    return Text('Data empty.', style: _popupTextStyle);
                  }
                  Map<String, dynamic> data = gameJson[TAG_DATA];
                  int listSize = data[TAG_TOTAL_NUMBER];
                  return ListView.builder(
                      itemCount: listSize,
                      itemBuilder: (BuildContext context, int position) {
                        return _getItem(
                            context,
                            (data[TAG_APP] as List)
                                .map((i) => AppInfo.fromJson(i))
                                .toList(),
                            position,
                            type);
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
    HttpUtils.instance.localStatus = deviceCodeUnassigned;
    super.initState();
    _onSuccessCallback = (ip, id, type) {
      Navigator.pushReplacement(
          context,
          MaterialPageRoute<dynamic>(
              builder: (BuildContext context) => CloudXrPage(
                  cloudXrIP:
                      ip)) //if you want to disable back feature set to false
          );
    };
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    Utils.instance.currentRouteName = AppList.AppListRoute;

    int index = 0;
    final serverTextController =
        TextEditingController(text: HttpUtils.instance.baseUrl);
    final TextField serverText = TextField(
        controller: serverTextController,
        decoration: const InputDecoration(
            filled: true,
            fillColor: Colors.white70,
            hintText: "Central server IP & Port"));

    return WillPopScope(
        onWillPop: () => Utils.instance.showLeaveAppAlert(context),
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
