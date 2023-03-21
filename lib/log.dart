const _debug = true;

class Log {
  static v(String tag, String message) {
    if (_debug) {
      print("Compal-CloudXr $tag $message");
    }
  }

  static d(String tag, String message) {
    if (_debug) {
      print("Compal-CloudXr $tag $message");
    }
  }

  static e(String tag, String message) {
    print("Compal-CloudXr $tag $message");
  }
}
