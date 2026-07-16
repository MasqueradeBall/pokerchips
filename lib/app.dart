import 'package:flutter/material.dart';

import 'core/theme.dart';
import 'screens/home/home_screen.dart';

class PokerChipsApp extends StatelessWidget {
  const PokerChipsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Poker Chips',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const HomeScreen(),
    );
  }
}
