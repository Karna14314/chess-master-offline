import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/core/theme/board_themes.dart';
import 'package:chess_master/core/constants/app_constants.dart';
import 'package:chess_master/providers/settings_provider.dart';

/// Settings screen for app customization
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppTheme.surfaceDark,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Board Settings
            _buildSectionHeader(context, 'Board', Icons.grid_on),
            _buildSettingsCard([
              _BoardThemeSelector(
                currentTheme: settings.boardTheme,
                onChanged: (theme) => settingsNotifier.setBoardTheme(theme),
              ),
              const Divider(color: AppTheme.surfaceDark),
              _PieceSetSelector(
                currentSet: settings.pieceSet,
                onChanged: (set) => settingsNotifier.setPieceSet(set),
              ),
              const Divider(color: AppTheme.surfaceDark),
              _SwitchSetting(
                title: 'Show Coordinates',
                subtitle: 'Display a-h and 1-8 labels',
                value: settings.showCoordinates,
                onChanged: (_) => settingsNotifier.toggleCoordinates(),
              ),
              const Divider(color: AppTheme.surfaceDark),
              _SwitchSetting(
                title: 'Show Legal Moves',
                subtitle: 'Highlight available moves when selecting a piece',
                value: settings.showLegalMoves,
                onChanged: (_) => settingsNotifier.toggleLegalMoves(),
              ),
              const Divider(color: AppTheme.surfaceDark),
              _SwitchSetting(
                title: 'Show Last Move',
                subtitle: 'Highlight the last move played',
                value: settings.showLastMove,
                onChanged: (_) => settingsNotifier.toggleLastMove(),
              ),
            ]),
            const SizedBox(height: 24),

            // Animation Settings
            _buildSectionHeader(context, 'Animation', Icons.animation),
            _buildSettingsCard([
              _AnimationSpeedSelector(
                currentSpeed: settings.animationSpeed,
                onChanged: (speed) => settingsNotifier.setAnimationSpeed(speed),
              ),
            ]),
            const SizedBox(height: 24),

            // Sound & Haptics
            _buildSectionHeader(context, 'Sound & Haptics', Icons.volume_up),
            _buildSettingsCard([
              _SwitchSetting(
                title: 'Sound Effects',
                subtitle: 'Play sounds for moves, captures, etc.',
                value: settings.soundEnabled,
                onChanged: (_) => settingsNotifier.toggleSound(),
              ),
              const Divider(color: AppTheme.surfaceDark),
              _SwitchSetting(
                title: 'Vibration',
                subtitle: 'Vibrate on moves and events',
                value: settings.vibrationEnabled,
                onChanged: (_) => settingsNotifier.toggleVibration(),
              ),
            ]),
            const SizedBox(height: 24),

            // About Section
            _buildSectionHeader(context, 'About', Icons.info),
            _buildSettingsCard([
              _InfoRow(title: 'App Version', value: AppConstants.appVersion),
              const Divider(color: AppTheme.surfaceDark),
              _InfoRow(title: 'Engine', value: 'Stockfish'),
              const Divider(color: AppTheme.surfaceDark),
              ListTile(
                title: const Text('Licenses'),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: AppTheme.textHint,
                ),
                onTap: () => _showLicenses(context),
              ),
            ]),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: children),
    );
  }

  void _showLicenses(BuildContext context) {
    showLicensePage(
      context: context,
      applicationName: AppConstants.appName,
      applicationVersion: AppConstants.appVersion,
    );
  }
}

/// Board theme selector
class _BoardThemeSelector extends StatelessWidget {
  final BoardThemeType currentTheme;
  final ValueChanged<BoardThemeType> onChanged;

  const _BoardThemeSelector({
    required this.currentTheme,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Board Theme', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Row(
            children:
                BoardThemeType.values.map((theme) {
                  final boardTheme = BoardTheme.fromType(theme);
                  final isSelected = currentTheme == theme;

                  return Expanded(
                    child: GestureDetector(
                      onTap: () => onChanged(theme),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color:
                                isSelected
                                    ? AppTheme.primaryColor
                                    : Colors.transparent,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            // Mini board preview
                            SizedBox(
                              height: 48,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      children: [
                                        Expanded(
                                          child: Container(
                                            color: boardTheme.lightSquare,
                                          ),
                                        ),
                                        Expanded(
                                          child: Container(
                                            color: boardTheme.darkSquare,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      children: [
                                        Expanded(
                                          child: Container(
                                            color: boardTheme.darkSquare,
                                          ),
                                        ),
                                        Expanded(
                                          child: Container(
                                            color: boardTheme.lightSquare,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              boardTheme.name,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight:
                                    isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                color:
                                    isSelected
                                        ? AppTheme.primaryColor
                                        : AppTheme.textPrimary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }
}

/// Piece set selector
class _PieceSetSelector extends StatelessWidget {
  final PieceSetType currentSet;
  final ValueChanged<PieceSetType> onChanged;

  const _PieceSetSelector({required this.currentSet, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Piece Set', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Row(
            children:
                PieceSetType.values.map((set) {
                  final pieceSet = PieceSet.fromType(set);
                  final isSelected = currentSet == set;

                  return Expanded(
                    child: GestureDetector(
                      onTap: () => onChanged(set),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color:
                                isSelected
                                    ? AppTheme.primaryColor
                                    : Colors.transparent,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          color:
                              isSelected
                                  ? AppTheme.primaryColor.withValues(alpha: 0.1)
                                  : Colors.transparent,
                        ),
                        child: Column(
                          children: [
                            // Piece preview using Unicode
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Text('♔', style: TextStyle(fontSize: 28)),
                                Text('♚', style: TextStyle(fontSize: 28)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              pieceSet.name,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight:
                                    isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                color:
                                    isSelected
                                        ? AppTheme.primaryColor
                                        : AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
          ),
        ],
      ),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Move Animation Speed',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                currentSpeed.label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children:
                AnimationSpeed.values.map((speed) {
                  final isSelected = currentSpeed == speed;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => onChanged(speed),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color:
                              isSelected
                                  ? AppTheme.primaryColor
                                  : AppTheme.surfaceDark,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            speed.label,
                            style: TextStyle(
                              color:
                                  isSelected
                                      ? Colors.white
                                      : AppTheme.textPrimary,
                              fontWeight:
                                  isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
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
      title: Text(title),
      subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      value: value,
      onChanged: onChanged,
      activeColor: AppTheme.primaryColor,
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
          Text(title),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}
