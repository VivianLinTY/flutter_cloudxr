import 'dart:async';

import 'package:cloudxr_flutter/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:udp/udp.dart';

import '../constants.dart';
import '../httpUtils.dart';
import '../log.dart';
import 'appList.dart';

const _tag = "cloudXrPage";
const _platformMessages = MethodChannel('com.compal.cloudxr/messages');
const _messageEvents = EventChannel('com.compal.cloudxr/events');

class CloudXrPage extends StatefulWidget {
  static const String CloudXrPageRoute = 'CloudXrPage';

  const CloudXrPage({Key? key, required this.cloudXrIP}) : super(key: key);

  final String cloudXrIP;

  @override
  State<CloudXrPage> createState() => _CloudXrPageState();
}

class _CloudXrPageState extends State<CloudXrPage> {
  bool _isStart = false;
  bool _isShowPanel = false; //All touch panel
  bool _isShowMenu = false; //Only menu panel
  late DateTime _lastTouchTime;
  StreamSubscription? _streamSubscription;
  UDP? _udpSender;

  // Timer? _timer;

  Future<bool> _sendMessage(String message) async {
    String response = '';
    try {
      response = await _platformMessages.invokeMethod(message);
    } on PlatformException catch (e) {
      response = "${e.message}";
    }
    return response == '1';
  }

  void _stopCloudXr() async {
    await _sendMessage('stop_cloudxr');
  }

  void _releaseCloudXr() async {
    await _sendMessage('disconnect_to_cloudxr');
  }

  void _startApp() async {
    Map<String, dynamic> syncJson = await HttpUtils.instance.syncStatus(true);
    if (centralCodeSuccess == syncJson[TAG_RESPONSE_CODE]) {
      await Future.delayed(const Duration(milliseconds: 1000), () {});
      Map<String, dynamic> gameJson =
          await HttpUtils.instance.retryPostRequest("devices/start_app", {});
      if (centralCodeSuccess == gameJson[TAG_RESPONSE_CODE]) {
        HttpUtils.instance.localStatus = deviceCodePlaying;
      }
    } else {
      _onBackPressed();
    }
  }

  void _onEvent(message) {
    if (mounted) {
      if ('stop_cloudxr' == message) {
        if (mounted && (_isStart || _isShowMenu)) {
          setState(() {
            _isStart = false;
            _isShowMenu = false;
          });
        }
        HttpUtils.instance.localStatus = deviceCodeDisconnected;
      } else if ('start_cloudxr' == message) {
        if (mounted && !_isStart) {
          setState(() {
            _isStart = true;
          });
        }
        HttpUtils.instance.localStatus = deviceCodeConnected;
        _startApp();
      } else if (message.contains("Rot")) {
        _sendUdpCmd(message);
      } else if (message.contains("touch")) {
        if (mounted && !_isShowPanel) {
          setState(() {
            _isShowPanel = true;
          });
        }
        _lastTouchTime = DateTime.now();
        Future.delayed(const Duration(seconds: 5), () {
          DateTime now = DateTime.now();
          if (now.millisecondsSinceEpoch -
                  _lastTouchTime.millisecondsSinceEpoch >=
              5000) {
            _hidePanel();
          }
        });
      }
    }
  }

  void _onError(error) {
    Log.e(_tag, error);
  }

  void _initUdpClient() async {
    _udpSender = await UDP.bind(Endpoint.any(port: Port(8001)));
  }

  void _sendUdpCmd(String cmd) async {
    if (null != _udpSender) {
      await _udpSender!
          .send(cmd.codeUnits, Endpoint.broadcast(port: Port(8001)));
    }
  }

  void _setMenuVisibility() {
    if (mounted) {
      setState(() {
        _isShowMenu = !_isShowMenu;
      });
    }
  }

  void _hidePanel() {
    if (mounted && _isShowPanel) {
      setState(() {
        _isShowPanel = false;
      });
    }
  }

  void _sendHeadPos() async {
    _sendUdpCmd("Rot,");
  }

  @override
  void initState() {
    HttpUtils.instance.localStatus = deviceCodeDisconnected;
    super.initState();
    // _timer = Timer(const Duration(seconds: 50), () {
    //   _onBackPressed();
    // });
    _streamSubscription = _messageEvents
        .receiveBroadcastStream()
        .listen(_onEvent, onError: _onError);
    String ip = widget.cloudXrIP;
    _sendMessage('connect_to_cloudxr' + ip); //must not interpolation
    _initUdpClient();
    _sendHeadPos();
  }

