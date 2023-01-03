import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:udp/udp.dart';

const _platformMessages = MethodChannel('com.compal.cloudxr/messages');
const _messageEvents = EventChannel('com.compal.cloudxr/events');

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
      home: const MyHomePage(title: 'Compal Flutter Demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _isStart = false;
  bool _isShowPanel = false;  //All touch panel
  bool _isShowMenu = false;  //Only menu panel
  late DateTime _lastTouchTime;
  StreamSubscription? _streamSubscription;
  UDP? _udpSender;

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

  void _onEvent(message) {
    setState(() {
      if ('stop_cloudxr' == message) {
        _isStart = false;
        _isShowMenu = false;
      } else if ('start_cloudxr' == message) {
        _isStart = true;
      } else if (message.contains("Rot")) {
        _sendUdpCmd(message);
      } else if (message.contains("touch")) {
        _isShowPanel = true;
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
    });
  }

  void _onError(error) {
    print(error);
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
    setState(() {
      _isShowMenu = !_isShowMenu;
    });
  }

  void _hidePanel() {
    setState(() {
      _isShowPanel = false;
    });
  }

  void _sendHeadPos() async {
    _sendUdpCmd("Rot,");
  }

  @override
  void initState() {
    super.initState();
    _streamSubscription = _messageEvents
        .receiveBroadcastStream()
        .listen(_onEvent, onError: _onError);
    _initUdpClient();
    _sendHeadPos();
  }

  @override
  void dispose() {
    if (null != _streamSubscription) {
      _streamSubscription!.cancel();
      _streamSubscription = null;
    }
    if (null != _udpSender) {
      _udpSender!.closed;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        Center(
            child: Text(_isStart ? '' : 'Touch panel to start cloudXR',
                style: const TextStyle(color: Colors.white))),
        Positioned(
            top: 30.0,
            left: 30.0,
            child: _isStart && _isShowPanel
                ? IconButton(
                    icon: const Icon(Icons.menu, color: Colors.white),
                    onPressed: _setMenuVisibility)
                : Container(width: 0)),
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
                                    icon: const Icon(Icons.arrow_circle_down),
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
            : Container(width: 0)
      ]),
    );
  }
}
