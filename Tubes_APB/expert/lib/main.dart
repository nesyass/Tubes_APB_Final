import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth/splash_screen.dart';
import 'data/supabase_storage_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (SupabaseStorageConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseStorageConfig.url,
      publishableKey: SupabaseStorageConfig.key,
    );
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Expert Printing',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E4CB9)),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}
