import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme.dart';
import 'core/router.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/home/providers/document_provider.dart';
import 'features/chat/providers/chat_provider.dart';
import 'features/upload/providers/upload_provider.dart';
import 'features/notebooks/providers/notebook_provider.dart';
import 'features/quiz/providers/quiz_provider.dart';
import 'features/quiz/providers/quiz_history_provider.dart';
import 'features/flashcards/providers/flashcard_provider.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DocumentProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => UploadProvider()),
        ChangeNotifierProvider(create: (_) => NotebookProvider()),
        ChangeNotifierProvider(create: (_) => QuizProvider()),
        ChangeNotifierProvider(create: (_) => QuizHistoryProvider()),
        ChangeNotifierProvider(create: (_) => FlashCardProvider()),
      ],
      child: const TdmuSmartDocApp(),
    ),
  );
}

class TdmuSmartDocApp extends StatelessWidget {
  const TdmuSmartDocApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'TDMU SmartDoc',
      theme: AppTheme.lightTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
