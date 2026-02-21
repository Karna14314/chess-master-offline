import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/core/theme/board_themes.dart';
import 'package:chess_master/core/constants/app_constants.dart';
import 'package:chess_master/providers/settings_provider.dart';
import 'package:chess_master/screens/game/widgets/chess_piece.dart';
import 'package:google_fonts/google_fonts.dart';

/// Settings screen for app customization
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120.0,
            floating: false,
            pinned: true,
            backgroundColor: AppTheme.surfaceDark,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'Settings',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.surfaceDark, AppTheme.backgroundDark],
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
                  _BoardThemeSelector(
                    currentTheme: settings.boardTheme,
                    onChanged: (theme) => settingsNotifier.setBoardTheme(theme),
                  ),
                  const Divider(color: AppTheme.borderColor),
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
                    subtitle: 'Display a-h and 1-8 labels',
                    value: settings.showCoordinates,
                    onChanged: (_) => settingsNotifier.toggleCoordinates(),
                  ),
                  const Divider(color: AppTheme.borderColor),
                  _SwitchSetting(
                    title: 'Show Legal Moves',
                    subtitle: 'Highlight available moves',
                    value: settings.showLegalMoves,
                    onChanged: (_) => settingsNotifier.toggleLegalMoves(),
                  ),
                  const Divider(color: AppTheme.borderColor),
                  _SwitchSetting(
                    title: 'Show Last Move',
                    subtitle: 'Highlight the last played move',
                    value: settings.showLastMove,
                    onChanged: (_) => settingsNotifier.toggleLastMove(),
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
                  const Divider(color: AppTheme.borderColor),
                  _SwitchSetting(
                    title: 'Sound Effects',
                    subtitle: 'Play sounds for moves',
                    value: settings.soundEnabled,
                    onChanged: (_) => settingsNotifier.toggleSound(),
                  ),
                  const Divider(color: AppTheme.borderColor),
                  _SwitchSetting(
                    title: 'Vibration',
                    subtitle: 'Haptic feedback on moves',
                    value: settings.vibrationEnabled,
                    onChanged: (_) => settingsNotifier.toggleVibration(),
                  ),
                ]),
                const SizedBox(height: 24),

                // About Section
                _buildSectionHeader(context, 'About', Icons.info_outline),
                const SizedBox(height: 12),
                _buildSettingsCard(context, [
                  _InfoRow(
                    title: 'App Version',
                    value: AppConstants.appVersion,
                  ),
                  const Divider(color: AppTheme.borderColor),
                  _InfoRow(title: 'Engine', value: 'Stockfish 16'),
                  const Divider(color: AppTheme.borderColor),
                  ListTile(
                    title: Text(
                      'Licenses',
                      style: GoogleFonts.inter(color: AppTheme.textPrimary),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: AppTheme.textSecondary,
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
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
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
              color: AppTheme.textPrimary,
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
                                  : Colors.grey.withOpacity(0.3),
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
                                    color: AppTheme.primaryColor.withOpacity(
                                      0.4,
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
                                : AppTheme.textSecondary,
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
              color: AppTheme.textPrimary,
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
                            ? AppTheme.primaryColor.withOpacity(0.1)
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
                                  : AppTheme.textSecondary,
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
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
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
                                      : AppTheme.textSecondary,
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
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 12),
      ),
      value: value,
      onChanged: onChanged,
      activeColor: AppTheme.primaryColor,
      activeTrackColor: AppTheme.primaryColor.withOpacity(0.4),
      inactiveThumbColor: AppTheme.textHint,
      inactiveTrackColor: AppTheme.surfaceDark,
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
          Text(title, style: GoogleFonts.inter(color: AppTheme.textPrimary)),
          Text(
            value,
            style: GoogleFonts.inter(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
