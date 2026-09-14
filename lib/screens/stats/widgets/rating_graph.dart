import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/models/statistics_model.dart';
import 'package:chess_master/widgets/shared/app_card.dart';

class RatingGraph extends StatelessWidget {
  final List<EloSnapshot> eloHistory;
  final int currentElo;
  final int initialElo;

  const RatingGraph({
    super.key,
    required this.eloHistory,
    required this.currentElo,
    this.initialElo = StatisticsModel.defaultGameElo,
  });

  Color _getRatingColor(int elo) => StatisticsModel.getRatingColor(elo);
  String _getRatingTier(int elo) => StatisticsModel.getRatingTier(elo);

  ({String targetTier, int targetElo, int pointsNeeded, double progress})?
      _calculateProgress(int elo) {
    if (elo >= 2200) return null;
    int targetElo;
    int floorElo;
    String targetTier;

    if (elo < 700) {
      targetTier = 'Apprentice';
      floorElo = 400;
      targetElo = 700;
    } else if (elo < 1000) {
      targetTier = 'Club Player';
      floorElo = 700;
      targetElo = 1000;
    } else if (elo < 1400) {
      targetTier = 'Intermediate';
      floorElo = 1000;
      targetElo = 1400;
    } else if (elo < 1800) {
      targetTier = 'Master';
      floorElo = 1400;
      targetElo = 1800;
    } else {
      targetTier = 'Grandmaster';
      floorElo = 1800;
      targetElo = 2200;
    }

    final pointsNeeded = math.max(0, targetElo - elo);
    final progress =
        ((elo - floorElo) / (targetElo - floorElo)).clamp(0.0, 1.0);
    return (
      targetTier: targetTier,
      targetElo: targetElo,
      pointsNeeded: pointsNeeded,
      progress: progress,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = AppTheme.cardColor(context);
    final borderColor = AppTheme.borderColorFor(context);
    final textPrimary = AppTheme.textPrimaryFor(context);
    final textSecondary = AppTheme.textSecondaryFor(context);

    if (eloHistory.isEmpty) {
      return _buildRoadmapEmptyState(
        context,
        cardColor,
        borderColor,
        textPrimary,
        textSecondary,
      );
    }

    final baseline = initialElo;

    // Build spots anchored at Game 0 (initial baseline)
    final spots = <FlSpot>[
      FlSpot(0, baseline.toDouble()),
    ];
    for (int i = 0; i < eloHistory.length; i++) {
      spots.add(FlSpot((i + 1).toDouble(), eloHistory[i].elo.toDouble()));
    }

    final allElos = [baseline, ...eloHistory.map((e) => e.elo), currentElo];
    final minDataElo = allElos.reduce(math.min);
    final maxDataElo = allElos.reduce(math.max);

    // Dynamic clean bounds with padding
    final minElo = math.max(0.0, ((minDataElo - 30) / 50).floor() * 50.0);
    final maxElo = math.max(minElo + 100.0, ((maxDataElo + 30) / 50).ceil() * 50.0);
    final eloColor = _getRatingColor(currentElo);
    final netChange = currentElo - baseline;
    final progressData = _calculateProgress(currentElo);

    return AppCard(
      padding: const EdgeInsets.all(AppTheme.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rating History',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_getRatingTier(currentElo)} • ${eloHistory.length} ${eloHistory.length == 1 ? 'game' : 'games'} played',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  if (netChange != 0)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: netChange > 0
                            ? AppTheme.emeraldGreen.withValues(alpha: 0.15)
                            : Colors.red.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        netChange > 0 ? '+$netChange' : '$netChange',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: netChange > 0 ? AppTheme.emeraldGreen : Colors.red,
                        ),
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: eloColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: eloColor.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      '$currentElo ELO',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: eloColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 50,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: borderColor.withValues(alpha: 0.25),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 38,
                      interval: (maxElo - minElo) > 300 ? 100 : 50,
                      getTitlesWidget: (value, meta) => Text(
                        value.toInt().toString(),
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: AppTheme.textHintFor(context),
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: math.max(1.0, (spots.length / 5).floorToDouble()),
                      getTitlesWidget: (value, meta) {
                        final valInt = value.toInt();
                        if (valInt == 0) {
                          return Text('Start', style: GoogleFonts.inter(fontSize: 10, color: textSecondary));
                        }
                        return Text('G$valInt', style: GoogleFonts.inter(fontSize: 10, color: textSecondary));
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                minY: minElo,
                maxY: maxElo,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.15,
                    color: eloColor,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: spots.length <= 15,
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: 3.5,
                        color: eloColor,
                        strokeWidth: 1.5,
                        strokeColor: Colors.white,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          eloColor.withValues(alpha: 0.25),
                          eloColor.withValues(alpha: 0.02),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final index = spot.x.toInt();
                        if (index == 0) {
                          return LineTooltipItem(
                            'Starting Rating\n$baseline ELO',
                            GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        }
                        final snapshot = eloHistory[index - 1];
                        final prevElo = index == 1 ? baseline : eloHistory[index - 2].elo;
                        final delta = snapshot.elo - prevElo;
                        final deltaStr = delta >= 0 ? '+$delta' : '$delta';
                        return LineTooltipItem(
                          'Game ${snapshot.gameNumber}\n${snapshot.elo} ELO ($deltaStr)',
                          GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
          if (progressData != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLevel2(context),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Next Milestone: ${progressData.targetTier} (${progressData.targetElo} ELO)',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                      Text(
                        '${progressData.pointsNeeded} ELO to go',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: eloColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progressData.progress,
                      minHeight: 6,
                      backgroundColor: borderColor.withValues(alpha: 0.3),
                      valueColor: AlwaysStoppedAnimation<Color>(eloColor),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRoadmapEmptyState(
    BuildContext context,
    Color cardColor,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    final eloColor = _getRatingColor(currentElo);
    final tierName = _getRatingTier(currentElo);

    return AppCard(
      padding: const EdgeInsets.all(AppTheme.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Text(
                'Rating Journey',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: eloColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: eloColor.withValues(alpha: 0.5)),
                ),
                child: Text(
                  '$currentElo ELO • $tierName',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: eloColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Your rating begins at $currentElo ELO ($tierName). Defeat bots to climb the ladder — rating gains advance sequentially while losses dip realistically.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          // Visual Milestone Ladder
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildMilestonePill(context, 'Novice', '400', const Color(0xFF8D6E63), isCurrent: currentElo < 700),
                _buildMilestoneDivider(),
                _buildMilestonePill(context, 'Apprentice', '700', const Color(0xFF00BFA5), isCurrent: currentElo >= 700 && currentElo < 1000),
                _buildMilestoneDivider(),
                _buildMilestonePill(context, 'Club', '1000', const Color(0xFF1E88E5), isCurrent: currentElo >= 1000 && currentElo < 1400),
                _buildMilestoneDivider(),
                _buildMilestonePill(context, 'Intermediate', '1400', const Color(0xFFFFB300), isCurrent: currentElo >= 1400 && currentElo < 1800),
                _buildMilestoneDivider(),
                _buildMilestonePill(context, 'Master', '1800+', const Color(0xFF7B1FA2), isCurrent: currentElo >= 1800),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMilestonePill(
    BuildContext context,
    String title,
    String elo,
    Color color, {
    bool isCurrent = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isCurrent ? color.withValues(alpha: 0.2) : AppTheme.surfaceLevel2(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isCurrent ? color : AppTheme.borderColorFor(context).withValues(alpha: 0.4),
          width: isCurrent ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
              color: isCurrent ? color : AppTheme.textPrimaryFor(context),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            elo,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: isCurrent ? color : AppTheme.textSecondaryFor(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMilestoneDivider() {
    return Container(
      width: 16,
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: Colors.grey.withValues(alpha: 0.3),
    );
  }
}
