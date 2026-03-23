import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'screens/viewer_tab.dart';
import 'screens/saved_tab.dart';
import 'dart:io';

void main() {
  // Initialize sqflite FFI for desktop platforms (Windows, Linux, macOS)
  if (!Platform.isAndroid && !Platform.isIOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Excel Viewer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const ExcelViewerApp(),
    );
  }
}

class ExcelViewerApp extends StatelessWidget {
  const ExcelViewerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Excel Viewer'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Viewer'),
              Tab(text: 'Saved'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            ViewerTab(),
            SavedTab(),
          ],
        ),
      ),
    );
  }
}
