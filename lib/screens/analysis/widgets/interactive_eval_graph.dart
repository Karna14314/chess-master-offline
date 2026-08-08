import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class InteractiveEvalGraph extends StatelessWidget {
  /// Evaluation series where index i is the position AFTER i plies, so
  /// index 0 is the starting position and the list has plies + 1 entries.
  final List<double> evaluations;

  /// Currently selected ply index, where -1 means "start position"
  /// (before any move has been played).
  final int? currentMoveIndex;

  /// Called with a ply index (-1 == start position).
  final ValueChanged<int>? onMoveSelected;

  const InteractiveEvalGraph({
    super.key,
    required this.evaluations,
    this.currentMoveIndex,
    this.onMoveSelected,
  });

  /// Convert a ply index (-1 == start) to an x coordinate on the graph.
  int _plyToX(int ply) => ply + 1;

  /// Convert an x coordinate on the graph back to a ply index (-1 == start).
  int _xToPly(int x) => x - 1;

  @override
  Widget build(BuildContext context) {
    if (evaluations.isEmpty) {
      return Container(
        height: 160,
        alignment: Alignment.center,
        child: Text(
          'No evaluation data',
          style: GoogleFonts.inter(color: AppTheme.textSecondaryFor(context)),
        ),
      );
    }

    // Create spots for the line chart. x == number of plies played, so x=0 is
    // the starting position and x=n is the position after ply n.
    final spots = List.generate(
      evaluations.length,
      (i) => FlSpot(i.toDouble(), evaluations[i].clamp(-10.0, 10.0)),
    );

    // Selected ply mapped into graph x-space and clamped to the plotted range,
    // so the marker stays correct at the start position and at the last ply.
    final int? selectedX = currentMoveIndex == null
        ? null
        : _plyToX(currentMoveIndex!).clamp(0, evaluations.length - 1);

    return Container(
      height: 180, // Increased height for better interaction and visibility
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.only(right: 16, top: 16, bottom: 8, left: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColorFor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8),
            child: Text(
              'Evaluation Graph',
              style: GoogleFonts.inter(
                color: AppTheme.textPrimaryFor(context),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          Expanded(
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
                      return FlLine(
                        color: AppTheme.textHintFor(context).withValues(alpha: 0.3),
                        strokeWidth: 1.5,
                      );
                    }
                    return FlLine(
                      color: AppTheme.textHintFor(context).withValues(alpha: 0.1),
                      strokeWidth: 1,
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
                        // x is plies played; ply 1-2 => move 1, 3-4 => move 2.
                        final moveNum = ((value.toInt() - 1) ~/ 2) + 1;
                        return SideTitleWidget(
                          meta: meta,
                          child: Text(
                            '$moveNum',
                            style: GoogleFonts.inter(
                              color: AppTheme.textHintFor(context),
                              fontSize: 10,
                            ),
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
                            style: GoogleFonts.inter(
                              color: AppTheme.textHintFor(context),
                              fontSize: 10,
                            ),
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
                    color: Colors.transparent, // We use gradient
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        final isSelected = index == selectedX;
                        final color =
                            spot.y >= 0
                                ? Colors.white
                                : const Color(0xFF303030);
                        return FlDotCirclePainter(
                          radius: isSelected ? 6 : 0,
                          color: color,
                          strokeWidth: isSelected ? 3 : 0,
                          strokeColor: AppTheme.primaryColor,
                        );
                      },
                      checkToShowDot: (spot, barData) {
                        return spot.x.toInt() == selectedX;
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.3),
                          Colors.white.withValues(alpha: 0.05),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.05),
                          Colors.black.withValues(alpha: 0.3),
                        ],
                        stops: const [0.0, 0.45, 0.5, 0.55, 1.0],
                      ),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white,
                        Colors.grey[400]!,
                        Colors.grey[600]!,
                        const Color(0xFF303030),
                      ],
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  enabled: true,
                  handleBuiltInTouches: true,
                  touchCallback: (event, response) {
                    if (event is FlTapUpEvent &&
                        response?.lineBarSpots != null) {
                      final spot = response!.lineBarSpots!.first;
                      // x is a position index; convert back to a ply index.
                      onMoveSelected?.call(_xToPly(spot.x.toInt()));
                    }
                  },
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (touchedSpot) => AppTheme.surfaceColor(context),
                    tooltipRoundedRadius: 12,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final ply = _xToPly(spot.x.toInt());
                        final sign = spot.y >= 0 ? '+' : '';
                        if (ply < 0) {
                          return LineTooltipItem(
                            'Start\n$sign${spot.y.toStringAsFixed(2)}',
                            GoogleFonts.spaceMono(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        }
                        final moveNum = (ply ~/ 2) + 1;
                        final isWhiteMove = ply % 2 == 0;
                        return LineTooltipItem(
                          'Move $moveNum${isWhiteMove ? '' : '...'}\n$sign${spot.y.toStringAsFixed(2)}',
                          GoogleFonts.spaceMono(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: 0,
                      color: AppTheme.textHintFor(context).withValues(alpha: 0.5),
                      strokeWidth: 1.5,
                    ),
                  ],
                  verticalLines:
                      selectedX != null
                          ? [
                            VerticalLine(
                              x: selectedX.toDouble(),
                              color: AppTheme.primaryColor,
                              strokeWidth: 2,
                              dashArray: [5, 5],
                            ),
                          ]
                          : [],
                ),
              ),
            ),
          ),
        ],
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
