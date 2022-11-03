import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  bool isStart = false;
  StreamSubscription? _streamSubscription;

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

  void onEvent(message) {
    setState(() {
      if ('stop_cloudxr' == message) {
        isStart = false;
      } else if ('start_cloudxr' == message) {
        isStart = true;
      }
    });
  }

  void onError(error) {
    print(error);
  }

  @override
  void initState() {
    super.initState();
    _streamSubscription = _messageEvents
        .receiveBroadcastStream()
        .listen(onEvent, onError: onError);
  }

  @override
  void dispose() {
    if (null != _streamSubscription) {
      _streamSubscription!.cancel();
      _streamSubscription = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(isStart ? '' : 'Touch panel to start cloudXR')
          ],
        ),
      ),
      floatingActionButton: isStart
          ? FloatingActionButton(
              onPressed: _stopCloudXr,
              child: const Icon(Icons.stop),
            )
          : const Text(''),
    );
  }
}
