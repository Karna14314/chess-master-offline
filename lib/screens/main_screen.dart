import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/screens/home/home_screen.dart';
import 'package:chess_master/screens/puzzles/puzzle_menu_screen.dart';
import 'package:chess_master/screens/learn/learn_screen.dart';
import 'package:chess_master/screens/stats/statistics_screen.dart';
import 'package:chess_master/providers/settings_provider.dart';
import 'package:chess_master/providers/streak_provider.dart';

/// Provider for main bottom navigation tab index
final mainTabProvider = StateProvider<int>((ref) => 0);

/// Main screen with 4 bottom navigation tabs: Play, Puzzles, Learn, Profile
class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  final List<Widget> _screens = const [
    HomeScreen(),
    PuzzleMenuScreen(),
    LearnScreen(),
    StatisticsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(mainTabProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = ref.watch(settingsProvider);
    final accentColor = settings.themePreset.accentColor;
    final streakState = ref.watch(streakProvider);
    final isDailyPuzzleSolvedToday = streakState.isDailyPuzzleSolvedToday;

    return Scaffold(
      body: IndexedStack(index: currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceLevel1(context),
          border: Border(
            top: BorderSide(
              color: AppTheme.borderStroke(context),
              width: 1.0,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
              blurRadius: 12,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: (index) {
            HapticFeedback.selectionClick();
            ref.read(mainTabProvider.notifier).state = index;
          },
          backgroundColor: AppTheme.surfaceLevel1(context),
          selectedItemColor: accentColor,
          unselectedItemColor: AppTheme.textSecondaryFor(context),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          showUnselectedLabels: true,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 11,
          ),
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.sports_esports_outlined),
              activeIcon: Icon(Icons.sports_esports),
              label: 'Play',
            ),
            BottomNavigationBarItem(
              icon: _buildPuzzlesIcon(
                isActive: false,
                isSolvedToday: isDailyPuzzleSolvedToday,
              ),
              activeIcon: _buildPuzzlesIcon(
                isActive: true,
                isSolvedToday: isDailyPuzzleSolvedToday,
              ),
              label: 'Puzzles',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.school_outlined),
              activeIcon: Icon(Icons.school_rounded),
              label: 'Learn',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPuzzlesIcon({
    required bool isActive,
    required bool isSolvedToday,
  }) {
    final icon = Icon(
      isActive ? Icons.extension_rounded : Icons.extension_outlined,
    );

    if (isSolvedToday) return icon;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        icon,
        Positioned(
          top: -2,
          right: -2,
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFFFF6D00), // Orange badge dot for unsolved Daily Puzzle
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }
}
