import 'package:flutter/material.dart';

void main() => runApp(const LanplaceFlutterModuleApp());

/// Default route shown when opening [FlutterModuleHost] from the ArkTS shell.
class LanplaceFlutterModuleApp extends StatelessWidget {
  const LanplaceFlutterModuleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '蓝域 Flutter',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF008FC8)),
        useMaterial3: true,
      ),
      home: const LanplaceFlutterHomePage(),
    );
  }
}

class LanplaceFlutterHomePage extends StatelessWidget {
  const LanplaceFlutterHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('蓝域 · Flutter Module')),
      body: const Center(
        child: Text(
          'Flutter module 已嵌入鸿蒙宿主',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
