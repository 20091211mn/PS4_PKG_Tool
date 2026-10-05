import 'dart:async';
import 'package:flutter/material.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      print("Flutter Error Details: ${details.exception}");
    };

    runApp(const MyApp());
  }, (Object error, StackTrace stack) {
    print("Uncaught Error Details: $error");
    print("Stack Trace Details: $stack");
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('App Initialized Successfully'),
        ),
      ),
    );
  }
}
