import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:chess_master/core/theme/app_theme.dart';

/// Evaluation graph widget showing evaluation over the game
class EvalGraph extends StatelessWidget {
  final List<double> evaluations;
  final int? currentMoveIndex;
  final ValueChanged<int>? onMoveSelected;

  const EvalGraph({
    super.key,
    required this.evaluations,
    this.currentMoveIndex,
    this.onMoveSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (evaluations.isEmpty) {
      return Container(
        height: 120,
        alignment: Alignment.center,
        child: Text(
          'No evaluation data',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }

    // Create spots for the line chart
    final spots = List.generate(
      evaluations.length,
      (i) => FlSpot(i.toDouble(), evaluations[i].clamp(-10.0, 10.0)),
    );

    return Container(
      height: 120,
      padding: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: LineChart(
        LineChartData(
          minY: -10,
          maxY: 10,
          minX: 0,
          maxX: (evaluations.length - 1).toDouble(),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 5,
            getDrawingHorizontalLine: (value) {
              if (value == 0) {
                return FlLine(color: Colors.grey[500]!, strokeWidth: 1);
              }
              return FlLine(
                color: Colors.grey[800]!,
                strokeWidth: 0.5,
                dashArray: [5, 5],
              );
            },
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                interval: _calculateInterval(evaluations.length),
                getTitlesWidget: (value, meta) {
                  if (value == meta.max || value == meta.min) {
                    return const SizedBox.shrink();
                  }
                  final moveNum = (value ~/ 2) + 1;
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      '$moveNum',
                      style: TextStyle(color: AppTheme.textHint, fontSize: 10),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                interval: 5,
                getTitlesWidget: (value, meta) {
                  if (value == -10 || value == 10) {
                    return const SizedBox.shrink();
                  }
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      value.toInt().toString(),
                      style: TextStyle(color: AppTheme.textHint, fontSize: 10),
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.2,
              color: Colors.transparent,
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  final isSelected = index == currentMoveIndex;
                  final color = spot.y >= 0 ? Colors.white : Colors.grey[800]!;
                  return FlDotCirclePainter(
                    radius: isSelected ? 5 : 2,
                    color: color,
                    strokeWidth: isSelected ? 2 : 0,
                    strokeColor: AppTheme.primaryColor,
                  );
                },
                checkToShowDot: (spot, barData) {
                  // Show fewer dots for long games
                  if (evaluations.length > 60) {
                    return spot.x.toInt() == currentMoveIndex ||
                        spot.x.toInt() % 10 == 0;
                  }
                  if (evaluations.length > 30) {
                    return spot.x.toInt() == currentMoveIndex ||
                        spot.x.toInt() % 5 == 0;
                  }
                  return true;
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(0.3),
                    Colors.white.withOpacity(0.1),
                    Colors.transparent,
                    Colors.black.withOpacity(0.1),
                    Colors.black.withOpacity(0.3),
                  ],
                  stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
                ),
              ),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white,
                  Colors.grey[400]!,
                  Colors.grey[600]!,
                  Colors.grey[800]!,
                ],
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            enabled: true,
            touchCallback: (event, response) {
              if (event is FlTapUpEvent && response?.lineBarSpots != null) {
                final spot = response!.lineBarSpots!.first;
                onMoveSelected?.call(spot.x.toInt());
              }
            },
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (touchedSpot) => AppTheme.surfaceDark,
              tooltipRoundedRadius: 8,
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final moveNum = (spot.x ~/ 2) + 1;
                  final isWhiteMove = spot.x.toInt() % 2 == 0;
                  final sign = spot.y >= 0 ? '+' : '';
                  return LineTooltipItem(
                    'Move $moveNum${isWhiteMove ? '' : '...'}\n$sign${spot.y.toStringAsFixed(2)}',
                    const TextStyle(color: Colors.white, fontSize: 12),
                  );
                }).toList();
              },
            ),
          ),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(y: 0, color: Colors.grey[500]!, strokeWidth: 1),
            ],
            verticalLines: currentMoveIndex != null
                ? [
                    VerticalLine(
                      x: currentMoveIndex!.toDouble(),
                      color: AppTheme.primaryColor,
                      strokeWidth: 2,
                      dashArray: [5, 3],
                    ),
                  ]
                : [],
          ),
        ),
      ),
    );
  }

  double _calculateInterval(int length) {
    if (length > 100) return 20;
    if (length > 60) return 10;
    if (length > 30) return 5;
    return 2;
  }
}
