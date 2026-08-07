import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/models/statistics_model.dart';
import 'package:google_fonts/google_fonts.dart';

class RatingGraph extends StatelessWidget {
  final List<EloSnapshot> eloHistory;
  final int currentElo;

  const RatingGraph({
    super.key,
    required this.eloHistory,
    required this.currentElo,
  });

  @override
  Widget build(BuildContext context) {
    if (eloHistory.isEmpty) {
      return Container(
        height: 200,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.cardColor(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderColorFor(context)),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.show_chart_rounded,
                  size: 48, color: AppTheme.textHintFor(context)),
              const SizedBox(height: 12),
              Text(
                'Play games to see your rating graph',
                style: GoogleFonts.inter(
                  color: AppTheme.textSecondaryFor(context),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final spots = <FlSpot>[];
    for (int i = 0; i < eloHistory.length; i++) {
      spots.add(FlSpot(i.toDouble(), eloHistory[i].elo.toDouble()));
    }

    final minElo = math.min(
      currentElo - 100,
      eloHistory.map((e) => e.elo).reduce(math.min),
    ).toDouble();
    final maxElo = math.max(
      currentElo + 100,
      eloHistory.map((e) => e.elo).reduce(math.max),
    ).toDouble();

    return Container(
      height: 220,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColorFor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Rating History',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryFor(context),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _getRatingColor(currentElo).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$currentElo',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _getRatingColor(currentElo),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 50,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: AppTheme.borderColorFor(context).withValues(alpha: 0.3),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      interval: 100,
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
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minY: minElo,
                maxY: maxElo,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.2,
                    color: _getRatingColor(currentElo),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: spots.length <= 20,
                      getDotPainter: (spot, percent, barData, index) =>
                          FlDotCirclePainter(
                        radius: 4,
                        color: _getRatingColor(currentElo),
                        strokeWidth: 2,
                        strokeColor: Colors.white,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: _getRatingColor(currentElo).withValues(alpha: 0.1),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final snapshot = eloHistory[spot.x.toInt()];
                        return LineTooltipItem(
                          'Game ${snapshot.gameNumber}\n${snapshot.elo} ELO',
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
        ],
      ),
    );
  }

  Color _getRatingColor(int elo) {
    if (elo >= 2000) return const Color(0xFF7B1FA2);
    if (elo >= 1800) return const Color(0xFF1E88E5);
    if (elo >= 1600) return const Color(0xFF43A047);
    if (elo >= 1400) return const Color(0xFFFB8C00);
    return const Color(0xFFE53935);
  }
}
