import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'ai/config_loader.dart';
import 'ai/inference_engine.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AiConfigLoader.loadAll();
  await InferenceEngine.initModel();
  runApp(const EcoVisionApp());
}

class EcoVisionApp extends StatelessWidget {
  const EcoVisionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EcoVision',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