  void _closeGameServer() async {
    Log.d(_tag, "_closeGameServer");
    await HttpUtils.instance.sendPostRequest("devices/stop_app", {});
    await HttpUtils.instance.sendDeleteRequest("/devices/reserve");
  }

  @override
  void dispose() {
    if (_isStart) {
      _stopCloudXr();
    }
    _releaseCloudXr();
    if (null != _streamSubscription) {
      _streamSubscription!.cancel();
      _streamSubscription = null;
    }
    if (null != _udpSender) {
      _udpSender!.closed;
    }
    _closeGameServer();
    super.dispose();
  }

  Future<bool> _onBackPressed() async {
    await Navigator.pushReplacement(
        context,
        MaterialPageRoute<dynamic>(
            builder: (BuildContext context) => const AppList()));
    return true;
  }

  @override
  Widget build(BuildContext context) {
    Log.d(_tag, "build _isShowMenu= $_isShowMenu, _isShowPanel= $_isShowPanel");
    Utils.instance.currentRouteName = CloudXrPage.CloudXrPageRoute;
    return WillPopScope(
        onWillPop: _onBackPressed,
        child: Scaffold(
          body: Stack(children: [
            _isShowMenu
                ? Container(width: 0)
                : IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                    onPressed: () {
                      _onBackPressed();
                    }),
            Center(
                child: Text(_isStart ? '' : 'Touch panel to start cloudXR',
                    style: const TextStyle(color: Colors.white))),
            Center(
                child: _isShowMenu && _isShowPanel
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                            Container(
                                color: const Color(0x66dddddd),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    IconButton(
                                      icon: const Icon(Icons.arrow_drop_up),
                                      onPressed: () => _sendUdpCmd("Pos,5"),
                                    ),
                                    Row(children: [
                                      IconButton(
                                        icon: const Icon(Icons.arrow_left),
                                        onPressed: () => _sendUdpCmd("Pos,0"),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.arrow_right),
                                        onPressed: () => _sendUdpCmd("Pos,1"),
                                      )
                                    ]),
                                    IconButton(
                                      icon: const Icon(Icons.arrow_drop_down),
                                      onPressed: () => _sendUdpCmd("Pos,4"),
                                    )
                                  ],
                                )),
                            Container(width: 20),
                            Container(
                                color: const Color(0x66dddddd),
                                child: Row(children: [
                                  IconButton(
                                    icon: const Icon(Icons.arrow_back),
                                    onPressed: () => _sendUdpCmd("Pos,6"),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.arrow_forward),
                                    onPressed: () => _sendUdpCmd("Pos,7"),
                                  )
                                ])),
                            Container(width: 20),
                            Container(
                                color: const Color(0x66dddddd),
                                child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.arrow_circle_up),
                                        onPressed: () => _sendUdpCmd("Pos,3"),
                                      ),
                                      IconButton(
                                        icon:
                                            const Icon(Icons.arrow_circle_down),
                                        onPressed: () => _sendUdpCmd("Pos,2"),
                                      )
                                    ]))
                          ])
                    : _isStart && _isShowPanel
                        ? const Icon(Icons.add, size: 30, color: Colors.white)
                        : Container(width: 0)),
            _isStart && _isShowPanel
                ? Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                      RawMaterialButton(
                        onPressed: _setMenuVisibility,
                        elevation: 2.0,
                        fillColor: Colors.white,
                        padding: const EdgeInsets.all(8.0),
                        shape: const CircleBorder(),
                        child: const Icon(Icons.settings, size: 30.0),
                      ),
                      Container(height: 10),
                      RawMaterialButton(
                        onPressed: () => _sendUdpCmd("Ctr,3"),
                        elevation: 2.0,
                        fillColor: Colors.white,
                        padding: const EdgeInsets.all(8.0),
                        shape: const CircleBorder(),
                        child: const Icon(Icons.touch_app, size: 30.0),
                      ),
                      Container(height: 10),
                      RawMaterialButton(
                        onPressed: _stopCloudXr,
                        elevation: 2.0,
                        fillColor: Colors.white,
                        padding: const EdgeInsets.all(8.0),
                        shape: const CircleBorder(),
                        child: const Icon(Icons.stop, size: 30.0),
                      ),
                      Container(height: 10),
                      RawMaterialButton(
                        onPressed: () => _sendUdpCmd("KeyDown,230"),
                        elevation: 2.0,
                        fillColor: Colors.white,
                        padding: const EdgeInsets.all(8.0),
                        shape: const CircleBorder(),
                        child: const Icon(Icons.lock_open_outlined, size: 30.0),
                      ),
                      Container(height: 10)
                    ])
                  ])
                : Container(width: 0),
          ]),
        ));
  }
}
