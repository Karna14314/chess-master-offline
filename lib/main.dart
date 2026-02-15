import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/screens/bottom_nav/bottom_nav_screen.dart';
import 'package:chess_master/screens/game/widgets/chess_piece.dart';
import 'package:chess_master/core/theme/board_themes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Preload piece assets in background
  PieceAssets.preloadAssets(PieceSet.traditional);

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Configure system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.backgroundDark,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const ProviderScope(child: ChessMasterApp()));
}

class ChessMasterApp extends StatelessWidget {
  const ChessMasterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChessMaster Offline',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: BottomNavScreen(),
    );
  }
}
