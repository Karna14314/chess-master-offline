import 'package:flutter/material.dart';
import 'package:chess/chess.dart' as chess;
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/screens/home/home_screen.dart';
import 'package:chess_master/screens/game/widgets/chess_board.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tutorial intro screen shown after onboarding completes.
/// Presents a quick 1-move checkmate puzzle to give new players an instant win.
class TutorialIntroScreen extends StatefulWidget {
  const TutorialIntroScreen({super.key});

  @override
  State<TutorialIntroScreen> createState() => _TutorialIntroScreenState();
}

class _TutorialIntroScreenState extends State<TutorialIntroScreen> {
  int _step = 0; // 0 = intro, 1 = how-to-play, 2 = checkmate puzzle
  bool _showHowToPlay = true;
  String? _selectedSquare;
  List<String> _legalMoves = [];
  late chess.Chess _board;
  bool _isSolved = false;

  @override
  void initState() {
    super.initState();
    // Set up a mate-in-1 position: White pawn on d7, White king on f6,
    // Black king on e8. White plays d8=Q# (promotion with checkmate).
    _board = chess.Chess.fromFEN('4k3/3P4/5K2/8/8/8/8/8 w - - 0 1');
  }

  void _onSquareTap(String square) {
    if (_step != 2 || _isSolved) return;

    final piece = _board.get(square);
    if (piece == null) {
      // Clicked empty square
      if (_selectedSquare != null && _legalMoves.contains(square)) {
        // Make the move
        final from = _selectedSquare!;
        final to = square;
        final moved = _board.move({'from': from, 'to': to, 'promotion': 'q'});

        if (moved && _board.in_checkmate) {
          setState(() {
            _isSolved = true;
          });
        }

        _resetSelection();
      } else if (_selectedSquare != null && _selectedSquare != square) {
        // Clicked a different piece of the same color
        final newPiece = _board.get(square);
        if (newPiece != null) {
          _selectSquare(square);
        }
      }
      return;
    }

    // Clicked a piece
    _selectSquare(square);
  }

  void _selectSquare(String square) {
    final piece = _board.get(square);
    if (piece == null) return;

    final isWhitePiece = piece.color == chess.Color.WHITE;
    if (!isWhitePiece) return; // Only allow selecting white pieces

    // Get legal moves from this square
    final moves = _board.moves({'square': square, 'verbose': true});
    final legalSquares = moves.map((m) => (m as Map)['to'] as String).toList();

    setState(() {
      _selectedSquare = square;
      _legalMoves = legalSquares;
    });
  }

  void _resetSelection() {
    setState(() {
      _selectedSquare = null;
      _legalMoves = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(child: _buildContent()),
    );
  }

  Widget _buildContent() {
    switch (_step) {
      case 0:
        return _buildIntro();
      case 1:
        return _buildHowToPlay();
      case 2:
        return _buildPuzzle();
      default:
        return _buildIntro();
    }
  }

  Widget _buildIntro() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.celebration_outlined,
              size: 64,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Welcome to ChessMaster!',
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryFor(context),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Let\'s play a quick game to get you started. You\'ll play as White and try to find checkmate in 1 move.',
            style: GoogleFonts.inter(
              fontSize: 15,
              height: 1.5,
              color: AppTheme.textSecondaryFor(context),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                setState(() => _step = 1);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'Let\'s Go!',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const HomeScreen()),
              );
            },
            child: Text(
              'Skip (go to home)',
              style: GoogleFonts.inter(
                color: AppTheme.textSecondaryFor(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHowToPlay() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.touch_app_outlined,
            size: 64,
            color: AppTheme.primaryColor,
          ),
          const SizedBox(height: 24),
          Text(
            'How to Move Pieces',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryFor(context),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          _buildStep(
            step: '1',
            title: 'Tap a piece',
            description:
                'Tap the pawn on d7 (the piece with a crown-like symbol when promoted).',
          ),
          const SizedBox(height: 16),
          _buildStep(
            step: '2',
            title: 'Tap destination',
            description: 'Tap the square with a green dot to move there.',
          ),
          const SizedBox(height: 16),
          _buildStep(
            step: '3',
            title: 'Get checkmate!',
            description:
                'Your move will be checkmate — the enemy king can\'t escape!',
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                setState(() => _step = 2);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'Try It!',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep({
    required String step,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              step,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimaryFor(context),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.4,
                  color: AppTheme.textSecondaryFor(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPuzzle() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text(
                'Checkmate in 1 Move',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryFor(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isSolved
                    ? 'Correct! You found checkmate.'
                    : 'White to move. Find the winning move.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppTheme.textSecondaryFor(context),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              if (!_isSolved)
                Text(
                  'Hint: Promote the pawn for checkmate!',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.orange.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 1.0,
              child: ChessBoard(
                fen: _board.fen,
                onSquareTap: _onSquareTap,
                selectedSquare: _selectedSquare,
                legalMoves: _legalMoves,
                showCoordinates: true,
              ),
            ),
          ),
        ),
        if (_isSolved)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.amber.shade100,
                  ),
                  child: const Icon(
                    Icons.emoji_events,
                    size: 56,
                    color: Colors.amber,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Excellent!',
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryFor(context),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'You just delivered checkmate! Now you\'re ready to play for real.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    height: 1.5,
                    color: AppTheme.textSecondaryFor(context),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HomeScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      'Go to Home',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
