import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/temp_spike_game_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  runApp(const TempSpikeMatchApp());
}

class TempSpikeMatchApp extends StatelessWidget {
  const TempSpikeMatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TempSpike Match',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFF121212),
        useMaterial3: true,
      ),
      home: const TempSpikeGameScreen(),
    );
  }
}
