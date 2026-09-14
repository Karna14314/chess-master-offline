import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:chess_master/core/services/lesson_service.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/screens/lessons/lesson_player_screen.dart';
import 'package:chess_master/screens/openings/opening_playbook_screen.dart';
import 'package:chess_master/widgets/shared/app_card.dart';

const Color _accentGold = Color(0xFFF59E0B);
const Color _successGreen = Color(0xFF2E7D32);

class LessonsScreen extends ConsumerStatefulWidget {
  const LessonsScreen({super.key});

  @override
  ConsumerState<LessonsScreen> createState() => _LessonsScreenState();
}

class _LessonsScreenState extends ConsumerState<LessonsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedDifficulty = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'beginner':
        return AppTheme.success;
      case 'intermediate':
        return Colors.blueAccent;
      case 'advanced':
        return Colors.orangeAccent;
      case 'expert':
        return Colors.purpleAccent;
      default:
        return const Color(0xFFF59E0B);
    }
  }

  IconData _getCategoryIcon(String iconName) {
    switch (iconName.toLowerCase()) {
      case 'shield':
        return Icons.shield_rounded;
      case 'bolt':
      case 'zap':
        return Icons.bolt_rounded;
      case 'crosshair':
      case 'target':
        return Icons.gps_fixed_rounded;
      case 'lock':
        return Icons.lock_outline_rounded;
      case 'star':
        return Icons.star_border_rounded;
      case 'award':
      case 'crown':
        return Icons.emoji_events_rounded;
      case 'pin':
        return Icons.push_pin_rounded;
      case 'arrow_right':
        return Icons.trending_flat_rounded;
      case 'fork':
      case 'swords':
        return Icons.call_split_rounded;
      case 'eye':
        return Icons.visibility_outlined;
      case 'layers':
        return Icons.layers_outlined;
      case 'clock':
        return Icons.hourglass_empty_rounded;
      case 'maximize':
        return Icons.fullscreen_rounded;
      case 'hand':
        return Icons.pan_tool_outlined;
      case 'scissors':
        return Icons.content_cut_rounded;
      case 'gift':
        return Icons.card_giftcard_rounded;
      case 'shuffle':
        return Icons.shuffle_rounded;
      case 'magnet':
        return Icons.attractions_rounded;
      case 'chevrons_up':
        return Icons.keyboard_double_arrow_up_rounded;
      case 'skull':
        return Icons.dangerous_outlined;
      case 'shield_alert':
        return Icons.shield_moon_rounded;
      case 'hammer':
        return Icons.gavel_rounded;
      case 'wind':
        return Icons.air_rounded;
      case 'key':
        return Icons.key_rounded;
      case 'users':
        return Icons.people_outline_rounded;
      case 'castle':
        return Icons.fort_rounded;
      case 'columns':
        return Icons.view_column_rounded;
      case 'activity':
        return Icons.auto_graph_rounded;
      case 'flag':
        return Icons.flag_rounded;
      default:
        return Icons.menu_book_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lessonService = LessonService.instance;
    final sections = lessonService.sections;
    final totalChapters = lessonService.totalChaptersCount;
    final completedChapters = lessonService.completedChaptersCount;
    final overallProgress = totalChapters > 0 ? (completedChapters / totalChapters) : 0.0;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Chess Lessons',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.menu_book_rounded),
            tooltip: 'Opening Playbook',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const OpeningPlaybookScreen()),
              );
            },
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // 1. Overall Progress Header Card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: AppCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _accentGold.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.school_rounded,
                            color: _accentGold,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Structured Mastery Curriculum',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimaryFor(context),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$completedChapters of $totalChapters Exercises Mastered (${(overallProgress * 100).toInt()}%)',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: AppTheme.textHintFor(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: overallProgress,
                        minHeight: 8,
                        backgroundColor: Colors.grey.withValues(alpha: 0.2),
                        valueColor: const AlwaysStoppedAnimation<Color>(_accentGold),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Shortcut to Opening Playbook
                    InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const OpeningPlaybookScreen()),
                        );
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: _accentGold.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _accentGold.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.auto_stories_rounded,
                              size: 16,
                              color: _accentGold,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Explore Master Opening Playbook (50+ Openings)',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _accentGold,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 12,
                              color: _accentGold,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 2. Search & Filter Bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Search 40+ categories (e.g. Pin, Fork, Back Rank)...',
                      hintStyle: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppTheme.textHintFor(context),
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: AppTheme.textHintFor(context),
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: AppTheme.cardColor(context),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Difficulty Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['All', 'Beginner', 'Intermediate', 'Advanced', 'Expert']
                          .map((diff) {
                        final isSelected = _selectedDifficulty == diff;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(
                              diff,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected ? Colors.black : AppTheme.textPrimaryFor(context),
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: _accentGold,
                            backgroundColor: AppTheme.cardColor(context),
                            checkmarkColor: Colors.black,
                            onSelected: (_) {
                              setState(() => _selectedDifficulty = diff);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 12)),

          // 3. Sections and 40+ Categories
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, sectionIndex) {
                final section = sections[sectionIndex];

                // Filter categories within section
                final filteredCategories = section.categories.where((cat) {
                  final matchesDifficulty = _selectedDifficulty == 'All' ||
                      cat.difficulty.toLowerCase() == _selectedDifficulty.toLowerCase();
                  final q = _searchQuery.trim().toLowerCase();
                  final matchesQuery = q.isEmpty ||
                      cat.title.toLowerCase().contains(q) ||
                      cat.subtitle.toLowerCase().contains(q);
                  return matchesDifficulty && matchesQuery;
                }).toList();

                if (filteredCategories.isEmpty) {
                  return const SizedBox();
                }

                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section Header
                      Row(
                        children: [
                          Icon(
                            _getCategoryIcon(section.icon),
                            size: 18,
                            color: _accentGold,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            section.title,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimaryFor(context),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${filteredCategories.length} topics',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppTheme.textHintFor(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        section.description,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppTheme.textHintFor(context),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Category Cards
                      ...filteredCategories.map((cat) {
                        final progress = lessonService.getCategoryProgress(cat.id);
                        final completed = lessonService.getCompletedCount(cat.id);
                        final total = cat.chapterIds.length;
                        final isFullyCompleted = completed >= total && total > 0;
                        final diffColor = _getDifficultyColor(cat.difficulty);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: AppCard(
                            onTap: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => LessonPlayerScreen(categoryId: cat.id),
                                ),
                              );
                              // Refresh progress upon return
                              setState(() {});
                            },
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                // Category Icon
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: isFullyCompleted
                                        ? _successGreen.withValues(alpha: 0.15)
                                        : AppTheme.cardColor(context),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isFullyCompleted
                                          ? _successGreen
                                          : Colors.grey.withValues(alpha: 0.2),
                                    ),
                                  ),
                                  child: Icon(
                                    isFullyCompleted
                                        ? Icons.check_circle_rounded
                                        : _getCategoryIcon(cat.icon),
                                    color: isFullyCompleted
                                        ? _successGreen
                                        : _accentGold,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 14),

                                // Title, Subtitle, and Progress
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              cat.title,
                                              style: GoogleFonts.inter(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                                color: AppTheme.textPrimaryFor(context),
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: diffColor.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              cat.difficulty,
                                              style: GoogleFonts.inter(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: diffColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        cat.subtitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: AppTheme.textHintFor(context),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(3),
                                              child: LinearProgressIndicator(
                                                value: progress,
                                                minHeight: 4,
                                                backgroundColor:
                                                    Colors.grey.withValues(alpha: 0.2),
                                                valueColor: AlwaysStoppedAnimation<Color>(
                                                  isFullyCompleted
                                                      ? _successGreen
                                                      : _accentGold,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            '$completed/$total',
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: AppTheme.textHintFor(context),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: AppTheme.textHintFor(context),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                );
              },
              childCount: sections.length,
            ),
          ),
        ],
      ),
    );
  }
}
