import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'home_screen.dart';
import 'look.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  runApp(const WishingSkyApp());
}

class WishingSkyApp extends StatelessWidget {
  const WishingSkyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wishing Sky',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'PatrickHand',
        colorScheme: ColorScheme.fromSeed(seedColor: stickerYellow, brightness: Brightness.dark),
        scaffoldBackgroundColor: ceilingTop,
      ),
      home: const HomeScreen(),
    );
  }
}
