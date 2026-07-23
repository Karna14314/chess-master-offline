import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/core/constants/app_constants.dart';
import 'package:chess_master/providers/settings_provider.dart';
import 'package:chess_master/screens/stats/statistics_screen.dart';
import 'package:chess_master/screens/settings/settings_screen.dart';
import 'package:chess_master/core/services/diagnostics_service.dart';

/// More screen - contains settings, stats, cross-promotion, and additional options
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(context),
              const SizedBox(height: 24),

              // Quick Stats Card
              _buildQuickStatsCard(context, ref),
              const SizedBox(height: 24),

              // Menu Options
              _buildMenuSection(context, ref),
              const SizedBox(height: 24),

              // Our Other Games (Karna Digital Cross-Promotion)
              _buildOurGamesSection(context),
              const SizedBox(height: 24),

              // Settings Section
              _buildSettingsSection(context, ref, settings),
              const SizedBox(height: 24),

              // About Section
              _buildAboutSection(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final cardColor = Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface;
    final iconColor = Theme.of(context).colorScheme.onSurface;

    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).dividerTheme.color ?? AppTheme.borderColor,
            ),
          ),
          child: Center(
            child: Icon(Icons.tune_outlined, size: 28, color: iconColor),
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Settings & More',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              'Customize your experience & explore games',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppTheme.textSecondary
                        : AppTheme.textSecondaryLight,
                  ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickStatsCard(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.2),
            AppTheme.primaryLight.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Text(
                'Your Stats',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const StatisticsScreen(),
                    ),
                  );
                },
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Row(
            children: [
              Expanded(
                child: _StatItem(
                  label: 'Games',
                  value: '0',
                  icon: Icons.sports_esports,
                ),
              ),
              Expanded(
                child: _StatItem(
                  label: 'Win Rate',
                  value: '0%',
                  icon: Icons.emoji_events,
                ),
              ),
              Expanded(
                child: _StatItem(
                  label: 'Puzzles',
                  value: '0',
                  icon: Icons.extension,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection(BuildContext context, WidgetRef ref) {
    final cardColor = Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface;
    final borderColor = Theme.of(context).dividerTheme.color ?? AppTheme.borderColor;

    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          children: [
            _buildMenuItem(
              context,
              icon: Icons.bar_chart_rounded,
              title: 'Statistics',
              subtitle: 'View your game history and stats',
              color: Colors.blue,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const StatisticsScreen(),
                  ),
                );
              },
            ),
            Divider(height: 1, color: borderColor),
            _buildMenuItem(
              context,
              icon: Icons.settings_rounded,
              title: 'Settings',
              subtitle: 'Board theme, sounds, and preferences',
              color: Colors.grey,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
              },
            ),
            Divider(height: 1, color: borderColor),
            _buildMenuItem(
              context,
              icon: Icons.bug_report_rounded,
              title: 'Diagnostic Logs',
              subtitle: 'Share error logs via native OS share sheet',
              color: Colors.teal,
              onTap: () async {
                final success = await LocalDiagnosticsService.instance.exportLogFile();
                if (!success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No diagnostic log available to export')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOurGamesSection(BuildContext context) {
    final cardColor = Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface;
    final borderColor = Theme.of(context).dividerTheme.color ?? AppTheme.borderColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Row(
            children: [
              const Icon(
                Icons.sports_esports_outlined,
                color: AppTheme.primaryColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Explore Karna Digital Games',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
        ),
        Material(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                _buildGameTile(
                  context,
                  title: 'Mahjong Master Offline',
                  subtitle: 'Classic tile-matching puzzle, 100% ad-free',
                  icon: Icons.grid_view_rounded,
                  color: Colors.amber,
                  packageName: 'com.karna.mahjong',
                ),
                Divider(height: 1, color: borderColor),
                _buildGameTile(
                  context,
                  title: 'Block Puzzle Master',
                  subtitle: 'Addictive block logic challenge offline',
                  icon: Icons.category_rounded,
                  color: Colors.deepOrange,
                  packageName: 'com.karna.blockpuzzle',
                ),
                Divider(height: 1, color: borderColor),
                _buildGameTile(
                  context,
                  title: 'Sudoku Master Offline',
                  subtitle: 'Pure logic Sudoku with unlimited puzzles',
                  icon: Icons.filter_9_plus_rounded,
                  color: Colors.teal,
                  packageName: 'com.karna.sudoku',
                ),
                Divider(height: 1, color: borderColor),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.storefront_rounded,
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'More Ad-Free Games',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  subtitle: Text(
                    'Browse all games on Google Play',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  trailing: const Icon(
                    Icons.open_in_new,
                    size: 18,
                    color: AppTheme.primaryColor,
                  ),
                  onTap: () => _launchUrl(
                    context,
                    'https://play.google.com/store/apps/developer?id=Karna+Digital',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGameTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String packageName,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
      subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      trailing: OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          minimumSize: const Size(60, 32),
          side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.5)),
        ),
        onPressed: () => _launchUrl(
          context,
          'market://details?id=$packageName',
          fallbackWebUrl:
              'https://play.google.com/store/apps/details?id=$packageName',
        ),
        child: const Text('Get', style: TextStyle(fontSize: 12)),
      ),
    );
  }

  Widget _buildSettingsSection(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
    final cardColor = Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface;
    final borderColor = Theme.of(context).dividerTheme.color ?? AppTheme.borderColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Quick Settings',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        Material(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                // Sound toggle
                SwitchListTile(
                  title: const Text('Sound Effects'),
                  subtitle: const Text('Move sounds and alerts'),
                  secondary: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.volume_up,
                      color: Colors.orange,
                      size: 20,
                    ),
                  ),
                  value: settings.soundEnabled,
                  onChanged: (value) {
                    ref.read(settingsProvider.notifier).toggleSound();
                  },
                ),
                Divider(height: 1, color: borderColor),
                // Show legal moves toggle
                SwitchListTile(
                  title: const Text('Show Legal Moves'),
                  subtitle: const Text('Highlight possible moves'),
                  secondary: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.visibility,
                      color: Colors.green,
                      size: 20,
                    ),
                  ),
                  value: settings.showLegalMoves,
                  onChanged: (value) {
                    ref.read(settingsProvider.notifier).toggleShowLegalMoves();
                  },
                ),
                Divider(height: 1, color: borderColor),
                // Show coordinates toggle
                SwitchListTile(
                  title: const Text('Show Coordinates'),
                  subtitle: const Text('Display a-h and 1-8'),
                  secondary: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.purple.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.grid_3x3,
                      color: Colors.purple,
                      size: 20,
                    ),
                  ),
                  value: settings.showCoordinates,
                  onChanged: (value) {
                    ref.read(settingsProvider.notifier).toggleCoordinates();
                  },
                ),
                Divider(height: 1, color: borderColor),
                // Auto flip board toggle
                SwitchListTile(
                  title: const Text('Auto Flip Board'),
                  subtitle: const Text('Flip board for black pieces'),
                  secondary: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.flip, color: Colors.blue, size: 20),
                  ),
                  value: settings.autoFlipBoard,
                  onChanged: (value) {
                    ref.read(settingsProvider.notifier).toggleAutoFlipBoard();
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAboutSection(BuildContext context) {
    final cardColor = Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface;
    final borderColor = Theme.of(context).dividerTheme.color ?? AppTheme.borderColor;

    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primaryColor, AppTheme.primaryLight],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text(
                      '♔',
                      style: TextStyle(fontSize: 24, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppConstants.appName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Version ${AppConstants.appVersion}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'A complete offline chess experience with AI opponent, puzzles, and analysis.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppTheme.textHint),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchUrl(
    BuildContext context,
    String primaryUrl, {
    String? fallbackWebUrl,
  }) async {
    final primaryUri = Uri.parse(primaryUrl);
    try {
      if (await canLaunchUrl(primaryUri)) {
        await launchUrl(primaryUri, mode: LaunchMode.externalApplication);
        return;
      }
      if (fallbackWebUrl != null) {
        final fallbackUri = Uri.parse(fallbackWebUrl);
        if (await canLaunchUrl(fallbackUri)) {
          await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
          return;
        }
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link')),
        );
      }
    }
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 24, color: AppTheme.primaryColor),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
