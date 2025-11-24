import 'package:flutter/material.dart';
import 'screens/media_home_page.dart';

class MediaPlayerApp extends StatelessWidget {
  const MediaPlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MediaHomePage(),
    );
  }
}
