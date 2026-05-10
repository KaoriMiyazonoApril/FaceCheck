import 'package:flutter/material.dart';

void main() {
  runApp(const FaceCheckApp());
}

class FaceCheckApp extends StatelessWidget {
  const FaceCheckApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FaceCheck',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
        useMaterial3: true,
      ),
      home: const _BootstrapPage(),
    );
  }
}

class _BootstrapPage extends StatelessWidget {
  const _BootstrapPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('FaceCheck bootstrap'),
      ),
    );
  }
}
