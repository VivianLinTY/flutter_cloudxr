import 'package:cloudxr_flutter/httpUtils.dart';
import 'package:cloudxr_flutter/ui/appList.dart';
import 'package:cloudxr_flutter/ui/loginPage.dart';
import 'package:cloudxr_flutter/utils.dart';
import 'package:flutter/material.dart';

import 'constants.dart';

void main() {
  runApp(const MyApp());
}

class NavigationService {
  static GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // This widget is the root of your application.
  bool alive = true;

  Future keepAlive() async {
    while (alive) {
      if (Utils.instance.hasToken() &&
          (HttpUtils.instance.localStatus != edgeCodeUnassigned ||
              HttpUtils.instance.localStatus != HttpUtils.instance.lastLocalStatus)) {
        await HttpUtils.instance.syncStatus(false);
      }
      await Future.delayed(const Duration(seconds: 30));
    }
  }

  void initialize() async {
    await Utils.instance.init();
    BuildContext? context = NavigationService.navigatorKey.currentContext;
    if (null != context && context.mounted) {
      Navigator.pushReplacement(
          context,
          MaterialPageRoute<dynamic>(
              builder: (BuildContext context) => Utils.instance.hasToken()
                  ? const AppList()
                  : const LoginPage()));
    }
    keepAlive();
  }

  @override
  void initState() {
    super.initState();
    initialize();
  }

  @override
  void dispose() {
    alive = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Compal CloudXR',
        navigatorKey: NavigationService.navigatorKey,
        theme: ThemeData(
            scaffoldBackgroundColor: Colors.transparent,
            colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.blue)
                .copyWith(background: Colors.transparent)),
        home: const LaunchPage());
  }
}

class LaunchPage extends StatelessWidget {
  static const String LaunchPageRoute = 'LaunchPage';

  const LaunchPage({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    Utils.instance.currentRouteName = LaunchPageRoute;

    return WillPopScope(
        onWillPop: () => Utils.instance.showLeaveAppAlert(context),
        child: const Scaffold(backgroundColor: Colors.black));
  }
}
