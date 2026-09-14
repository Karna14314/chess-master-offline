import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:chess/chess.dart' as chess;
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/core/constants/app_constants.dart';
import 'package:chess_master/core/models/opening_book.dart';
import 'package:chess_master/core/services/opening_service.dart';
import 'package:chess_master/providers/game_session_viewmodel.dart';
import 'package:chess_master/screens/game/game_screen.dart';
import 'package:chess_master/screens/game/widgets/chess_board.dart';
import 'package:chess_master/widgets/shared/app_card.dart';
import 'package:chess_master/widgets/shared/themed_board_container.dart';

class OpeningPlaybookScreen extends ConsumerStatefulWidget {
  const OpeningPlaybookScreen({super.key});

  @override
  ConsumerState<OpeningPlaybookScreen> createState() =>
      _OpeningPlaybookScreenState();
}

class _OpeningPlaybookScreenState extends ConsumerState<OpeningPlaybookScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<OpeningEntry> _getFilteredOpenings() {
    final service = OpeningService.instance;
    List<OpeningEntry> list;
    if (_selectedCategory == 'All') {
      list = service.allOpenings;
    } else {
      list = service.getOpeningsByCategory(_selectedCategory);
    }

    if (_searchQuery.trim().isEmpty) return list;
    final q = _searchQuery.trim().toLowerCase();
    return list.where((o) {
      return o.name.toLowerCase().contains(q) ||
          o.eco.toLowerCase().contains(q) ||
          o.formattedMoves.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final openings = _getFilteredOpenings();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Opening Playbook',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Search openings (e.g. Sicilian, C50, e4)...',
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
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppTheme.borderColorFor(context),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppTheme.borderColorFor(context),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Category Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _buildCategoryChip('All'),
                      const SizedBox(width: 8),
                      ...OpeningService.categories.map((cat) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _buildCategoryChip(cat),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Count & Playbook List
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${openings.length} Openings Found',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondaryFor(context),
                  ),
                ),
                Text(
                  '100% Offline Master Theory',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          Expanded(
            child: openings.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.menu_book_rounded,
                          size: 56,
                          color: AppTheme.textHintFor(context),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No openings matched "$_searchQuery"',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondaryFor(context),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                    itemCount: openings.length,
                    itemBuilder: (context, index) {
                      final opening = openings[index];
                      return _buildOpeningCard(context, opening);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String category) {
    final isSelected = _selectedCategory == category;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = category),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor
              : AppTheme.cardColor(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryColor
                : AppTheme.borderColorFor(context),
          ),
        ),
        child: Text(
          category,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : AppTheme.textSecondaryFor(context),
          ),
        ),
      ),
    );
  }

  Widget _buildOpeningCard(BuildContext context, OpeningEntry opening) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        onTap: () => _showOpeningModal(context, opening),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: ECO + Category + Plies
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    opening.eco,
                    style: GoogleFonts.robotoMono(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    opening.category,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textHintFor(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${opening.plies} plies',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondaryFor(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Opening Name
            Text(
              opening.name,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimaryFor(context),
              ),
            ),
            const SizedBox(height: 6),

            // Formatted moves
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                opening.formattedMoves,
                style: GoogleFonts.robotoMono(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Description snippet
            Text(
              opening.description,
              style: GoogleFonts.inter(
                fontSize: 13,
                height: 1.35,
                color: AppTheme.textSecondaryFor(context),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),

            // Key themes tags
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: opening.keyThemes.map((theme) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppTheme.primaryColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    theme,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _showOpeningModal(BuildContext context, OpeningEntry opening) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _InteractiveOpeningModal(opening: opening),
    );
  }
}

/// Interactive Opening Exploration Modal with scrubbable board
class _InteractiveOpeningModal extends ConsumerStatefulWidget {
  final OpeningEntry opening;

  const _InteractiveOpeningModal({required this.opening});

  @override
  ConsumerState<_InteractiveOpeningModal> createState() =>
      _InteractiveOpeningModalState();
}

class _InteractiveOpeningModalState
    extends ConsumerState<_InteractiveOpeningModal> {
  late chess.Chess _board;
  int _currentPly = 0;
  final List<String> _fenHistory = [];

  @override
  void initState() {
    super.initState();
    _board = chess.Chess();
    _fenHistory.add(_board.fen);

    // Play moves up to current ply
    for (final san in widget.opening.movesSan) {
      _board.move(san);
      _fenHistory.add(_board.fen);
    }
    _currentPly = widget.opening.movesSan.length;
    _board.load(_fenHistory[_currentPly]);
  }

  void _goToPly(int ply) {
    if (ply < 0 || ply >= _fenHistory.length) return;
    setState(() {
      _currentPly = ply;
      _board.load(_fenHistory[ply]);
    });
  }

  void _practiceVsBot(BuildContext context) {
    final gameViewModel = ref.read(gameSessionProvider.notifier);

    // Setup bot match starting from this opening position
    gameViewModel.startNewGame(
      playerColor: PlayerColor.white,
      difficulty: AppConstants.difficultyLevels[3], // Intermediate (1600 ELO)
      timeControl: AppConstants.timeControls[7], // 10+0 Rapid
      gameMode: GameMode.bot,
      botType: BotType.stockfish,
      startingFen: widget.opening.practiceFen,
    );

    Navigator.pop(context); // Close modal
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const GameScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final opening = widget.opening;

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.textHintFor(context).withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Modal Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                              ),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              opening.eco,
                              style: GoogleFonts.robotoMono(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              opening.name,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimaryFor(context),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Board Container
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: 340,
                        maxHeight: 340,
                      ),
                      child: ThemedBoardContainer(
                        child: ChessBoard(
                          fen: _board.fen,
                          isFlipped: false,
                          showCoordinates: true,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Move Scrubber Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.first_page_rounded),
                        onPressed: _currentPly > 0 ? () => _goToPly(0) : null,
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_left_rounded),
                        onPressed: _currentPly > 0
                            ? () => _goToPly(_currentPly - 1)
                            : null,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          _currentPly == 0
                              ? 'Starting Position'
                              : 'Ply $_currentPly of ${opening.movesSan.length} (${opening.movesSan[_currentPly - 1]})',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimaryFor(context),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right_rounded),
                        onPressed: _currentPly < opening.movesSan.length
                            ? () => _goToPly(_currentPly + 1)
                            : null,
                      ),
                      IconButton(
                        icon: const Icon(Icons.last_page_rounded),
                        onPressed: _currentPly < opening.movesSan.length
                            ? () => _goToPly(opening.movesSan.length)
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Move sequence
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Move Sequence',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimaryFor(context),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          opening.formattedMoves,
                          style: GoogleFonts.robotoMono(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Strategic Plans & Description
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Strategic Overview',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimaryFor(context),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          opening.description,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            height: 1.45,
                            color: AppTheme.textSecondaryFor(context),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Key Tactical & Positional Themes:',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimaryFor(context),
                          ),
                        ),
                        const SizedBox(height: 6),
                        ...opening.keyThemes.map((theme) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('• ',
                                    style: TextStyle(color: AppTheme.primaryColor)),
                                Expanded(
                                  child: Text(
                                    theme,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: AppTheme.textSecondaryFor(context),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Action Button: Practice Against Bot
                  ElevatedButton.icon(
                    onPressed: () => _practiceVsBot(context),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(
                      'Practice this Opening vs AI',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
