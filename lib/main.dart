import 'package:flutter/foundation.dart';

import 'bootstrap/bootstrap.dart';

Future<void> main(List<String> args) async {
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };
  await AppBootstrap.run(args);
}
