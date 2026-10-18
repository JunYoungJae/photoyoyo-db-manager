import 'package:flutter/material.dart';
import 'screens/sales_manager_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PhotoYoYoDbManager());
}

class PhotoYoYoDbManager extends StatelessWidget {
  const PhotoYoYoDbManager({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Photo YoYo DB Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const SalesManagerScreen(),
    );
  }
}
