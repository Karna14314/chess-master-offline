import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess/chess.dart' as chess;
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/core/theme/board_themes.dart';
import 'package:chess_master/providers/settings_provider.dart';

/// Position setup screen for creating custom FEN positions
class PositionSetupScreen extends ConsumerStatefulWidget {
  const PositionSetupScreen({super.key});

  @override
  ConsumerState<PositionSetupScreen> createState() =>
      _PositionSetupScreenState();
}

class _PositionSetupScreenState extends ConsumerState<PositionSetupScreen> {
  late List<List<String?>> _board;
  String? _selectedPiece;
  bool _whiteToMove = true;
  bool _whiteCastleKing = true;
  bool _whiteCastleQueen = true;
  bool _blackCastleKing = true;
  bool _blackCastleQueen = true;

  final _fenController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeEmptyBoard();
    _updateFen();
  }

  @override
  void dispose() {
    _fenController.dispose();
    super.dispose();
  }

  void _initializeEmptyBoard() {
    _board = List.generate(8, (_) => List.filled(8, null));
  }

  void _initializeStandardPosition() {
    _board = [
      ['r', 'n', 'b', 'q', 'k', 'b', 'n', 'r'],
      ['p', 'p', 'p', 'p', 'p', 'p', 'p', 'p'],
      [null, null, null, null, null, null, null, null],
      [null, null, null, null, null, null, null, null],
      [null, null, null, null, null, null, null, null],
      [null, null, null, null, null, null, null, null],
      ['P', 'P', 'P', 'P', 'P', 'P', 'P', 'P'],
      ['R', 'N', 'B', 'Q', 'K', 'B', 'N', 'R'],
    ];
    setState(() {
      _whiteToMove = true;
      _whiteCastleKing = true;
      _whiteCastleQueen = true;
      _blackCastleKing = true;
      _blackCastleQueen = true;
    });
    _updateFen();
  }

  void _clearBoard() {
    setState(() {
      _initializeEmptyBoard();
    });
    _updateFen();
  }

  void _updateFen() {
    final fen = _generateFen();
    _fenController.text = fen;
  }

  String _generateFen() {
    final buffer = StringBuffer();

    // Board position
    for (int rank = 0; rank < 8; rank++) {
      int emptyCount = 0;
      for (int file = 0; file < 8; file++) {
        final piece = _board[rank][file];
        if (piece == null) {
          emptyCount++;
        } else {
          if (emptyCount > 0) {
            buffer.write(emptyCount);
            emptyCount = 0;
          }
          buffer.write(piece);
        }
      }
      if (emptyCount > 0) {
        buffer.write(emptyCount);
      }
      if (rank < 7) buffer.write('/');
    }

    // Active color
    buffer.write(_whiteToMove ? ' w ' : ' b ');

    // Castling rights
    String castling = '';
    if (_whiteCastleKing) castling += 'K';
    if (_whiteCastleQueen) castling += 'Q';
    if (_blackCastleKing) castling += 'k';
    if (_blackCastleQueen) castling += 'q';
    buffer.write(castling.isEmpty ? '-' : castling);

    // En passant, halfmove, fullmove
    buffer.write(' - 0 1');

    return buffer.toString();
  }

  bool _loadFen(String fen) {
    try {
      final testGame = chess.Chess();
      if (!testGame.load(fen)) {
        return false;
      }

      // Parse the FEN
      final parts = fen.split(' ');
      if (parts.isEmpty) return false;

      final ranks = parts[0].split('/');
      if (ranks.length != 8) return false;

      final newBoard = List.generate(8, (_) => List<String?>.filled(8, null));

      for (int rank = 0; rank < 8; rank++) {
        int file = 0;
        for (final char in ranks[rank].split('')) {
          final num = int.tryParse(char);
          if (num != null) {
            file += num;
          } else {
            if (file < 8) {
              newBoard[rank][file] = char;
              file++;
            }
          }
        }
      }

      setState(() {
        _board = newBoard;
        if (parts.length > 1) {
          _whiteToMove = parts[1] == 'w';
        }
        if (parts.length > 2) {
          _whiteCastleKing = parts[2].contains('K');
          _whiteCastleQueen = parts[2].contains('Q');
          _blackCastleKing = parts[2].contains('k');
          _blackCastleQueen = parts[2].contains('q');
        }
      });

      return true;
    } catch (e) {
      return false;
    }
  }

  void _onSquareTap(int rank, int file) {
    setState(() {
      if (_selectedPiece == null) {
        // Clear square
        _board[rank][file] = null;
      } else if (_selectedPiece == 'CLEAR') {
        _board[rank][file] = null;
      } else {
        _board[rank][file] = _selectedPiece;
      }
    });
    _updateFen();
  }

  bool _validatePosition() {
    final fen = _generateFen();
    try {
      final game = chess.Chess();
      return game.load(fen);
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final boardTheme = settings.currentBoardTheme;
    final isValid = _validatePosition();

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('Position Setup'),
        backgroundColor: AppTheme.surfaceDark,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset to starting position',
            onPressed: _initializeStandardPosition,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear board',
            onPressed: _clearBoard,
          ),
        ],
      ),
      body: Column(
        children: [
          // Board
          AspectRatio(
            aspectRatio: 1,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: _buildBoard(boardTheme),
            ),
          ),

          // Piece palette
          _buildPiecePalette(),

          // Options
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTurnSelector(),
                  const SizedBox(height: 16),
                  _buildCastlingOptions(),
                  const SizedBox(height: 16),
                  _buildFenInput(),
                  const SizedBox(height: 24),
                  _buildActionButtons(isValid),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoard(BoardTheme theme) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.cardDark, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 8,
          ),
          itemCount: 64,
          itemBuilder: (context, index) {
            final rank = index ~/ 8;
            final file = index % 8;
            final isLight = (rank + file) % 2 == 0;
            final piece = _board[rank][file];

            return GestureDetector(
              onTap: () => _onSquareTap(rank, file),
              child: Container(
                color: isLight ? theme.lightSquare : theme.darkSquare,
                child: Center(
                  child: piece != null
                      ? Text(
                          _getPieceUnicode(piece),
                          style: const TextStyle(fontSize: 32),
                        )
                      : null,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPiecePalette() {
    const whitePieces = ['K', 'Q', 'R', 'B', 'N', 'P'];
    const blackPieces = ['k', 'q', 'r', 'b', 'n', 'p'];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: AppTheme.cardDark,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ...whitePieces.map((p) => _buildPieceButton(p)),
              _buildClearButton(),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: blackPieces.map((p) => _buildPieceButton(p)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPieceButton(String piece) {
    final isSelected = _selectedPiece == piece;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPiece = isSelected ? null : piece;
        });
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.transparent,
            width: 2,
          ),
        ),
        child: Center(
          child: Text(
            _getPieceUnicode(piece),
            style: const TextStyle(fontSize: 28),
          ),
        ),
      ),
    );
  }

  Widget _buildClearButton() {
    final isSelected = _selectedPiece == 'CLEAR';
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPiece = isSelected ? null : 'CLEAR';
        });
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isSelected ? Colors.red : AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(child: Icon(Icons.close, color: Colors.white)),
      ),
    );
  }

  Widget _buildTurnSelector() {
    return Row(
      children: [
        const Text('To move: '),
        const SizedBox(width: 16),
        ChoiceChip(
          label: const Text('White'),
          selected: _whiteToMove,
          onSelected: (selected) {
            if (selected) {
              setState(() => _whiteToMove = true);
              _updateFen();
            }
          },
        ),
        const SizedBox(width: 8),
        ChoiceChip(
          label: const Text('Black'),
          selected: !_whiteToMove,
          onSelected: (selected) {
            if (selected) {
              setState(() => _whiteToMove = false);
              _updateFen();
            }
          },
        ),
      ],
    );
  }

  Widget _buildCastlingOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Castling rights:'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilterChip(
              label: const Text('White O-O'),
              selected: _whiteCastleKing,
              onSelected: (selected) {
                setState(() => _whiteCastleKing = selected);
                _updateFen();
              },
            ),
            FilterChip(
              label: const Text('White O-O-O'),
              selected: _whiteCastleQueen,
              onSelected: (selected) {
                setState(() => _whiteCastleQueen = selected);
                _updateFen();
              },
            ),
            FilterChip(
              label: const Text('Black O-O'),
              selected: _blackCastleKing,
              onSelected: (selected) {
                setState(() => _blackCastleKing = selected);
                _updateFen();
              },
            ),
            FilterChip(
              label: const Text('Black O-O-O'),
              selected: _blackCastleQueen,
              onSelected: (selected) {
                setState(() => _blackCastleQueen = selected);
                _updateFen();
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFenInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('FEN:'),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.copy, size: 20),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _fenController.text));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('FEN copied to clipboard')),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.paste, size: 20),
              onPressed: () async {
                final data = await Clipboard.getData(Clipboard.kTextPlain);
                if (data?.text != null) {
                  if (_loadFen(data!.text!)) {
                    _fenController.text = data.text!;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('FEN loaded successfully')),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Invalid FEN')),
                    );
                  }
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _fenController,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: AppTheme.cardDark,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onSubmitted: (fen) {
            if (_loadFen(fen)) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('FEN loaded')));
            } else {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Invalid FEN')));
            }
          },
        ),
      ],
    );
  }

  Widget _buildActionButtons(bool isValid) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: isValid
                ? () => Navigator.pop(context, {
                    'action': 'analyze',
                    'fen': _generateFen(),
                  })
                : null,
            child: const Text('Analyze'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: isValid
                ? () => Navigator.pop(context, {
                    'action': 'play',
                    'fen': _generateFen(),
                  })
                : null,
            child: const Text('Play'),
          ),
        ),
      ],
    );
  }

  String _getPieceUnicode(String piece) {
    const unicodeMap = {
      'K': '♔',
      'Q': '♕',
      'R': '♖',
      'B': '♗',
      'N': '♘',
      'P': '♙',
      'k': '♚',
      'q': '♛',
      'r': '♜',
      'b': '♝',
      'n': '♞',
      'p': '♟',
    };
    return unicodeMap[piece] ?? '';
  }
}
