import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/screens/lessons/lessons_screen.dart';
import 'package:chess_master/screens/openings/opening_playbook_screen.dart';
import 'package:chess_master/screens/analysis/analysis_menu_screen.dart';

/// Provider for managing the selected segment index in LearnScreen
final learnSegmentProvider = StateNotifierProvider<LearnSegmentNotifier, int>((ref) {
  return LearnSegmentNotifier();
});

class LearnSegmentNotifier extends StateNotifier<int> {
  LearnSegmentNotifier() : super(0) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = (prefs.getInt('last_selected_learn_segment') ?? 0).clamp(0, 2);
    } catch (_) {}
  }

  void setSegment(int index) async {
    state = index.clamp(0, 2);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('last_selected_learn_segment', index);
    } catch (_) {}
  }
}

/// Centralized Learn Hub featuring Lessons, Openings, and Review
class LearnScreen extends ConsumerWidget {
  final int? initialSegment;

  const LearnScreen({super.key, this.initialSegment});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (initialSegment != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(learnSegmentProvider.notifier).setSegment(initialSegment!);
      });
    }

    final currentSegment = ref.watch(learnSegmentProvider);
    final textPrimary = AppTheme.textPrimaryFor(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Learn',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: textPrimary,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.surfaceLevel2(context),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppTheme.borderStroke(context)),
              ),
              child: Row(
                children: [
                  _buildSegmentButton(context, ref, label: 'Lessons', index: 0, activeIndex: currentSegment),
                  _buildSegmentButton(context, ref, label: 'Openings', index: 1, activeIndex: currentSegment),
                  _buildSegmentButton(context, ref, label: 'Review', index: 2, activeIndex: currentSegment),
                ],
              ),
            ),
          ),
        ),
      ),
      body: IndexedStack(
        index: currentSegment,
        children: const [
          LessonsScreen(),
          OpeningPlaybookScreen(),
          AnalysisMenuScreen(),
        ],
      ),
    );
  }

  Widget _buildSegmentButton(
    BuildContext context,
    WidgetRef ref, {
    required String label,
    required int index,
    required int activeIndex,
  }) {
    final isSelected = index == activeIndex;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          ref.read(learnSegmentProvider.notifier).setSegment(index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? Colors.white : AppTheme.textSecondaryFor(context),
            ),
          ),
        ),
      ),
    );
  }
}
