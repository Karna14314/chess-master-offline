import 'package:chess_master/screens/settings/about_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/core/theme/board_themes.dart';
import 'package:chess_master/core/constants/app_constants.dart';
import 'package:chess_master/providers/settings_provider.dart';
import 'package:chess_master/screens/game/widgets/chess_piece.dart';
import 'package:chess_master/screens/history/game_history_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:chess_master/screens/onboarding/onboarding_screen.dart';
import 'package:chess_master/providers/statistics_provider.dart';

/// Settings screen for app customization
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _version = 'Loading...';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _version = packageInfo.version;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _version = 'Unknown';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120.0,
            floating: false,
            pinned: true,
            backgroundColor: Theme.of(context).colorScheme.surface,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'Settings',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.surface,
                      Theme.of(context).scaffoldBackgroundColor,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16.0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Appearance Section
                _buildSectionHeader(
                  context,
                  'Appearance',
                  Icons.palette_outlined,
                ),
                const SizedBox(height: 12),
                _buildSettingsCard(context, [
                  _ThemePresetSelector(
                    currentPreset: settings.themePreset,
                    onChanged: (preset) => settingsNotifier.setThemePreset(preset),
                  ),
                  Divider(color: AppTheme.borderColorFor(context)),
                  _BoardThemeSelector(
                    currentTheme: settings.boardTheme,
                    onChanged: (theme) => settingsNotifier.setBoardTheme(theme),
                  ),
                  Divider(color: AppTheme.borderColorFor(context)),
                  _PieceSetSelector(
                    currentSet: settings.pieceSet,
                    onChanged: (set) => settingsNotifier.setPieceSet(set),
                  ),
                ]),
                const SizedBox(height: 24),

                // Gameplay Section
                _buildSectionHeader(
                  context,
                  'Gameplay',
                  Icons.sports_esports_outlined,
                ),
                const SizedBox(height: 12),
                _buildSettingsCard(context, [
                  _SwitchSetting(
                    title: 'Show Coordinates',
                    subtitle: 'Display a-h and 1-8 board labels',
                    value: settings.showCoordinates,
                    onChanged: (_) => settingsNotifier.toggleCoordinates(),
                  ),
                  Divider(color: AppTheme.borderColorFor(context)),
                  _SwitchSetting(
                    title: 'Show Legal Moves',
                    subtitle: 'Highlight available moves on board',
                    value: settings.showLegalMoves,
                    onChanged: (_) => settingsNotifier.toggleLegalMoves(),
                  ),
                  Divider(color: AppTheme.borderColorFor(context)),
                  _SwitchSetting(
                    title: 'Show Last Move',
                    subtitle: 'Highlight origin and target squares',
                    value: settings.showLastMove,
                    onChanged: (_) => settingsNotifier.toggleLastMove(),
                  ),
                  Divider(color: AppTheme.borderColorFor(context)),
                  _SwitchSetting(
                    title: 'Auto-flip for Black',
                    subtitle: 'Automatically invert perspective when playing black',
                    value: settings.autoFlipBoard,
                    onChanged: (_) => settingsNotifier.toggleAutoFlipBoard(),
                  ),
                ]),
                const SizedBox(height: 24),

                // Preferences Section
                _buildSectionHeader(
                  context,
                  'Preferences',
                  Icons.tune_outlined,
                ),
                const SizedBox(height: 12),
                _buildSettingsCard(context, [
                  _AnimationSpeedSelector(
                    currentSpeed: settings.animationSpeed,
                    onChanged:
                        (speed) => settingsNotifier.setAnimationSpeed(speed),
                  ),
                  Divider(color: AppTheme.borderColorFor(context)),
                  _SwitchSetting(
                    title: 'Sound Effects',
                    subtitle: 'Audio cues for moves, captures, and checks',
                    value: settings.soundEnabled,
                    onChanged: (_) => settingsNotifier.toggleSound(),
                  ),
                  Divider(color: AppTheme.borderColorFor(context)),
                  _SwitchSetting(
                    title: 'Vibration',
                    subtitle: 'Haptic feedback on move interactions',
                    value: settings.vibrationEnabled,
                    onChanged: (_) => settingsNotifier.toggleVibration(),
                  ),
                ]),
                const SizedBox(height: 24),

                // Game History & Analysis Section
                _buildSectionHeader(
                  context,
                  'Games & Analysis',
                  Icons.analytics_outlined,
                ),
                const SizedBox(height: 12),
                _buildSettingsCard(context, [
                  ListTile(
                    title: Text(
                      'Game History & PGN Archive',
                      style: GoogleFonts.inter(
                        color: AppTheme.textPrimaryFor(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      'Browse past matches, replay moves, and export PGN',
                      style: GoogleFonts.inter(
                        color: AppTheme.textSecondaryFor(context),
                        fontSize: 12,
                      ),
                    ),
                    leading: const Icon(
                      Icons.history_edu_rounded,
                      color: AppTheme.primaryColor,
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: AppTheme.textSecondaryFor(context),
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const GameHistoryScreen(),
                      ),
                    ),
                  ),
                  Divider(color: AppTheme.borderColorFor(context)),
                  _SwitchSetting(
                    title: 'Show Win Probability',
                    subtitle: 'Display win% estimates instead of raw centipawns',
                    value: settings.showWinPercent,
                    onChanged: (_) => settingsNotifier.toggleShowWinPercent(),
                  ),
                  Divider(color: AppTheme.borderColorFor(context)),
                  _SwitchSetting(
                    title: 'Auto-analyze After Game',
                    subtitle: 'Automatically open deep review when match ends',
                    value: settings.autoAnalyzeAfterGame,
                    onChanged: (_) => settingsNotifier.toggleAutoAnalyze(),
                  ),
                ]),
                const SizedBox(height: 24),

                // Notifications Section
                _buildSectionHeader(
                  context,
                  'Local Notifications',
                  Icons.notifications_none_outlined,
                ),
                const SizedBox(height: 12),
                _buildSettingsCard(context, [
                  _SwitchSetting(
                    title: 'Daily Puzzle Reminders',
                    subtitle: 'Local notification when today\'s challenge arrives',
                    value: settings.dailyPuzzleNotificationEnabled,
                    onChanged:
                        (_) => _toggleNotification(
                          context,
                          settings.dailyPuzzleNotificationEnabled,
                          () => settingsNotifier
                              .toggleDailyPuzzleNotification(),
                        ),
                  ),
                  Divider(color: AppTheme.borderColorFor(context)),
                  _SwitchSetting(
                    title: 'Streak Protection Nudges',
                    subtitle: 'Gentle warning before your streak resets at midnight',
                    value: settings.streakNotificationEnabled,
                    onChanged:
                        (_) => _toggleNotification(
                          context,
                          settings.streakNotificationEnabled,
                          () =>
                              settingsNotifier.toggleStreakNotification(),
                        ),
                  ),
                ]),
                const SizedBox(height: 24),

                // Data & Statistics Management
                _buildSectionHeader(context, 'Data & Profile', Icons.analytics_outlined),
                const SizedBox(height: 12),
                _buildSettingsCard(context, [
                  ListTile(
                    title: Text(
                      'Reset Rating & Match Statistics',
                      style: GoogleFonts.inter(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      'Reset game rating to baseline (400 Novice) and clear match history',
                      style: GoogleFonts.inter(
                        color: AppTheme.textSecondaryFor(context),
                        fontSize: 12,
                      ),
                    ),
                    leading: const Icon(
                      Icons.restore_rounded,
                      color: Colors.redAccent,
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: AppTheme.textSecondaryFor(context),
                    ),
                    onTap: () => _confirmResetStats(context),
                  ),
                ]),
                const SizedBox(height: 24),

                // About Section
                _buildSectionHeader(context, 'About', Icons.info_outline),
                const SizedBox(height: 12),
                _buildSettingsCard(context, [
                  ListTile(
                    title: Text(
                      'Our Other Games',
                      style: GoogleFonts.inter(
                        color: AppTheme.textPrimaryFor(context),
                      ),
                    ),
                    subtitle: Text(
                      'Explore ad-free games by Karna Digital',
                      style: GoogleFonts.inter(
                        color: AppTheme.textSecondaryFor(context),
                        fontSize: 12,
                      ),
                    ),
                    leading: const Icon(
                      Icons.sports_esports_outlined,
                      color: AppTheme.primaryColor,
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: AppTheme.textSecondaryFor(context),
                    ),
                    onTap: () => _launchDeveloperPage(),
                  ),
                  Divider(color: AppTheme.borderColorFor(context)),
                  ListTile(
                    title: Text(
                      'Rate Us on Play Store',
                      style: GoogleFonts.inter(
                        color: AppTheme.textPrimaryFor(context),
                      ),
                    ),
                    subtitle: Text(
                      'Love the app? Leave a review!',
                      style: GoogleFonts.inter(
                        color: AppTheme.textSecondaryFor(context),
                        fontSize: 12,
                      ),
                    ),
                    leading: const Icon(
                      Icons.star_outline,
                      color: AppTheme.primaryColor,
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: AppTheme.textSecondaryFor(context),
                    ),
                    onTap: () => _launchPlayStore(),
                  ),
                  Divider(color: AppTheme.borderColorFor(context)),
                  ListTile(
                    title: Text(
                      'Welcome Tutorial & Skill Setup',
                      style: GoogleFonts.inter(
                        color: AppTheme.textPrimaryFor(context),
                      ),
                    ),
                    subtitle: Text(
                      'Revisit onboarding guide & AI difficulty setup',
                      style: GoogleFonts.inter(
                        color: AppTheme.textSecondaryFor(context),
                        fontSize: 12,
                      ),
                    ),
                    leading: const Icon(
                      Icons.school_outlined,
                      color: AppTheme.primaryColor,
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: AppTheme.textSecondaryFor(context),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const OnboardingScreen(),
                        ),
                      );
                    },
                  ),
                  Divider(color: AppTheme.borderColorFor(context)),
                  ListTile(
                    title: Text(
                      'Open Source & Credits',
                      style: GoogleFonts.inter(
                        color: AppTheme.textPrimaryFor(context),
                      ),
                    ),
                    leading: Icon(
                      Icons.info_outline,
                      color: AppTheme.textSecondaryFor(context),
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: AppTheme.textSecondaryFor(context),
                    ),
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AboutScreen(),
                          ),
                        ),
                  ),
                  Divider(color: AppTheme.borderColorFor(context)),
                  _InfoRow(title: 'App Version', value: _version),
                  Divider(color: AppTheme.borderColorFor(context)),
                  _InfoRow(title: 'Engine', value: 'Stockfish 17'),
                  Divider(color: AppTheme.borderColorFor(context)),
                  ListTile(
                    title: Text(
                      'Licenses',
                      style: GoogleFonts.inter(
                        color: AppTheme.textPrimaryFor(context),
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: AppTheme.textSecondaryFor(context),
                    ),
                    onTap: () => _showLicenses(context),
                  ),
                ]),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(BuildContext context, List<Widget> children) {
    final cardColor =
        Theme.of(context).cardTheme.color ??
        Theme.of(context).colorScheme.surface;
    final borderColor =
        Theme.of(context).dividerTheme.color ?? AppTheme.borderColor;

    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Column(children: children),
      ),
    );
  }

  void _showLicenses(BuildContext context) {
    showLicensePage(
      context: context,
      applicationName: AppConstants.appName,
      applicationVersion: _version,
    );
  }

  void _launchPlayStore() async {
    const appPackageName = 'com.karna.chessmaster';
    final uri = Uri.parse('market://details?id=$appPackageName');
    final webUri = Uri.parse(
      'https://play.google.com/store/apps/details?id=$appPackageName',
    );

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open Play Store'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open Play Store'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _launchDeveloperPage() async {
    final uri = Uri.parse(
      'https://play.google.com/store/apps/developer?id=Karna+Digital',
    );
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  // Helper for notification reminders
  Future<void> _toggleNotification(
    BuildContext context,
    bool wasEnabled,
    Future<bool> Function() toggle,
  ) async {
    final enabled = await toggle();
    // Tried to enable but still OFF => OS permission denied.
    if (!wasEnabled && !enabled && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Notification permission denied — enable it in system settings to use reminders',
          ),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _confirmResetStats(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surfaceLevel2(dialogContext),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
        title: Text(
          'Reset Rating & Stats?',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'This will reset your Game ELO to baseline (400 Novice) and clear match history, allowing you to climb sequentially with the balanced rating system.\n\nPuzzle ratings and achievements are preserved.',
          style: GoogleFonts.inter(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(dialogContext);
              await ref.read(statisticsProvider.notifier).resetStatistics();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Rating and stats reset to baseline (400 ELO).'),
                    backgroundColor: AppTheme.emeraldGreen,
                  ),
                );
              }
            },
            child: const Text('Reset to Baseline'),
          ),
        ],
      ),
    );
  }
}

