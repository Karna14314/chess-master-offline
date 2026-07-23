import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/providers/settings_provider.dart';
import 'package:chess_master/screens/main_screen.dart';

/// Onboarding screen for first-time players.
/// Features welcome message, skill level picker, feature highlights, and privacy positioning.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  int _selectedSkillLevel = 1; // 1 = Beginner, 3 = Intermediate, 5 = Advanced

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_completed_onboarding', true);

    // Persist selected starting difficulty
    ref.read(settingsProvider.notifier).setLastDifficulty(_selectedSkillLevel);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark ? AppTheme.backgroundDark : AppTheme.backgroundLight;
    final textPrimary = isDark ? AppTheme.textPrimary : AppTheme.textPrimaryLight;
    final textSecondary = isDark ? AppTheme.textSecondary : AppTheme.textSecondaryLight;
    final cardColor = isDark ? AppTheme.cardDark : AppTheme.cardLight;
    final borderColor = isDark ? AppTheme.borderColor : AppTheme.borderLight;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar with Skip Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Page Indicators
                  Row(
                    children: List.generate(
                      3,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(right: 6),
                        width: _currentPage == index ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? AppTheme.primaryColor
                              : textSecondary.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  if (_currentPage < 2)
                    TextButton(
                      onPressed: _completeOnboarding,
                      child: Text(
                        'Skip',
                        style: GoogleFonts.inter(
                          color: textSecondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: 48),
                ],
              ),
            ),

            // Main Page Content
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                children: [
                  _buildWelcomePage(context, textPrimary, textSecondary),
                  _buildSkillLevelPage(context, textPrimary, textSecondary, cardColor, borderColor),
                  _buildFeaturesPage(context, textPrimary, textSecondary, cardColor, borderColor),
                ],
              ),
            ),

            // Bottom Navigation Controls
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (_currentPage < 2) {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    } else {
                      _completeOnboarding();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 2,
                  ),
                  child: Text(
                    _currentPage == 2 ? 'Get Started' : 'Continue',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomePage(BuildContext context, Color textPrimary, Color textSecondary) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.offline_bolt_rounded,
              size: 80,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            '100% Offline & Ad-Free',
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Play chess anytime, anywhere with zero ads, zero accounts, and zero data tracking. Your privacy stays on your device.',
            style: GoogleFonts.inter(
              fontSize: 15,
              height: 1.5,
              color: textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSkillLevelPage(
    BuildContext context,
    Color textPrimary,
    Color textSecondary,
    Color cardColor,
    Color borderColor,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Your Skill Level',
            style: GoogleFonts.inter(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We\'ll set your initial Stockfish AI difficulty so games feel just right.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 24),

          _buildSkillCard(
            context,
            level: 1,
            title: 'Beginner',
            subtitle: 'New to chess or learning the fundamentals.',
            icon: Icons.school_outlined,
            isSelected: _selectedSkillLevel == 1,
            cardColor: cardColor,
            borderColor: borderColor,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          const SizedBox(height: 12),
          _buildSkillCard(
            context,
            level: 3,
            title: 'Intermediate',
            subtitle: 'Know basic tactics, piece values, and checkmates.',
            icon: Icons.military_tech_outlined,
            isSelected: _selectedSkillLevel == 3,
            cardColor: cardColor,
            borderColor: borderColor,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          const SizedBox(height: 12),
          _buildSkillCard(
            context,
            level: 5,
            title: 'Advanced',
            subtitle: 'Experienced player looking for strong AI practice.',
            icon: Icons.workspace_premium_outlined,
            isSelected: _selectedSkillLevel == 5,
            cardColor: cardColor,
            borderColor: borderColor,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildSkillCard(
    BuildContext context, {
    required int level,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required Color cardColor,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Material(
      color: isSelected
          ? AppTheme.primaryColor.withValues(alpha: 0.15)
          : cardColor,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedSkillLevel = level;
          });
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppTheme.primaryColor : borderColor,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 32,
                color: isSelected ? AppTheme.primaryColor : textSecondary,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? AppTheme.primaryColor : textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: isSelected ? AppTheme.primaryColor : textSecondary.withValues(alpha: 0.5),
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturesPage(
    BuildContext context,
    Color textPrimary,
    Color textSecondary,
    Color cardColor,
    Color borderColor,
  ) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Everything You Need',
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Improve your tactics, analyze your games, and maintain your daily streak.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 28),

          _buildFeatureItem(
            icon: Icons.extension_outlined,
            color: Colors.amber,
            title: 'Daily Puzzles & Streaks',
            subtitle: 'Solve daily tactics puzzles and protect your playing streak.',
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          const SizedBox(height: 20),
          _buildFeatureItem(
            icon: Icons.smart_toy_outlined,
            color: AppTheme.primaryColor,
            title: 'Stockfish AI',
            subtitle: 'Train against 8 distinct difficulty levels for all player ratings.',
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          const SizedBox(height: 20),
          _buildFeatureItem(
            icon: Icons.analytics_outlined,
            color: Colors.purple,
            title: 'Full Game Analysis',
            subtitle: 'Import PGNs, analyze moves, and track win statistics.',
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
