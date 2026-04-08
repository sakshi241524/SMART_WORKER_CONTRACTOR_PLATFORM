import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'auth_wrapper.dart';

import 'package:provider/provider.dart';
import 'app_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  debugPrint("SWCP App: Initializing Firebase...");
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint("SWCP App: Firebase initialized successfully");
  } catch (e) {
    debugPrint("SWCP App: Firebase initialization error: $e");
  }

  runApp(
    ChangeNotifierProvider(
      create: (context) => AppState(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SWCP App',
      themeMode: appState.themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F3A40)),
        useMaterial3: true,
      ),
      darkTheme: ThemeData.dark(useMaterial3: true),
      locale: appState.locale,
      home: const AuthWrapper(),
    );
  }
}