/// Theme preset selector with cohesive accent and board swatches
class _ThemePresetSelector extends StatelessWidget {
  final ThemePreset currentPreset;
  final ValueChanged<ThemePreset> onChanged;

  const _ThemePresetSelector({
    required this.currentPreset,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Row(
            children: [
              Text(
                'Theme Preset',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimaryFor(context),
                ),
              ),
              const Spacer(),
              Text(
                currentPreset.displayName,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: currentPreset.accentColor,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Changes app colors, board aesthetics, and piece styles',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppTheme.textSecondaryFor(context),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 88,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: ThemePreset.values.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final preset = ThemePreset.values[index];
              final isSelected = currentPreset == preset;
              final boardTheme = BoardTheme.fromType(preset.defaultBoardTheme);

              return GestureDetector(
                onTap: () => onChanged(preset),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 124,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? preset.accentColor.withValues(alpha: 0.12)
                        : AppTheme.surfaceColor(context),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? preset.accentColor
                          : AppTheme.borderColorFor(context),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  boardTheme.lightSquare,
                                  boardTheme.darkSquare,
                                ],
                                stops: const [0.5, 0.5],
                              ),
                              border: Border.all(
                                color: preset.accentColor,
                                width: 1.5,
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (isSelected)
                            Icon(
                              Icons.check_circle_rounded,
                              size: 16,
                              color: preset.accentColor,
                            ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            preset.displayName,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? preset.accentColor
                                  : AppTheme.textPrimaryFor(context),
                            ),
                          ),
                          Text(
                            boardTheme.name,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: AppTheme.textSecondaryFor(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

/// Board theme selector with circular swatches
class _BoardThemeSelector extends StatelessWidget {
  final BoardThemeType currentTheme;
  final ValueChanged<BoardThemeType> onChanged;

  const _BoardThemeSelector({
    required this.currentTheme,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Text(
            'Board Theme',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimaryFor(context),
            ),
          ),
        ),
        SizedBox(
          height: 80,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: BoardThemeType.values.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final themeType = BoardThemeType.values[index];
              final boardTheme = BoardTheme.fromType(themeType);
              final isSelected = currentTheme == themeType;

              return GestureDetector(
                onTap: () => onChanged(themeType),
                child: Column(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color:
                              isSelected
                                  ? AppTheme.primaryColor
                                  : Colors.grey.withValues(alpha: 0.3),
                          width: isSelected ? 3 : 1,
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            boardTheme.lightSquare,
                            boardTheme.darkSquare,
                          ],
                          stops: const [0.5, 0.5],
                        ),
                        boxShadow:
                            isSelected
                                ? [
                                  BoxShadow(
                                    color: AppTheme.primaryColor.withValues(
                                      alpha: 0.4,
                                    ),
                                    blurRadius: 8,
                                  ),
                                ]
                                : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      boardTheme.name,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        color:
                            isSelected
                                ? AppTheme.primaryColor
                                : AppTheme.textSecondaryFor(context),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Piece set selector using actual piece widgets
class _PieceSetSelector extends StatelessWidget {
  final PieceSetType currentSet;
  final ValueChanged<PieceSetType> onChanged;

  const _PieceSetSelector({required this.currentSet, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Text(
            'Piece Set',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimaryFor(context),
            ),
          ),
        ),
        SizedBox(
          height: 90,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: PieceSetType.values.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final setType = PieceSetType.values[index];
              final pieceSet = PieceSet.fromType(setType);
              final isSelected = currentSet == setType;

              return GestureDetector(
                onTap: () => onChanged(setType),
                child: Container(
                  width: 80,
                  decoration: BoxDecoration(
                    color:
                        isSelected
                            ? AppTheme.primaryColor.withValues(alpha: 0.1)
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          isSelected
                              ? AppTheme.primaryColor
                              : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ChessPiece(piece: 'wN', size: 24, pieceSet: pieceSet),
                          const SizedBox(width: 4),
                          ChessPiece(piece: 'bN', size: 24, pieceSet: pieceSet),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        pieceSet.name,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          color:
                              isSelected
                                  ? AppTheme.primaryColor
                                  : AppTheme.textSecondaryFor(context),
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

/// Animation speed selector
class _AnimationSpeedSelector extends StatelessWidget {
  final AnimationSpeed currentSpeed;
  final ValueChanged<AnimationSpeed> onChanged;

  const _AnimationSpeedSelector({
    required this.currentSpeed,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Animation Speed',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimaryFor(context),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children:
                  AnimationSpeed.values.map((speed) {
                    final isSelected = currentSpeed == speed;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => onChanged(speed),
                        child: Container(
                          decoration: BoxDecoration(
                            color:
                                isSelected
                                    ? AppTheme.primaryColor
                                    : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            speed.label,
                            style: GoogleFonts.inter(
                              color:
                                  isSelected
                                      ? Colors.white
                                      : AppTheme.textSecondaryFor(context),
                              fontWeight:
                                  isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Switch setting row
class _SwitchSetting extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchSetting({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(
        title,
        style: GoogleFonts.inter(
          color: AppTheme.textPrimaryFor(context),
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.inter(
          color: AppTheme.textSecondaryFor(context),
          fontSize: 12,
        ),
      ),
      value: value,
      onChanged: onChanged,
      thumbColor: WidgetStateProperty.resolveWith<Color?>((states) {
        return states.contains(WidgetState.selected)
            ? AppTheme.primaryColor
            : AppTheme.textHintFor(context);
      }),
      trackColor: WidgetStateProperty.resolveWith<Color?>((states) {
        return states.contains(WidgetState.selected)
            ? AppTheme.primaryColor.withValues(alpha: 0.3)
            : AppTheme.surfaceColor(context);
      }),
    );
  }
}

/// Info row for displaying static information
class _InfoRow extends StatelessWidget {
  final String title;
  final String value;

  const _InfoRow({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(color: AppTheme.textPrimaryFor(context)),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              color: AppTheme.textSecondaryFor(context),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
