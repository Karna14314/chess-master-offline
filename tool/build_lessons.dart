/// Builds structured v2 lessons + openings from the local Lichess puzzle DB.
///
/// Run: dart tool/build_lessons.dart
/// Reads: assets/puzzles/puzzles.json
/// Writes: assets/lessons/lessons_data.json, assets/lessons/curriculum.json,
///         assets/lessons/openings.json (backs up existing files first).
///
/// Every puzzle solution is replayed with package:chess — invalid lines are
/// dropped with a report. Nothing unverified ships.
library;

import 'dart:convert';
import 'dart:io';
import 'package:chess/chess.dart' as chess;

/// One teachable motif. A pack turns N puzzles into N lessons that share
/// concept/takeaway/quiz but have per-position narration + hints.
class MotifPack {
  final String id;
  final String categoryId;
  final String categoryTitle;
  final String categorySubtitle;
  final String sectionId;
  final String difficulty;
  final String icon;
  final int count;
  final String puzzleTheme;
  final int minRating;
  final int maxRating;
  final String concept;
  final String takeaway;
  final String instruction;
  final String ideaNoun;
  final String mistakeText;
  final String hintTemplate;
  final String quizQuestion;
  final List<String> quizOptions;
  final int quizAnswer;
  final bool mustMate;

  const MotifPack({
    required this.id,
    required this.categoryId,
    required this.categoryTitle,
    required this.categorySubtitle,
    required this.sectionId,
    required this.difficulty,
    required this.icon,
    required this.count,
    required this.puzzleTheme,
    required this.minRating,
    required this.maxRating,
    required this.concept,
    required this.takeaway,
    required this.instruction,
    required this.ideaNoun,
    required this.mistakeText,
    required this.hintTemplate,
    required this.quizQuestion,
    required this.quizOptions,
    required this.quizAnswer,
    this.mustMate = false,
  });
}

const List<MotifPack> kMatePacks = [
  MotifPack(
    id: 'backrank',
    categoryId: 'mate_back_rank',
    categoryTitle: 'Back-Rank Mate',
    categorySubtitle: 'Trap the king on its own back rank',
    sectionId: 'checkmates',
    difficulty: 'Beginner',
    icon: 'grid',
    count: 12,
    puzzleTheme: 'backRankMate',
    minRating: 600,
    maxRating: 1600,
    concept:
        'When a king is hemmed in on the back rank by its own pawns, a rook or queen check along that rank is checkmate — the king has no escape square.',
    takeaway: 'Before attacking, check: can the enemy king leave the back rank?',
    instruction: 'Deliver checkmate on the back rank.',
    ideaNoun: 'the back-rank mate',
    mistakeText:
        'That does not mate — look for the check the king cannot escape. Its own pawns block every flight square.',
    hintTemplate: 'The enemy king is trapped by its own pawns. Check along the back rank.',
    quizQuestion: 'Why is a back-rank check usually decisive?',
    quizOptions: [
      'The king has no escape squares — its own pawns block it',
      'Rooks are worth more than pawns',
      'Checks are always checkmate',
    ],
    quizAnswer: 0,
    mustMate: true,
  ),
  MotifPack(
    id: 'mate1',
    categoryId: 'mate_in_one',
    categoryTitle: 'Mate in 1',
    categorySubtitle: 'Spot the finishing blow',
    sectionId: 'checkmates',
    difficulty: 'Beginner',
    icon: 'bolt',
    count: 12,
    puzzleTheme: 'mateIn1',
    minRating: 600,
    maxRating: 1200,
    concept:
        'Mate in one means a single move ends the game. Scan every check first, then ask: after this check, does the king have any legal move or block?',
    takeaway: 'Checks first, captures second, quiet moves last.',
    instruction: 'Find the move that checkmates immediately.',
    ideaNoun: 'the mate in one',
    mistakeText:
        'That is not mate — the king escapes or the check is blocked. List every check and test each one.',
    hintTemplate: 'There is exactly one mating move. Start by listing all checks.',
    quizQuestion: 'What should you examine first when hunting mate in 1?',
    quizOptions: [
      'Quiet pawn moves',
      'Every checking move, testing each escape',
      'Trading queens',
    ],
    quizAnswer: 1,
    mustMate: true,
  ),
  MotifPack(
    id: 'mate2',
    categoryId: 'mate_in_two',
    categoryTitle: 'Mate in 2',
    categorySubtitle: 'Force the mate, whatever they play',
    sectionId: 'checkmates',
    difficulty: 'Beginner',
    icon: 'bolt',
    count: 12,
    puzzleTheme: 'mateIn2',
    minRating: 600,
    maxRating: 1400,
    concept:
        'A forced mate in two works against every defence. Your first move limits the king, and the second finishes — no matter which legal reply comes.',
    takeaway: 'First move takes away flight squares; second move delivers.',
    instruction: 'Force checkmate in two moves.',
    ideaNoun: 'the forced mate',
    mistakeText:
        'That allows an escape. Your first move must work against every legal reply, not just one.',
    hintTemplate: 'Take away the king’s flight squares first — the mate follows itself.',
    quizQuestion: 'What makes a combination "forced"?',
    quizOptions: [
      'It looks impressive',
      'It succeeds against every legal defence',
      'It uses the queen',
    ],
    quizAnswer: 1,
    mustMate: true,
  ),
  MotifPack(
    id: 'smothered',
    categoryId: 'mate_smothered',
    categoryTitle: 'Smothered Mate',
    categorySubtitle: 'The knight’s signature mate',
    sectionId: 'checkmates',
    difficulty: 'Intermediate',
    icon: 'star',
    count: 6,
    puzzleTheme: 'smotheredMate',
    minRating: 600,
    maxRating: 1800,
    concept:
        'When a king is completely surrounded by its own pieces, a knight check is checkmate — the king is smothered and no piece can capture the knight.',
    takeaway: 'A surrounded king fears knight checks most of all.',
    instruction: 'Deliver the smothered mate with the knight.',
    ideaNoun: 'the smothered mate',
    mistakeText:
        'Not mate — check whether the king is truly smothered: every adjacent square must be covered or occupied.',
    hintTemplate: 'The king is buried in its own pieces. A knight check ends it.',
    quizQuestion: 'Which piece delivers smothered mate?',
    quizOptions: ['A bishop', 'A knight', 'A pawn'],
    quizAnswer: 1,
    mustMate: true,
  ),
  MotifPack(
    id: 'arabian',
    categoryId: 'mate_arabian',
    categoryTitle: 'Arabian Mate',
    categorySubtitle: 'Rook and knight, cornered king',
    sectionId: 'checkmates',
    difficulty: 'Intermediate',
    icon: 'star',
    count: 4,
    puzzleTheme: 'arabianMate',
    minRating: 600,
    maxRating: 1800,
    concept:
        'The Arabian mate traps the king in the corner: the rook cuts off escape along the rank while the knight covers the flight square.',
    takeaway: 'Rook seals the edge, knight covers the hole.',
    instruction: 'Mate with the rook-and-knight pattern.',
    ideaNoun: 'the Arabian mate',
    mistakeText:
        'That lets the king slip out. The rook must seal the edge and the knight must cover the escape square.',
    hintTemplate: 'Drive the king to the corner: rook on the edge, knight covering flight.',
    quizQuestion: 'In the Arabian mate, what is the knight’s job?',
    quizOptions: [
      'Giving the check',
      'Covering the king’s escape square',
      'Defending the rook',
    ],
    quizAnswer: 1,
    mustMate: true,
  ),
  MotifPack(
    id: 'anastasia',
    categoryId: 'mate_anastasia',
    categoryTitle: "Anastasia's Mate",
    categorySubtitle: 'Knight and rook hunting the edge',
    sectionId: 'checkmates',
    difficulty: 'Intermediate',
    icon: 'star',
    count: 4,
    puzzleTheme: 'anastasiaMate',
    minRating: 600,
    maxRating: 1800,
    concept:
        "Anastasia's mate pins the king to the edge of the board: a knight covers the escapes while the rook delivers mate, often after a queen sacrifice lures the king out.",
    takeaway: 'Lure, cover, deliver: sacrifice to draw the king out.',
    instruction: "Deliver Anastasia's mate.",
    ideaNoun: "Anastasia's mate",
    mistakeText:
        'That misses the pattern — the knight must cover the escape squares while the rook gives mate on the edge.',
    hintTemplate: 'The knight covers escapes; the rook mates on the edge file.',
    quizQuestion: "What usually starts Anastasia's mate?",
    quizOptions: [
      'A quiet pawn push',
      'A sacrifice that lures the king toward the edge',
      'Castling',
    ],
    quizAnswer: 1,
    mustMate: true,
  ),
  MotifPack(
    id: 'morphy',
    categoryId: 'mate_morphy',
    categoryTitle: "Morphy's Mate",
    categorySubtitle: 'Bishop and rook corner trap',
    sectionId: 'checkmates',
    difficulty: 'Intermediate',
    icon: 'star',
    count: 4,
    puzzleTheme: 'morphysMate',
    minRating: 600,
    maxRating: 1800,
    concept:
        "Morphy's mate corners the king with a bishop sealing the diagonal while the rook delivers mate — the bishop does the quiet work of a whole wall.",
    takeaway: 'Bishop builds the cage, rook closes the door.',
    instruction: "Deliver Morphy's mate.",
    ideaNoun: "Morphy's mate",
    mistakeText:
        'That breaks the cage. Keep the bishop sealing the diagonal and mate with the rook.',
    hintTemplate: 'The bishop walls the king in; the rook gives mate.',
    quizQuestion: "In Morphy's mate, what does the bishop do?",
    quizOptions: [
      'Gives check',
      'Seals the king’s escape diagonal like a wall',
      'Protects the rook',
    ],
    quizAnswer: 1,
    mustMate: true,
  ),
  MotifPack(
    id: 'opera',
    categoryId: 'mate_opera',
    categoryTitle: 'Opera Mate',
    categorySubtitle: 'The classic opera-house finish',
    sectionId: 'checkmates',
    difficulty: 'Intermediate',
    icon: 'star',
    count: 6,
    puzzleTheme: 'operaMate',
    minRating: 600,
    maxRating: 1800,
    concept:
        'The Opera mate — named for Morphy’s famous 1858 game — mates a king trapped on the back rank when its escape is blocked, delivered by rook with bishop support.',
    takeaway: 'Develop with threats: every piece joins the attack.',
    instruction: 'Deliver the Opera mate.',
    ideaNoun: 'the Opera mate',
    mistakeText:
        'That lets the king breathe. Keep the pressure: block the escape, then mate on the back rank.',
    hintTemplate: 'The king is stuck on the edge — rook mates with bishop support.',
    quizQuestion: 'The Opera mate is famous from a game played in…',
    quizOptions: ['A 1997 computer match', 'An 1858 opera house', 'A 1972 championship'],
    quizAnswer: 1,
    mustMate: true,
  ),
];

const List<MotifPack> kFundamentalPacks = [
  MotifPack(
    id: 'fork',
    categoryId: 'tactic_fork',
    categoryTitle: 'The Fork',
    categorySubtitle: 'One piece attacks two',
    sectionId: 'fundamental_tactics',
    difficulty: 'Beginner',
    icon: 'call_split',
    count: 30,
    puzzleTheme: 'fork',
    minRating: 600,
    maxRating: 1300,
    concept:
        'A fork attacks two (or more) pieces at once. The most famous is the knight fork — but queens, pawns and bishops fork too. The victim can only save one piece.',
    takeaway: 'Attack two things at once; you win one of them.',
    instruction: 'Fork two enemy pieces and win material.',
    ideaNoun: 'the fork',
    mistakeText:
        'That attacks only one piece — find the square your piece can move to that hits two targets at once.',
    hintTemplate: 'Look for a square that attacks two loose enemy pieces at the same time.',
    quizQuestion: 'Why is a fork so powerful?',
    quizOptions: [
      'It gives check',
      'One move creates two threats and only one can be answered',
      'It always wins the queen',
    ],
    quizAnswer: 1,
  ),
  MotifPack(
    id: 'pin',
    categoryId: 'tactic_pin',
    categoryTitle: 'The Pin',
    categorySubtitle: 'Freeze a piece in place',
    sectionId: 'fundamental_tactics',
    difficulty: 'Beginner',
    icon: 'push_pin',
    count: 25,
    puzzleTheme: 'pin',
    minRating: 600,
    maxRating: 1300,
    concept:
        'A piece is pinned when moving it would expose something more valuable — the king (absolute pin) or a queen or rook (relative pin). Pinned pieces are prisoners: attack them, or attack what they can no longer defend.',
    takeaway: 'Pin first, win the piece second.',
    instruction: 'Exploit the pin to win material.',
    ideaNoun: 'the pin',
    mistakeText:
        'That ignores the pin. Ask: which enemy piece cannot move, and what did it stop defending?',
    hintTemplate: 'Find the piece that cannot move — then take what it used to defend.',
    quizQuestion: 'What is an absolute pin?',
    quizOptions: [
      'A pin on the queen',
      'A pin where moving would expose the king — the piece cannot legally move',
      'Two pins at once',
    ],
    quizAnswer: 1,
  ),
  MotifPack(
    id: 'hanging',
    categoryId: 'tactic_hanging_piece',
    categoryTitle: 'Hanging Pieces',
    categorySubtitle: 'Take what is undefended',
    sectionId: 'fundamental_tactics',
    difficulty: 'Beginner',
    icon: 'shopping_bag',
    count: 20,
    puzzleTheme: 'hangingPiece',
    minRating: 600,
    maxRating: 1200,
    concept:
        'A hanging piece is undefended — capturing it wins material for free. Strong players scan for hanging pieces on every single move, for both sides.',
    takeaway: 'Every move: what hangs, mine and theirs?',
    instruction: 'Capture the undefended piece.',
    ideaNoun: 'the hanging piece',
    mistakeText:
        'That misses free material. Scan the board: which enemy piece has no defender?',
    hintTemplate: 'One enemy piece has no defender. Find it and take it.',
    quizQuestion: 'What is a hanging piece?',
    quizOptions: [
      'A piece giving check',
      'An undefended piece that can be captured for free',
      'A pinned piece',
    ],
    quizAnswer: 1,
  ),
  MotifPack(
    id: 'skewer',
    categoryId: 'tactic_skewer',
    categorySubtitle: 'Attack through the valuable piece',
    categoryTitle: 'The Skewer',
    sectionId: 'fundamental_tactics',
    difficulty: 'Beginner',
    icon: 'arrow_range',
    count: 15,
    puzzleTheme: 'skewer',
    minRating: 600,
    maxRating: 1300,
    concept:
        'A skewer is the reverse of a pin: you attack the valuable piece first, and when it moves, you capture the piece hiding behind it. Line pieces — rooks, bishops, queens — skewer.',
    takeaway: 'Hit the big piece; collect the piece behind it.',
    instruction: 'Skewer and win the piece behind.',
    ideaNoun: 'the skewer',
    mistakeText:
        'That is not the skewer — attack the more valuable piece first so it must move and expose the piece behind.',
    hintTemplate: 'Two enemy pieces stand on one line. Hit the valuable one first.',
    quizQuestion: 'How is a skewer different from a pin?',
    quizOptions: [
      'There is no difference',
      'You attack the valuable piece first and win what hides behind it',
      'Only knights skewer',
    ],
    quizAnswer: 1,
  ),
  MotifPack(
    id: 'discovered',
    categoryId: 'tactic_discovered_attack',
    categoryTitle: 'Discovered Attacks',
    categorySubtitle: 'Move one piece, unleash another',
    sectionId: 'fundamental_tactics',
    difficulty: 'Beginner',
    icon: 'visibility',
    count: 20,
    puzzleTheme: 'discoveredAttack',
    minRating: 600,
    maxRating: 1400,
    concept:
        'Move a piece out of the way and the piece behind it suddenly attacks. The moving piece can itself give check or grab something — two threats from one move.',
    takeaway: 'One move, two threats: the mover and the unveiled.',
    instruction: 'Unleash the discovered attack.',
    ideaNoun: 'the discovered attack',
    mistakeText:
        'That unleashes nothing. Find the piece whose path is blocked — move the blocker with a threat.',
    hintTemplate: 'One of your pieces is masked. Move the blocker with tempo.',
    quizQuestion: 'Why are discovered attacks so dangerous?',
    quizOptions: [
      'They always give check',
      'They create two threats at once — the moving piece and the unveiled piece',
      'They win the queen automatically',
    ],
    quizAnswer: 1,
  ),
  MotifPack(
    id: 'doublecheck',
    categoryId: 'tactic_double_check',
    categoryTitle: 'Double Check',
    categorySubtitle: 'Two checks the king must flee',
    sectionId: 'fundamental_tactics',
    difficulty: 'Intermediate',
    icon: 'exposure_plus_2',
    count: 10,
    puzzleTheme: 'doubleCheck',
    minRating: 600,
    maxRating: 1500,
    concept:
        'A double check attacks the king with two pieces at once. It cannot be blocked and the blocking piece cannot capture — the king must move. The forced king move often walks into mate or drops material.',
    takeaway: 'Double check forces the king to move — decide where it is allowed to go.',
    instruction: 'Give double check and exploit the forced king move.',
    ideaNoun: 'the double check',
    mistakeText:
        'That is only a single check — it can be blocked or captured. Find the move that checks with two pieces.',
    hintTemplate: 'A discovered check where the moving piece also checks — the king must run.',
    quizQuestion: 'Why must the king move against a double check?',
    quizOptions: [
      'It is good etiquette',
      'It cannot be blocked and one piece cannot capture both attackers',
      'Double checks are always mate',
    ],
    quizAnswer: 1,
  ),
  MotifPack(
    id: 'deflection',
    categoryId: 'tactic_deflection',
    categoryTitle: 'Deflection',
    categorySubtitle: 'Lure the defender away',
    sectionId: 'fundamental_tactics',
    difficulty: 'Intermediate',
    icon: 'call_missed_outgoing',
    count: 12,
    puzzleTheme: 'deflection',
    minRating: 600,
    maxRating: 1500,
    concept:
        'A defender doing an important job can be lured away — sacrifice something to drag it off its post, then strike what it used to guard.',
    takeaway: 'Every defender has a price. Offer it.',
    instruction: 'Deflect the defender, then collect.',
    ideaNoun: 'the deflection',
    mistakeText:
        'That lets the defender stay. Force it away first — only then take the real target.',
    hintTemplate: 'One defender holds everything. Sacrifice to drag it off its square.',
    quizQuestion: 'What is deflection?',
    quizOptions: [
      'Blocking an attack',
      'Forcing a defending piece away from its post so its charge falls',
      'Pinning a piece',
    ],
    quizAnswer: 1,
  ),
  MotifPack(
    id: 'attraction',
    categoryId: 'tactic_attraction',
    categoryTitle: 'Attraction',
    categorySubtitle: 'Draw the king into the net',
    sectionId: 'fundamental_tactics',
    difficulty: 'Intermediate',
    icon: 'magnet',
    count: 8,
    puzzleTheme: 'attraction',
    minRating: 600,
    maxRating: 1600,
    concept:
        'Attraction sacrifices force the enemy king onto a fatal square — a square you choose, where mate or a decisive tactic waits.',
    takeaway: 'Do not chase the king. Invite it where you want it.',
    instruction: 'Lure the king to its doom.',
    ideaNoun: 'the attraction sacrifice',
    mistakeText:
        'That chases instead of luring. Sacrifice onto the square where your tactic is already prepared.',
    hintTemplate: 'The king must be drawn to a specific square — sacrifice there.',
    quizQuestion: 'The point of an attraction sacrifice is to…',
    quizOptions: [
      'Win a pawn',
      'Force the king onto a square where mate or a tactic waits',
      'Trade queens',
    ],
    quizAnswer: 1,
  ),
];

const List<MotifPack> kIntermediatePacks = [
  MotifPack(
    id: 'clearance',
    categoryId: 'tactic_clearance',
    categoryTitle: 'Clearance',
    categorySubtitle: 'Vacate the square for the real threat',
    sectionId: 'advanced_tactics',
    difficulty: 'Advanced',
    icon: 'cleaning_services',
    count: 15,
    puzzleTheme: 'clearance',
    minRating: 600,
    maxRating: 1800,
    concept:
        'Sometimes the winning square is occupied — by your own piece. Move it away with tempo (check, threat, or tempo gain) and the square becomes lethal.',
    takeaway: 'Your own piece can be the obstacle. Move it with a threat.',
    instruction: 'Clear the key square with tempo.',
    ideaNoun: 'the clearance',
    mistakeText:
        'That leaves your own piece blocking the winning idea. Vacate the square first — with check or a threat.',
    hintTemplate: 'Your own piece stands on the winning square. Move it with tempo.',
    quizQuestion: 'What is a clearance sacrifice?',
    quizOptions: [
      'Giving up the exchange',
      'Moving your own piece off a key square with gain of time so the square can be used',
      'Sacrificing the queen for mate',
    ],
    quizAnswer: 1,
  ),
  MotifPack(
    id: 'interference',
    categoryId: 'tactic_interference',
    categoryTitle: 'Interference',
    categorySubtitle: 'Block the defender’s path',
    sectionId: 'advanced_tactics',
    difficulty: 'Advanced',
    icon: 'block',
    count: 10,
    puzzleTheme: 'interference',
    minRating: 600,
    maxRating: 1800,
    concept:
        'Defenders work along lines. Throw a piece onto that line — even as a sacrifice — and the defence is cut. The defender watches helplessly from the wrong side of your piece.',
    takeaway: 'Cut the line, kill the defence.',
    instruction: 'Interfere with the defender’s line.',
    ideaNoun: 'the interference',
    mistakeText:
        'That leaves the defensive line intact. Interpose on the line between defender and its charge.',
    hintTemplate: 'The defender guards along a line. Drop a piece onto that line.',
    quizQuestion: 'Interference works by…',
    quizOptions: [
      'Checking the king twice',
      'Placing a piece between a defender and what it defends',
      'Trading into a drawn endgame',
    ],
    quizAnswer: 1,
  ),
  MotifPack(
    id: 'xray',
    categoryId: 'tactic_xray',
    categoryTitle: 'X-Ray Attack',
    categorySubtitle: 'Attack through the piece',
    sectionId: 'advanced_tactics',
    difficulty: 'Advanced',
    icon: 'x_ray',
    count: 6,
    puzzleTheme: 'xRayAttack',
    minRating: 600,
    maxRating: 1800,
    concept:
        'An x-ray attack hits through an enemy piece to the target behind — typically rook versus king on the same file, where the piece in between cannot survive the pressure.',
    takeaway: 'Line up on the real target, whatever stands between.',
    instruction: 'Strike through with the x-ray.',
    ideaNoun: 'the x-ray',
    mistakeText:
        'That ignores the piece behind. Line up through the blocker onto the true target.',
    hintTemplate: 'Your rook sees through to the king — the piece between is doomed.',
    quizQuestion: 'An x-ray attack means…',
    quizOptions: [
      'Seeing the board blindfold',
      'Attacking a target through a piece standing between',
      'Checking with two pieces',
    ],
    quizAnswer: 1,
  ),
  MotifPack(
    id: 'zugzwang',
    categoryId: 'tactic_zugzwang',
    categoryTitle: 'Zugzwang',
    categorySubtitle: 'Every move loses',
    sectionId: 'advanced_tactics',
    difficulty: 'Advanced',
    icon: 'sentiment_very_dissatisfied',
    count: 15,
    puzzleTheme: 'zugzwang',
    minRating: 600,
    maxRating: 1800,
    concept:
        'Zugzwang: any move the opponent makes worsens their position. Common in pawn endgames — triangulate, lose a tempo, and force them to abandon a key square.',
    takeaway: 'When everything wins, pass the move to them.',
    instruction: 'Put the opponent in zugzwang.',
    ideaNoun: 'the zugzwang',
    mistakeText:
        'That releases the tension too early. Improve your position first, then force them to move.',
    hintTemplate: 'Do not rush — make a waiting move that keeps every threat alive.',
    quizQuestion: 'What is zugzwang?',
    quizOptions: [
      'A forced checkmate',
      'A position where any move the opponent makes loses',
      'A draw by repetition',
    ],
    quizAnswer: 1,
  ),
  MotifPack(
    id: 'intermezzo',
    categoryId: 'tactic_intermezzo',
    categoryTitle: 'Intermezzo',
    categorySubtitle: 'The in-between move',
    sectionId: 'advanced_tactics',
    difficulty: 'Advanced',
    icon: 'skip_next',
    count: 12,
    puzzleTheme: 'intermezzo',
    minRating: 600,
    maxRating: 1800,
    concept:
        'Instead of the "obvious" recapture, slip in an intermediate threat first — a check or an attack — and recapture afterwards under better circumstances.',
    takeaway: 'Obvious recaptures can wait. Threaten first.',
    instruction: 'Find the intermezzo.',
    ideaNoun: 'the in-between move',
    mistakeText:
        'That is the automatic recapture — look for the forcing move you can insert first.',
    hintTemplate: 'Before recapturing, is there a check or threat to insert?',
    quizQuestion: 'An intermezzo is…',
    quizOptions: [
      'Ahaltime break',
      'An unexpected forcing move played before the "obvious" reply',
      'A type of pin',
    ],
    quizAnswer: 1,
  ),
  MotifPack(
    id: 'capdef',
    categoryId: 'tactic_capturing_defender',
    categoryTitle: 'Removing the Defender',
    categorySubtitle: 'Take the guard, then the treasure',
    sectionId: 'advanced_tactics',
    difficulty: 'Intermediate',
    icon: 'security',
    count: 10,
    puzzleTheme: 'capturingDefender',
    minRating: 600,
    maxRating: 1600,
    concept:
        'If one piece guards everything, capture it — even at apparent cost. Once the guard is gone, the treasure behind it falls.',
    takeaway: 'One guard, one capture, then collect.',
    instruction: 'Remove the defender.',
    ideaNoun: 'removing the defender',
    mistakeText:
        'That leaves the guard in place. Capture the defender first, whatever it costs.',
    hintTemplate: 'A single piece guards the target. Eliminate that guard.',
    quizQuestion: 'When is capturing the defender correct?',
    quizOptions: [
      'Never — defenders are too strong',
      'When the piece it guards is worth more than the cost of the capture',
      'Only with check',
    ],
    quizAnswer: 1,
  ),
  MotifPack(
    id: 'trapped',
    categoryId: 'tactic_trapped_piece',
    categoryTitle: 'Trapped Pieces',
    categorySubtitle: 'No way home',
    sectionId: 'advanced_tactics',
    difficulty: 'Intermediate',
    icon: 'trap',
    count: 12,
    puzzleTheme: 'trappedPiece',
    minRating: 600,
    maxRating: 1600,
    concept:
        'A piece deep in enemy territory with no retreat squares is already lost — close the last door (often with a pawn push) and collect it.',
    takeaway: 'Shut the door before collecting.',
    instruction: 'Trap and win the stranded piece.',
    ideaNoun: 'the trap',
    mistakeText:
        'That lets it escape. First take away its last retreat square, then capture.',
    hintTemplate: 'The enemy piece has almost no squares — close the last one.',
    quizQuestion: 'How do you finish a trapped piece?',
    quizOptions: [
      'Capture it immediately, always',
      'First remove its escape squares, then collect it',
      'Offer a draw',
    ],
    quizAnswer: 1,
  ),
  MotifPack(
    id: 'sacrifice',
    categoryId: 'tactic_sacrifice',
    categoryTitle: 'The Sacrifice',
    categorySubtitle: 'Material for initiative',
    sectionId: 'advanced_tactics',
    difficulty: 'Advanced',
    icon: 'whatshot',
    count: 12,
    puzzleTheme: 'sacrifice',
    minRating: 1300,
    maxRating: 1800,
    concept:
        'Give up material for something greater: an exposed king, a crushing initiative, or a forced mate. A sound sacrifice is calculated to the end; a positional one trusts lasting pressure.',
    takeaway: 'Count the compensation, not the material.',
    instruction: 'Sacrifice for the attack.',
    ideaNoun: 'the sacrifice',
    mistakeText:
        'That gives material for nothing. A sacrifice needs concrete compensation — mate, king hunt, or lasting pressure.',
    hintTemplate: 'Material matters less than the king. Break through, whatever it costs.',
    quizQuestion: 'What makes a sacrifice sound?',
    quizOptions: [
      'It looks brave',
      'Concrete compensation: mate, an exposed king, or lasting pressure',
      'The opponent is lower rated',
    ],
    quizAnswer: 1,
  ),
  MotifPack(
    id: 'quiet',
    categoryId: 'tactic_quiet_move',
    categoryTitle: 'Quiet Moves',
    categorySubtitle: 'The strongest move checks nothing',
    sectionId: 'advanced_tactics',
    difficulty: 'Advanced',
    icon: 'volume_mute',
    count: 8,
    puzzleTheme: 'quietMove',
    minRating: 1200,
    maxRating: 1800,
    concept:
        'The hardest moves to find give no check and capture nothing — they tighten the net: covering escapes, renewing threats, preparing mate that cannot be stopped.',
    takeaway: 'When every forcing move fails, improve quietly.',
    instruction: 'Find the winning quiet move.',
    ideaNoun: 'the quiet move',
    mistakeText:
        'Forcing moves all fail here. Look for the quiet improvement that leaves no defence.',
    hintTemplate: 'No check and no capture wins — find the quiet move that ends all resistance.',
    quizQuestion: 'Why are quiet moves hard to find?',
    quizOptions: [
      'They are illegal',
      'They give no check and win nothing at once — they prepare the unstoppable',
      'Engines cannot see them',
    ],
    quizAnswer: 1,
  ),
];

const List<MotifPack> kEndgamePacks = [
  MotifPack(
    id: 'rookend',
    categoryId: 'end_rook_endings',
    categoryTitle: 'Rook Endgames',
    categorySubtitle: 'The most common endgame',
    sectionId: 'endgames',
    difficulty: 'Intermediate',
    icon: 'castle',
    count: 20,
    puzzleTheme: 'rookEndgame',
    minRating: 600,
    maxRating: 1600,
    concept:
        'Rook endgames are the most frequent of all. Core skills: activate the rook behind passed pawns, cut off the enemy king, and know the Philidor (defending) and Lucena (winning) positions.',
    takeaway: 'Active rook, distant king, passed pawn pushed.',
    instruction: 'Convert the rook endgame.',
    ideaNoun: 'rook activity',
    mistakeText:
        'That leaves your rook passive. Activate it — behind your passed pawn or cutting off their king.',
    hintTemplate: 'Rooks belong behind passed pawns and far from the enemy king.',
    quizQuestion: 'Where does a rook belong in a rook endgame?',
    quizOptions: [
      'Next to its own king, defending',
      'Active: behind passed pawns or cutting off the enemy king',
      'Traded off immediately',
    ],
    quizAnswer: 1,
  ),
  MotifPack(
    id: 'pawnend',
    categoryId: 'end_pawn_endings',
    categoryTitle: 'Pawn Endgames',
    categorySubtitle: 'Kings and pawns only',
    sectionId: 'endgames',
    difficulty: 'Beginner',
    icon: 'circle',
    count: 15,
    puzzleTheme: 'pawnEndgame',
    minRating: 600,
    maxRating: 1400,
    concept:
        'With only kings and pawns, every tempo matters: the opposition, the square rule for stopping passed pawns, and breakthrough sacrifices decide everything.',
    takeaway: 'Count tempos. King first, pawn second.',
    instruction: 'Win the pawn endgame.',
    ideaNoun: 'the key tempo',
    mistakeText:
        'That drops the critical tempo. In pawn endings every king step must gain ground or keep opposition.',
    hintTemplate: 'Count who queens first. Use opposition and breakthroughs.',
    quizQuestion: 'What is the opposition?',
    quizOptions: [
      'Having more pawns',
      'Kings facing each other with one square between — whoever must move loses ground',
      'Trading all pawns',
    ],
    quizAnswer: 1,
  ),
  MotifPack(
    id: 'queenend',
    categoryId: 'end_queen_endings',
    categoryTitle: 'Queen Endgames',
    categorySubtitle: 'Perpetuals and promotion races',
    sectionId: 'endgames',
    difficulty: 'Advanced',
    icon: 'queen',
    count: 8,
    puzzleTheme: 'queenEndgame',
    minRating: 600,
    maxRating: 1800,
    concept:
        'Queen endgames swing between promotion races and perpetual checks. Centralize the queen, escort your pawn from the side, and never let the enemy queen settle into endless checks.',
    takeaway: 'Central queen, sideways escort, no perpetuals.',
    instruction: 'Navigate the queen endgame.',
    ideaNoun: 'queen centralization',
    mistakeText:
        'That allows endless checks or loses the race. Centralize and time the pawn push.',
    hintTemplate: 'Centralize the queen and time the pawn advance.',
    quizQuestion: 'The biggest danger when winning a queen endgame is…',
    quizOptions: [' stalemate tricks only', 'Perpetual check', 'The fifty-move rule only'],
    quizAnswer: 1,
  ),
  MotifPack(
    id: 'bishopend',
    categoryId: 'end_bishop_endings',
    categoryTitle: 'Bishop Endgames',
    categorySubtitle: 'Color complexes decide',
    sectionId: 'endgames',
    difficulty: 'Intermediate',
    icon: 'diagonal',
    count: 8,
    puzzleTheme: 'bishopEndgame',
    minRating: 600,
    maxRating: 1600,
    concept:
        'Same-color bishop endings are drawish; opposite-color ones favor the attacker. Fix enemy pawns on your bishop’s color and use your king as the battering ram.',
    takeaway: 'Fix pawns on your color; march the king.',
    instruction: 'Handle the bishop endgame.',
    ideaNoun: 'the color complex',
    mistakeText:
        'That ignores the color battle. Fix their pawns on your bishop’s color first.',
    hintTemplate: 'Pawns fixed on your bishop’s color are targets. Attack them with king and bishop.',
    quizQuestion: 'Why do opposite-color bishop endings favor the attacker?',
    quizOptions: [
      'Bishops are worth more then',
      'The defender’s bishop can never guard what the attacker’s bishop attacks',
      'There are more pawns',
    ],
    quizAnswer: 1,
  ),
  MotifPack(
    id: 'knightend',
    categoryId: 'end_knight_endings',
    categoryTitle: 'Knight Endgames',
    categorySubtitle: 'Outposts and domination',
    sectionId: 'endgames',
    difficulty: 'Intermediate',
    icon: 'horse',
    count: 6,
    puzzleTheme: 'knightEndgame',
    minRating: 600,
    maxRating: 1600,
    concept:
        'Knights need outposts and short distances. Dominate the enemy knight by attacking everything it defends, and push pawns on the side your knight controls.',
    takeaway: 'Outpost first, then push where the knight points.',
    instruction: 'Outplay the knight endgame.',
    ideaNoun: 'the outpost',
    mistakeText:
        'That drifts without a plan. Plant the knight on its best square, then advance there.',
    hintTemplate: 'Find the outpost square your knight can never be chased from.',
    quizQuestion: 'What is a knight outpost?',
    quizOptions: [
      'Any central square',
      'A square on the enemy’s side that cannot be attacked by a pawn',
      'The starting square',
    ],
    quizAnswer: 1,
  ),
  MotifPack(
    id: 'qrend',
    categoryId: 'end_queen_rook_endings',
    categoryTitle: 'Queen vs Rook Endings',
    categorySubtitle: 'Convert the extra exchange',
    sectionId: 'endgames',
    difficulty: 'Advanced',
    icon: 'swap',
    count: 5,
    puzzleTheme: 'queenRookEndgame',
    minRating: 600,
    maxRating: 1800,
    concept:
        'Queen against rook is winning but fiddly: avoid fortress setups, keep the queen mobile, and force the rook into passivity before collecting it or the pawns.',
    takeaway: 'No fortresses: keep tension until the rook cracks.',
    instruction: 'Convert queen versus rook.',
    ideaNoun: 'restriction',
    mistakeText:
        'That lets the rook get active or build a fortress. Restrict it first, collect second.',
    hintTemplate: 'Tie the rook to defence, then pick up pawns or the rook itself.',
    quizQuestion: 'The main risk with queen vs rook is…',
    quizOptions: [
      'Losing on time only',
      'Allowing a fortress or perpetual activity',
      'Stalemate on move one',
    ],
    quizAnswer: 1,
  ),
  MotifPack(
    id: 'promotion',
    categoryId: 'end_promotion',
    categoryTitle: 'Promotion Tactics',
    categorySubtitle: 'Queen the pawn',
    sectionId: 'endgames',
    difficulty: 'Beginner',
    icon: 'arrow_upward',
    count: 10,
    puzzleTheme: 'promotion',
    minRating: 600,
    maxRating: 1400,
    concept:
        'Pushing a passed pawn through takes calculation: count the race, sacrifice to clear the path, and remember underpromotion when stalemate or a knight fork threatens.',
    takeaway: 'Count the squares, clear the path, queen with check when you can.',
    instruction: 'Force the promotion through.',
    ideaNoun: 'the promotion',
    mistakeText:
        'That mis-times the race. Count moves to queen for both sides before pushing.',
    hintTemplate: 'Count the race first — then clear the pawn’s path by force.',
    quizQuestion: 'When is underpromotion correct?',
    quizOptions: [
      'Never',
      'To avoid stalemate or to deliver a knight fork/check',
      'When you dislike queens',
    ],
    quizAnswer: 1,
  ),
  MotifPack(
    id: 'advpawn',
    categoryId: 'end_advanced_pawns',
    categoryTitle: 'Advanced Pawns',
    categorySubtitle: 'Push, support, breakthrough',
    sectionId: 'endgames',
    difficulty: 'Beginner',
    icon: 'fast_forward',
    count: 8,
    puzzleTheme: 'advancedPawn',
    minRating: 600,
    maxRating: 1300,
    concept:
        'A far-advanced pawn ties down whole armies. Support it with the king, use breakthrough sacrifices to open lines, and never push without counting the reply.',
    takeaway: 'Supported passers win games.',
    instruction: 'Push the passer through.',
    ideaNoun: 'the passed pawn',
    mistakeText:
        'That pushes without support. Bring the king up first — lone passers get rounded up.',
    hintTemplate: 'Support the passer with the king before pushing it further.',
    quizQuestion: 'What makes a passed pawn strong?',
    quizOptions: [
      'Its color',
      'No enemy pawn can stop it, especially with king support',
      'Being doubled',
    ],
    quizAnswer: 1,
  ),
];

const List<MotifPack> kStrategyPacks = [
  MotifPack(
    id: 'kingside',
    categoryId: 'strat_kingside_attack',
    categoryTitle: 'Kingside Attacks',
    categorySubtitle: 'Storm the enemy king',
    sectionId: 'middlegame_strategy',
    difficulty: 'Intermediate',
    icon: 'storm',
    count: 20,
    puzzleTheme: 'kingsideAttack',
    minRating: 600,
    maxRating: 1700,
    concept:
        'Attack the king where it lives: open lines toward it, bring every piece, and strike before the defender consolidates. Pawn storms, piece sacrifices to open the h-file, and mating nets all belong here.',
    takeaway: 'Speed kills: attack with everything before they defend.',
    instruction: 'Break through on the kingside.',
    ideaNoun: 'the breakthrough',
    mistakeText:
        'That is too slow — the defence will consolidate. Every move must threaten or bring a new attacker.',
    hintTemplate: 'Open a line to the king and pile every piece onto it.',
    quizQuestion: 'The golden rule of a kingside attack is…',
    quizOptions: [
      'Trade all the pieces first',
      'Attack fast with everything — do not let them consolidate',
      'Push queenside pawns',
    ],
    quizAnswer: 1,
  ),
  MotifPack(
    id: 'exposed',
    categoryId: 'strat_exposed_king',
    categoryTitle: 'Exposed Kings',
    categorySubtitle: 'Punish the wandering king',
    sectionId: 'middlegame_strategy',
    difficulty: 'Intermediate',
    icon: 'exposure',
    count: 12,
    puzzleTheme: 'exposedKing',
    minRating: 600,
    maxRating: 1700,
    concept:
        'A king caught in the center or stripped of pawn cover is a target for the rest of the game. Open the position, keep queens on, and hunt it — do not let it castle by hand.',
    takeaway: 'Open lines against an uncastled king, always.',
    instruction: 'Punish the exposed king.',
    ideaNoun: 'the king hunt',
    mistakeText:
        'That lets the king escape to safety. Keep the position open and the pressure on.',
    hintTemplate: 'The king has no shelter — open lines and bring checks.',
    quizQuestion: 'Against an uncastled king you should…',
    quizOptions: [
      'Trade queens to simplify',
      'Keep the position open and attack before it finds shelter',
      'Castle yourself immediately whatever the cost',
    ],
    quizAnswer: 1,
  ),
  MotifPack(
    id: 'queenside',
    categoryId: 'strat_queenside_attack',
    categoryTitle: 'Queenside Play',
    categorySubtitle: 'Minority attacks and open files',
    sectionId: 'middlegame_strategy',
    difficulty: 'Advanced',
    icon: 'west',
    count: 10,
    puzzleTheme: 'queensideAttack',
    minRating: 600,
    maxRating: 1800,
    concept:
        'Queenside majorities, minority attacks creating weaknesses, and pressure down the c-file: the queenside rewards patience — create a weakness, then switch fronts.',
    takeaway: 'Create the weakness first, exploit it second.',
    instruction: 'Press on the queenside.',
    ideaNoun: 'the weakness',
    mistakeText:
        'That has no target. First fix a queenside weakness, then attack it.',
    hintTemplate: 'Find the queenside weakness to fix and attack.',
    quizQuestion: 'What is a minority attack?',
    quizOptions: [
      'Attacking with fewer pieces',
      'Advancing fewer pawns to provoke weaknesses in the enemy majority',
      'Sacrificing the minority',
    ],
    quizAnswer: 1,
  ),
  MotifPack(
    id: 'f7',
    categoryId: 'strat_f2_f7',
    categoryTitle: 'Attacking f2 / f7',
    categorySubtitle: 'The weakest squares',
    sectionId: 'middlegame_strategy',
    difficulty: 'Beginner',
    icon: 'target',
    count: 8,
    puzzleTheme: 'attackingF2F7',
    minRating: 600,
    maxRating: 1400,
    concept:
        'f7 (and f2) starts defended only by the king — the weakest squares on the board. Bishops, knights and queens combine against them in countless opening traps and middlegame blows.',
    takeaway: 'Always ask: who defends f7?',
    instruction: 'Strike on f2/f7.',
    ideaNoun: 'the f7 weakness',
    mistakeText:
        'That misses the weakest square. Count the attackers and defenders on f7 first.',
    hintTemplate: 'f7 is defended by the king alone — pile onto it.',
    quizQuestion: 'Why is f7 weak at the start?',
    quizOptions: [
      'It is off the board',
      'Only the king defends it',
      'Pawns cannot reach it',
    ],
    quizAnswer: 1,
  ),
  MotifPack(
    id: 'advantage',
    categoryId: 'strat_converting_advantage',
    categoryTitle: 'Converting Advantages',
    categorySubtitle: 'Turn better into won',
    sectionId: 'middlegame_strategy',
    difficulty: 'Advanced',
    icon: 'trending_up',
    count: 10,
    puzzleTheme: 'advantage',
    minRating: 1400,
    maxRating: 2000,
    concept:
        'Winning an advantage is half the job. Convert it: improve your worst piece, fix enemy weaknesses, open a second front, and trade into endgames you win — without letting counterplay breathe.',
    takeaway: 'Better means: improve, restrict, then collect.',
    instruction: 'Convert the advantage cleanly.',
    ideaNoun: 'the conversion',
    mistakeText:
        'That drifts and lets counterplay in. With an edge, every move should improve or restrict.',
    hintTemplate: 'Find your worst piece and improve it while denying counterplay.',
    quizQuestion: 'The key to converting an advantage is…',
    quizOptions: [
      'Attacking randomly',
      'Improving your pieces, restricting counterplay, then collecting',
      'Offering draws',
    ],
    quizAnswer: 1,
  ),
];

/// An opening line to turn into a lesson. UCI moves are replayed and
/// verified — invalid lines are dropped with a report, never shipped.
class OpeningSpec {
  final String eco;
  final String name;
  final String category;
  final String family;
  final List<String> uci;
  final String note;
  const OpeningSpec({
    required this.eco,
    required this.name,
    required this.category,
    required this.family,
    required this.uci,
    required this.note,
  });
}

/// Family plan text: the ideas behind whole groups of openings.
const Map<String, Map<String, String>> kOpeningFamilies = {
  'italian': {
    'white': 'Develop fast, control the centre, castle early, then play c3+d4 or d3 with kingside chances.',
    'black': 'Meet Bc4 with Nf6+…Bc5 or …Be7, keep …d5 break in reserve, do not drift with …h6/…a6.',
    'themes': 'Rapid development, d4 break, kingside attack',
  },
  'spanish': {
    'white': 'Pressure e5 via the pin, build the centre with c3+d4, choose open or closed middlegames.',
    'black': 'Counter with …d6+…Nbd7 (Breyer/Zaitsev solidity) or …d5 breaks; Marshall gambit for the brave.',
    'themes': 'Long-term e5 pressure, pawn structure choice, piece harmony',
  },
  'scotch': {
    'white': 'Open the centre early, develop with tempo, attack before Black catches up in development.',
    'black': 'Develop quickly, neutralize the centre, target the e4 pawn if White overextends.',
    'themes': 'Early central tension, tempo, development race',
  },
  'petrov': {
    'white': 'Accept the symmetrical fight, push d4, keep the initiative with precise central play.',
    'black': 'The solid reply to e4: mirror, then break symmetry at the right moment.',
    'themes': 'Symmetry, central breaks, solid development',
  },
  'sicilian_open': {
    'white': 'Build the Maroczy or English Attack: space, kingside pawn storm, sacrifices on d5/e6.',
    'black': 'Counterpunch on the queenside and centre (…d5), dragon-style …g6 fianchetto or Najdorf …a6 flexibility.',
    'themes': 'Opposite-side castling, pawn storms, dynamic counterplay',
  },
  'sicilian_closed': {
    'white': 'Avoid heavy theory: kingside fianchetto, slow build, f4 breaks.',
    'black': 'Strike the centre with …d5/…e5, develop harmoniously, no weaknesses.',
    'themes': 'Slow buildup, central counter, flexible development',
  },
  'french': {
    'white': 'Space with e5, attack the base of the pawn chain, kingside chances in Winawer/Steinitz.',
    'black': 'Attack the chain base at d4 with …c5+…Nc6, queenside counterplay, free the light-squared bishop.',
    'themes': 'Pawn chains, base attacks, wing counterplay',
  },
  'caro': {
    'white': 'Space and development; Panov-Botvinnik gives isolated-queen-pawn play.',
    'black': 'Rock-solid: …c6 supports …d5, develop the light-squared bishop early, minimal weakness.',
    'themes': 'Solid structure, bishop development, endgame comfort',
  },
  'pirc_modern': {
    'white': 'Occupy the centre, punish slow development with e5 or f4-f5 breaks.',
    'black': 'Hypermodern: let White build the centre, then strike it with …c5/…e5/…d5.',
    'themes': 'Hypermodernism, centre undermining, counterattacks',
  },
  'scandi': {
    'white': 'Lead in development after Qxd5, play for the centre with tempo on the queen.',
    'black': 'Provoke and develop fast; the queen retreat costs time but the structure is sound.',
    'themes': 'Tempo play, fast development, queen safety',
  },
  'kid': {
    'white': 'Space with e4+d4+c4, restrain …e5/…c5 breaks, queenside majority in the endgame.',
    'black': 'Kingside pawn storm (…f5) against castled king; sacrifice lines (Benko-style) for initiative.',
    'themes': 'Pawn storms, opposite wings, dynamic imbalance',
  },
  'nimzo_qgd': {
    'white': 'Build the classical centre, use the bishop pair if Black doubles pawns.',
    'black': 'Pin and pressure e4; Nimzo doubles White pawns, QGD holds solidly with …Be7/…Nbd7.',
    'themes': 'Pin pressure, doubled pawns, classical centre',
  },
  'slav_catalan': {
    'white': 'Slav: space and development. Catalan: long-term queenside pressure with the g2 bishop.',
    'black': 'Slav: keep the structure sound with …c6. Anti-Catalan: challenge the centre early.',
    'themes': 'Fianchetto pressure, pawn structure, patient squeezes',
  },
  'london_colle': {
    'white': 'System play: solid pyramid, develop safely, strike with e4 or Ne5 plans.',
    'black': 'Challenge the setup early with …c5/…Qb6, or mirror solidly and outplay positionally.',
    'themes': 'System openings, safe development, setup familiarity',
  },
  'english_reti': {
    'white': 'Flank control of d5, flexible transpositions, kingside fianchetto attacks.',
    'black': 'Occupy the centre to blunt the flank, develop classically.',
    'themes': 'Flank strategy, transpositions, flexibility',
  },
  'vienna_gambits': {
    'white': 'Fast development with tempo, gambits for open lines against the king.',
    'black': 'Return material for development, hold the centre, castle fast.',
    'themes': 'Tempo, gambit compensation, king safety',
  },
};

const List<OpeningSpec> kOpeningSpecs = [
  OpeningSpec(eco: 'C50', name: 'Italian Game: Giuoco Piano', category: "King's Pawn (1. e4)", family: 'italian', uci: ['e2e4', 'e7e5', 'g1f3', 'b8c6', 'f1c4', 'f8c5'], note: 'The quiet game: both sides develop before the central tension breaks.'),
  OpeningSpec(eco: 'C51', name: 'Italian Game: Evans Gambit', category: "King's Pawn (1. e4)", family: 'italian', uci: ['e2e4', 'e7e5', 'g1f3', 'b8c6', 'f1c4', 'f8c5', 'b2b4'], note: 'White sacrifices a wing pawn for a lasting lead in development and central control.'),
  OpeningSpec(eco: 'C55', name: 'Italian Game: Two Knights Defence', category: "King's Pawn (1. e4)", family: 'italian', uci: ['e2e4', 'e7e5', 'g1f3', 'b8c6', 'f1c4', 'g8f6'], note: 'Black counterattacks e4 at once — sharp Wilkes-Barre and Fried Liver territory.'),
  OpeningSpec(eco: 'C60', name: 'Ruy Lopez: Cozio Defence', category: "King's Pawn (1. e4)", family: 'spanish', uci: ['e2e4', 'e7e5', 'g1f3', 'b8c6', 'f1b5', 'g8e7'], note: 'A solid sideline: Black develops without committing the kingside knight.'),
  OpeningSpec(eco: 'C70', name: 'Ruy Lopez: Morphy Defence', category: "King's Pawn (1. e4)", family: 'spanish', uci: ['e2e4', 'e7e5', 'g1f3', 'b8c6', 'f1b5', 'a7a6'], note: 'The main road of the Spanish: Black questions the bishop immediately.'),
  OpeningSpec(eco: 'C77', name: 'Ruy Lopez: Anderssen Variation', category: "King's Pawn (1. e4)", family: 'spanish', uci: ['e2e4', 'e7e5', 'g1f3', 'b8c6', 'f1b5', 'a7a6', 'b5a4', 'g8f6', 'e1g1', 'f8e7'], note: 'Classical closed Lopez development from both sides.'),
  OpeningSpec(eco: 'C80', name: 'Ruy Lopez: Open Defence', category: "King's Pawn (1. e4)", family: 'spanish', uci: ['e2e4', 'e7e5', 'g1f3', 'b8c6', 'f1b5', 'a7a6', 'b5a4', 'g8f6', 'e1g1', 'f6e4'], note: 'Black grabs the centre pawn and holds it with active piece play.'),
  OpeningSpec(eco: 'C90', name: 'Ruy Lopez: Closed Defence', category: "King's Pawn (1. e4)", family: 'spanish', uci: ['e2e4', 'e7e5', 'g1f3', 'b8c6', 'f1b5', 'a7a6', 'b5a4', 'g8f6', 'e1g1', 'f8e7', 'f1e1', 'b7b5', 'a4b3', 'd7d6'], note: 'The historic main line: manoeuvring behind pawn chains.'),
  OpeningSpec(eco: 'C45', name: 'Scotch Game: Classical', category: "King's Pawn (1. e4)", family: 'scotch', uci: ['e2e4', 'e7e5', 'g1f3', 'b8c6', 'd2d4', 'e5d4', 'f3d4', 'g8f6'], note: 'Open centre, fast development — Mieses and Kasparov territory.'),
  OpeningSpec(eco: 'C44', name: 'Scotch Game: Scotch Gambit', category: "King's Pawn (1. e4)", family: 'scotch', uci: ['e2e4', 'e7e5', 'g1f3', 'b8c6', 'd2d4', 'e5d4', 'f1c4'], note: 'White offers the pawn for a lead in development and open lines.'),
  OpeningSpec(eco: 'C42', name: "Petrov's Defence: Classical", category: "King's Pawn (1. e4)", family: 'petrov', uci: ['e2e4', 'e7e5', 'g1f3', 'g8f6', 'f3e5', 'd7d6', 'e5f3', 'f6e4'], note: 'Symmetrical and rock-solid; Black equalizes with precise central play.'),
  OpeningSpec(eco: 'C41', name: 'Philidor Defence', category: "King's Pawn (1. e4)", family: 'petrov', uci: ['e2e4', 'e7e5', 'g1f3', 'd7d6'], note: 'An old solid wall: Black holds the centre but must mind development.'),
  OpeningSpec(eco: 'B20', name: 'Sicilian Defence: Bowdler Attack', category: "King's Pawn (1. e4)", family: 'sicilian_closed', uci: ['e2e4', 'c7c5', 'b1c3', 'b8c6', 'g2g3'], note: 'A calm anti-Sicilian: fianchetto and slow buildup.'),
  OpeningSpec(eco: 'B23', name: 'Sicilian Defence: Closed', category: "King's Pawn (1. e4)", family: 'sicilian_closed', uci: ['e2e4', 'c7c5', 'b1c3', 'b8c6', 'g2g3', 'g7g6', 'f1g2', 'f8g7'], note: 'Double fianchetto sparring before the central break.'),
  OpeningSpec(eco: 'B27', name: 'Sicilian Defence: Modern', category: "King's Pawn (1. e4)", family: 'sicilian_closed', uci: ['e2e4', 'c7c5', 'g1f3', 'g7g6'], note: 'Black fianchettoes first, keeping …Nf6/…Bg7 flexibility.'),
  OpeningSpec(eco: 'B40', name: 'Sicilian Defence: French Variation', category: "King's Pawn (1. e4)", family: 'sicilian_open', uci: ['e2e4', 'c7c5', 'g1f3', 'e7e6', 'd2d4', 'c5d4', 'f3d4', 'g8f6'], note: 'A French-like centre with Sicilian counterchances.'),
  OpeningSpec(eco: 'B50', name: 'Sicilian Defence: Modern Variations', category: "King's Pawn (1. e4)", family: 'sicilian_open', uci: ['e2e4', 'c7c5', 'g1f3', 'd7d6', 'f1c4'], note: 'The Sozin-style bishop eyes f7 from move 5.'),
  OpeningSpec(eco: 'B53', name: 'Sicilian Defence: Chekhover', category: "King's Pawn (1. e4)", family: 'sicilian_open', uci: ['e2e4', 'c7c5', 'g1f3', 'd7d6', 'd2d4', 'c5d4', 'd1d4'], note: 'Early queen development with central pressure.'),
  OpeningSpec(eco: 'B70', name: 'Sicilian Defence: Dragon', category: "King's Pawn (1. e4)", family: 'sicilian_open', uci: ['e2e4', 'c7c5', 'g1f3', 'd7d6', 'd2d4', 'c5d4', 'f3d4', 'g8f6', 'b1c3', 'g7g6'], note: 'The fiercest Sicilian: opposite-side castling and mutual pawn storms.'),
  OpeningSpec(eco: 'B90', name: 'Sicilian Defence: Najdorf', category: "King's Pawn (1. e4)", family: 'sicilian_open', uci: ['e2e4', 'c7c5', 'g1f3', 'd7d6', 'd2d4', 'c5d4', 'f3d4', 'g8f6', 'b1c3', 'a7a6'], note: 'Fischer and Kasparov’s weapon: maximal flexibility, endless theory.'),
  OpeningSpec(eco: 'B80', name: 'Sicilian Defence: Scheveningen', category: "King's Pawn (1. e4)", family: 'sicilian_open', uci: ['e2e4', 'c7c5', 'g1f3', 'd7d6', 'd2d4', 'c5d4', 'f3d4', 'g8f6', 'b1c3', 'e7e6'], note: 'The small centre: solid, flexible, Kasparov-approved.'),
  OpeningSpec(eco: 'B30', name: 'Sicilian Defence: Nyezhmetdinov-Rossolimo', category: "King's Pawn (1. e4)", family: 'sicilian_open', uci: ['e2e4', 'c7c5', 'g1f3', 'b8c6', 'f1b5'], note: 'Spanish-style pressure without heavy Open Sicilian theory.'),
  OpeningSpec(eco: 'B22', name: 'Sicilian Defence: Alapin', category: "King's Pawn (1. e4)", family: 'sicilian_closed', uci: ['e2e4', 'c7c5', 'c2c3'], note: 'The practical anti-Sicilian: a solid centre with minimal theory.'),
  OpeningSpec(eco: 'B21', name: 'Sicilian Defence: Smith-Morra Gambit', category: "King's Pawn (1. e4)", family: 'sicilian_closed', uci: ['e2e4', 'c7c5', 'd2d4', 'c5d4', 'c2c3'], note: 'A pawn for open lines and a development lead — club-player terror.'),
  OpeningSpec(eco: 'C02', name: 'French Defence: Advance', category: "King's Pawn (1. e4)", family: 'french', uci: ['e2e4', 'e7e6', 'd2d4', 'd7d5', 'e4e5'], note: 'White grabs space; Black undermines d4 with …c5 and …Nc6.'),
  OpeningSpec(eco: 'C11', name: 'French Defence: Steinitz', category: "King's Pawn (1. e4)", family: 'french', uci: ['e2e4', 'e7e6', 'd2d4', 'd7d5', 'b1c3', 'g8f6'], note: 'Classical pressure on e4 before White consolidates.'),
  OpeningSpec(eco: 'C15', name: 'French Defence: Winawer', category: "King's Pawn (1. e4)", family: 'french', uci: ['e2e4', 'e7e6', 'd2d4', 'd7d5', 'b1c3', 'f8b4'], note: 'The sharpest French: doubled pawns and opposite-side attacks.'),
  OpeningSpec(eco: 'C00', name: 'French Defence: Exchange', category: "King's Pawn (1. e4)", family: 'french', uci: ['e2e4', 'e7e6', 'd2d4', 'd7d5', 'e4d5', 'e6d5'], note: 'Symmetrical and drawish — but White keeps a tiny development edge.'),
  OpeningSpec(eco: 'B12', name: 'Caro-Kann: Advance', category: "King's Pawn (1. e4)", family: 'caro', uci: ['e2e4', 'c7c6', 'd2d4', 'd7d5', 'e4e5'], note: 'Space versus the bishop: Black develops Bf5 before locking the centre.'),
  OpeningSpec(eco: 'B18', name: 'Caro-Kann: Classical', category: "King's Pawn (1. e4)", family: 'caro', uci: ['e2e4', 'c7c6', 'd2d4', 'd7d5', 'b1c3', 'd5e4', 'c3e4', 'c8f5'], note: 'Karpov’s wall: the light-squared bishop breathes before …e6.'),
  OpeningSpec(eco: 'B14', name: 'Caro-Kann: Panov-Botvinnik', category: "King's Pawn (1. e4)", family: 'caro', uci: ['e2e4', 'c7c6', 'd2d4', 'd7d5', 'e4d5', 'c6d5', 'c2c4'], note: 'Isolated-queen-pawn middlegames with chances for both sides.'),
  OpeningSpec(eco: 'B07', name: 'Pirc Defence', category: "King's Pawn (1. e4)", family: 'pirc_modern', uci: ['e2e4', 'd7d6', 'd2d4', 'g8f6', 'b1c3', 'g7g6'], note: 'Let White build, then undermine: …c5/…e5 breaks follow.'),
  OpeningSpec(eco: 'B06', name: 'Modern Defence', category: "King's Pawn (1. e4)", family: 'pirc_modern', uci: ['e2e4', 'g7g6', 'd2d4', 'f8g7'], note: 'Hypermodern fianchetto: invite the centre, then strike it.'),
  OpeningSpec(eco: 'B01', name: 'Scandinavian Defence', category: "King's Pawn (1. e4)", family: 'scandi', uci: ['e2e4', 'd7d5', 'e4d5', 'd8d5'], note: 'The queen comes out early; Black develops with gain of time trades.'),
  OpeningSpec(eco: 'B02', name: 'Alekhine Defence', category: "King's Pawn (1. e4)", family: 'scandi', uci: ['e2e4', 'g8f6', 'e4e5', 'f6d5', 'd2d4', 'd7d6'], note: 'Provoke the pawns forward, then undermine the overextended centre.'),
  OpeningSpec(eco: 'A40', name: "Queen's Pawn: Modern", category: "Queen's Pawn (1. d4)", family: 'english_reti', uci: ['d2d4', 'g8f6', 'c2c4', 'e7e6', 'g1f3', 'b7b6'], note: 'Queen’s Indian setups: fianchetto pressure on the long diagonal.'),
  OpeningSpec(eco: 'E00', name: 'Catalan Opening', category: "Queen's Pawn (1. d4)", family: 'slav_catalan', uci: ['d2d4', 'g8f6', 'c2c4', 'e7e6', 'g2g3'], note: 'The g2 bishop grinds for 40 moves: pressure without risk.'),
  OpeningSpec(eco: 'E12', name: "Queen's Indian Defence", category: "Queen's Pawn (1. d4)", family: 'slav_catalan', uci: ['d2d4', 'g8f6', 'c2c4', 'e7e6', 'g1f3', 'b7b6'], note: 'Solid fianchetto defence: exchange the white bishop when it suits.'),
  OpeningSpec(eco: 'E20', name: 'Nimzo-Indian Defence', category: "Queen's Pawn (1. d4)", family: 'nimzo_qgd', uci: ['d2d4', 'g8f6', 'c2c4', 'e7e6', 'b1c3', 'f8b4'], note: 'Pin, double, pressure: the most respected defence to 1.d4.'),
  OpeningSpec(eco: 'E30', name: 'Nimzo-Indian: Leningrad', category: "Queen's Pawn (1. d4)", family: 'nimzo_qgd', uci: ['d2d4', 'g8f6', 'c2c4', 'e7e6', 'b1c3', 'f8b4', 'c1g5'], note: 'White develops aggressively before committing the centre pawns.'),
  OpeningSpec(eco: 'D30', name: "Queen's Gambit Declined", category: "Queen's Pawn (1. d4)", family: 'nimzo_qgd', uci: ['d2d4', 'd7d5', 'c2c4', 'e7e6', 'b1c3', 'g8f6'], note: 'The classical answer: hold the centre, develop, castle. Century-tested.'),
  OpeningSpec(eco: 'D35', name: 'QGD: Exchange Variation', category: "Queen's Pawn (1. d4)", family: 'nimzo_qgd', uci: ['d2d4', 'd7d5', 'c2c4', 'e7e6', 'b1c3', 'g8f6', 'c4d5', 'e6d5'], note: 'The Carlsbad structure: minority attack plans for White.'),
  OpeningSpec(eco: 'D10', name: 'Slav Defence', category: "Queen's Pawn (1. d4)", family: 'slav_catalan', uci: ['d2d4', 'd7d5', 'c2c4', 'c7c6'], note: 'Keeps the c8 bishop’s diagonal open — the QGD’s problem solved.'),
  OpeningSpec(eco: 'D16', name: 'Slav Defence: Krause', category: "Queen's Pawn (1. d4)", family: 'slav_catalan', uci: ['d2d4', 'd7d5', 'c2c4', 'c7c6', 'g1f3', 'g8f6', 'b1c3', 'd5c4'], note: 'Black grabs the gambit pawn and holds it with …b5. Greedy and sound.'),
  OpeningSpec(eco: 'E60', name: "King's Indian Defence", category: "Queen's Pawn (1. d4)", family: 'kid', uci: ['d2d4', 'g8f6', 'c2c4', 'g7g6', 'b1c3', 'f8g7', 'e2e4', 'd7d6'], note: 'The fighting fianchetto: concede the centre, then storm the kingside.'),
  OpeningSpec(eco: 'E90', name: 'KID: Classical Variation', category: "Queen's Pawn (1. d4)", family: 'kid', uci: ['d2d4', 'g8f6', 'c2c4', 'g7g6', 'b1c3', 'f8g7', 'e2e4', 'd7d6', 'g1f3', 'e8g8', 'f1e2', 'e7e5'], note: 'Bayonet and …f5 storms: the sharpest strategic battleground in chess.'),
  OpeningSpec(eco: 'A57', name: 'Benko Gambit', category: "Queen's Pawn (1. d4)", family: 'kid', uci: ['d2d4', 'g8f6', 'c2c4', 'c7c5', 'd4d5', 'b7b5'], note: 'A pawn for queenside pressure that lasts the whole game.'),
  OpeningSpec(eco: 'A60', name: 'Benoni Defence: Modern', category: "Queen's Pawn (1. d4)", family: 'kid', uci: ['d2d4', 'g8f6', 'c2c4', 'c7c5', 'd4d5', 'e7e6'], note: 'Imbalanced and double-edged: e5 outpost versus queenside majority.'),
  OpeningSpec(eco: 'A45', name: 'London System', category: "Queen's Pawn (1. d4)", family: 'london_colle', uci: ['d2d4', 'g8f6', 'c1f4', 'e7e6', 'g1f3', 'c7c5'], note: 'The system everyone plays: develop the same way, outplay them later.'),
  OpeningSpec(eco: 'D05', name: 'Colle System', category: "Queen's Pawn (1. d4)", family: 'london_colle', uci: ['d2d4', 'g8f6', 'g1f3', 'e7e6', 'e2e3', 'c7c5', 'c2c3'], note: 'Solid pyramid, e4 break coming: simple and venomous at club level.'),
  OpeningSpec(eco: 'A10', name: 'English Opening', category: 'Flank Openings', family: 'english_reti', uci: ['c2c4'], note: 'Fight for d5 from the flank; transpose or stay independent.'),
  OpeningSpec(eco: 'A20', name: "English Opening: King's English", category: 'Flank Openings', family: 'english_reti', uci: ['c2c4', 'e7e5', 'b1c3', 'g8f6'], note: 'Reversed Sicilian structures with an extra tempo for White.'),
  OpeningSpec(eco: 'A30', name: 'English Opening: Symmetrical', category: 'Flank Openings', family: 'english_reti', uci: ['c2c4', 'c7c5', 'g1f3', 'b8c6'], note: 'Hedgehog structures: cramped but unbreakable for Black.'),
  OpeningSpec(eco: 'A09', name: 'Réti Opening', category: 'Flank Openings', family: 'english_reti', uci: ['g1f3', 'd7d5', 'c2c4'], note: 'Hypermodern flank pressure before occupying the centre.'),
  OpeningSpec(eco: 'A04', name: 'Réti: Kingside Fianchetto', category: 'Flank Openings', family: 'english_reti', uci: ['g1f3', 'g8f6', 'g2g3', 'd7d5', 'f1g2'], note: 'The double fianchetto squeeze: pressure from both wings.'),
  OpeningSpec(eco: 'C25', name: 'Vienna Game', category: "King's Pawn (1. e4)", family: 'vienna_gambits', uci: ['e2e4', 'e7e5', 'b1c3'], note: 'Delayed central punch with f4 coming: aggressive yet sound.'),
  OpeningSpec(eco: 'C27', name: 'Vienna Gambit', category: "King's Pawn (1. e4)", family: 'vienna_gambits', uci: ['e2e4', 'e7e5', 'b1c3', 'g8f6', 'f2f4'], note: 'A pawn for open f-file lines and a flying start in development.'),
  OpeningSpec(eco: 'C30', name: "King's Gambit Declined", category: "King's Pawn (1. e4)", family: 'vienna_gambits', uci: ['e2e4', 'e7e5', 'f2f4', 'f8c5'], note: 'Black declines the pawn and develops: solidity against the storm.'),
  OpeningSpec(eco: 'C33', name: "King's Gambit Accepted", category: "King's Pawn (1. e4)", family: 'vienna_gambits', uci: ['e2e4', 'e7e5', 'f2f4', 'e5f4'], note: 'Romantic chess: open lines and initiative against precise defence.'),
  OpeningSpec(eco: 'C44', name: "King's Pawn Game: Ponziani", category: "King's Pawn (1. e4)", family: 'scotch', uci: ['e2e4', 'e7e5', 'g1f3', 'b8c6', 'c2c3'], note: 'Old and tricky: build the full centre with d4 to come.'),
  OpeningSpec(eco: 'C46', name: 'Three Knights Opening', category: "King's Pawn (1. e4)", family: 'scotch', uci: ['e2e4', 'e7e5', 'g1f3', 'b8c6', 'b1c3', 'g8f6'], note: 'Quiet development that can veer into Four Knights or Belgrade tactics.'),
  OpeningSpec(eco: 'C49', name: 'Four Knights: Spanish', category: "King's Pawn (1. e4)", family: 'scotch', uci: ['e2e4', 'e7e5', 'g1f3', 'b8c6', 'b1c3', 'g8f6', 'f1b5', 'f8b4'], note: 'Symmetrical knights, Spanish flavour: solid with sting.'),
  OpeningSpec(eco: 'C24', name: "Bishop's Opening", category: "King's Pawn (1. e4)", family: 'italian', uci: ['e2e4', 'e7e5', 'f1c4'], note: 'Italian ideas a move early, sidestepping the Petrov.'),
  OpeningSpec(eco: 'B00', name: "King's Pawn Opening", category: "King's Pawn (1. e4)", family: 'pirc_modern', uci: ['e2e4', 'b7b6'], note: "Owen's Defence: fianchetto pressure on e4 from move one."),
  OpeningSpec(eco: 'A00', name: 'Polish Opening', category: 'Flank Openings', family: 'english_reti', uci: ['b2b4'], note: 'Flank provocation: sidestep theory from move one.'),
  OpeningSpec(eco: 'A03', name: "Bird's Opening", category: 'Flank Openings', family: 'english_reti', uci: ['f2f4'], note: 'Dutch with a tempo: kingside ambitions, e5 weakness to mind.'),
  OpeningSpec(eco: 'A80', name: 'Dutch Defence', category: "Queen's Pawn (1. d4)", family: 'kid', uci: ['d2d4', 'f7f5'], note: 'Fight for e4 from the flank; Leningrad …g6 setups are sharpest.'),
  OpeningSpec(eco: 'D00', name: "Queen's Pawn Game", category: "Queen's Pawn (1. d4)", family: 'london_colle', uci: ['d2d4', 'd7d5', 'g1f3', 'g8f6', 'c1f4'], note: 'London-style development against anything Black tries.'),
  OpeningSpec(eco: 'D02', name: "Queen's Gambit: Zukertort", category: "Queen's Pawn (1. d4)", family: 'london_colle', uci: ['d2d4', 'd7d5', 'g1f3'], note: 'Flexible move order into QGD, Slav or Catalan waters.'),
  OpeningSpec(eco: 'E10', name: 'Blumenfeld Countergambit', category: "Queen's Pawn (1. d4)", family: 'kid', uci: ['d2d4', 'g8f6', 'c2c4', 'e7e6', 'g1f3', 'c7c5', 'd4d5', 'b7b5'], note: 'Benko ideas in a Nimzo move order: flank pressure for a pawn.'),
  OpeningSpec(eco: 'B10', name: 'Caro-Kann: Two Knights', category: "King's Pawn (1. e4)", family: 'caro', uci: ['e2e4', 'c7c6', 'b1c3', 'd7d5', 'g1f3'], note: 'Sidestep mainline Caro theory while keeping central tension.'),
  OpeningSpec(eco: 'B15', name: 'Caro-Kann: Tartakower', category: "King's Pawn (1. e4)", family: 'caro', uci: ['e2e4', 'c7c6', 'd2d4', 'd7d5', 'b1c3', 'd5e4', 'c3e4', 'g8f6', 'e4f6', 'e7f6'], note: 'Black accepts doubled pawns for open lines and bishop activity.'),
  OpeningSpec(eco: 'C08', name: 'French Defence: Tarrasch Open', category: "King's Pawn (1. e4)", family: 'french', uci: ['e2e4', 'e7e6', 'd2d4', 'd7d5', 'b1d2', 'c7c5'], note: 'Open the position before White’s knight block becomes permanent.'),
  OpeningSpec(eco: 'C14', name: 'French Defence: Classical', category: "King's Pawn (1. e4)", family: 'french', uci: ['e2e4', 'e7e6', 'd2d4', 'd7d5', 'b1c3', 'g8f6', 'e4e5', 'f6d7'], note: 'Steinitz structures: Black prepares …c5 and …f6 breaks.'),
  OpeningSpec(eco: 'C18', name: 'French Defence: Winawer Advance', category: "King's Pawn (1. e4)", family: 'french', uci: ['e2e4', 'e7e6', 'd2d4', 'd7d5', 'b1c3', 'f8b4', 'e4e5', 'c7c5'], note: 'The sharpest French main line: pawn chains and wing storms.'),
  OpeningSpec(eco: 'B30a', name: 'Sicilian: O’Kelly Variation', category: "King's Pawn (1. e4)", family: 'sicilian_open', uci: ['e2e4', 'c7c5', 'g1f3', 'a7a6'], note: 'A flexible waiting move that can transpose into Najdorf or Kan waters.'),
  OpeningSpec(eco: 'B41', name: 'Sicilian Defence: Kan', category: "King's Pawn (1. e4)", family: 'sicilian_open', uci: ['e2e4', 'c7c5', 'g1f3', 'e7e6', 'd2d4', 'c5d4', 'f3d4', 'a7a6'], note: 'Paulsen-style flexibility: …Qc7, …b5 and …d5 breaks on demand.'),
  OpeningSpec(eco: 'B48', name: 'Sicilian: Taimanov', category: "King's Pawn (1. e4)", family: 'sicilian_open', uci: ['e2e4', 'c7c5', 'g1f3', 'e7e6', 'd2d4', 'c5d4', 'f3d4', 'b8c6'], note: 'Kasparov’s counterpunching system: …Nge7, …d5 in one go.'),
  OpeningSpec(eco: 'B61', name: 'Sicilian: Richter-Rauzer', category: "King's Pawn (1. e4)", family: 'sicilian_open', uci: ['e2e4', 'c7c5', 'g1f3', 'd7d6', 'd2d4', 'c5d4', 'f3d4', 'g8f6', 'b1c3', 'b8c6', 'c1g5'], note: 'Pin and pressure d6: White plays for the two bishops and e5.'),
  OpeningSpec(eco: 'B75', name: 'Sicilian Dragon: Yugoslav Attack', category: "King's Pawn (1. e4)", family: 'sicilian_open', uci: ['e2e4', 'c7c5', 'g1f3', 'd7d6', 'd2d4', 'c5d4', 'f3d4', 'g8f6', 'b1c3', 'g7g6', 'c1e3', 'f8g7', 'f2f3'], note: 'The critical test of the Dragon: Be3, Qd2, long castle, h4-h5 storm.'),
];

String _normFen(String fen) {
  final parts = fen.split(' ');
  if (parts.length < 4) return fen;
  return '${parts[0]} ${parts[1]} ${parts[2]} ${parts[3]}';
}

class _VerifiedMove {
  final String uci;
  final String san;
  _VerifiedMove(this.uci, this.san);
}

/// Replay [uciMoves] from [fen]. Returns SAN list or null if any move illegal.
List<_VerifiedMove>? _replay(String fen, List<String> uciMoves) {
  final board = chess.Chess.fromFEN(fen);
  final out = <_VerifiedMove>[];
  for (final raw in uciMoves) {
    var u = raw.trim().toLowerCase();
    if (u.length < 4) return null;
    final from = u.substring(0, 2);
    final to = u.substring(2, 4);
    final promo = u.length >= 5 ? u.substring(4, 5) : null;
    String? san;
    try {
      final legal = board.moves({'verbose': true}) as List;
      for (final m in legal) {
        final mm = Map<String, dynamic>.from(m as Map);
        if (mm['from'] == from && mm['to'] == to) {
          final mp = (mm['promotion'] ?? '').toString();
          if (promo != null && mp.isNotEmpty && mp[0] != promo) continue;
          san = mm['san'] as String?;
          break;
        }
      }
      if (san == null) return null;
      if (promo != null) {
        board.move({'from': from, 'to': to, 'promotion': promo});
      } else {
        board.move({'from': from, 'to': to});
      }
    } catch (_) {
      return null;
    }
    out.add(_VerifiedMove(u, san!));
  }
  return out;
}

String _finalFen(String fen, List<String> uciMoves) {
  final board = chess.Chess.fromFEN(fen);
  for (final raw in uciMoves) {
    final u = raw.trim().toLowerCase();
    final from = u.substring(0, 2);
    final to = u.substring(2, 4);
    if (u.length >= 5) {
      board.move({'from': from, 'to': to, 'promotion': u.substring(4, 5)});
    } else {
      board.move({'from': from, 'to': to});
    }
  }
  return board.fen;
}

bool _endsInMate(String fen, List<String> uciMoves) {
  try {
    final board = chess.Chess.fromFEN(fen);
    for (final raw in uciMoves) {
      final u = raw.trim().toLowerCase();
      final from = u.substring(0, 2);
      final to = u.substring(2, 4);
      if (u.length >= 5) {
        board.move({'from': from, 'to': to, 'promotion': u.substring(4, 5)});
      } else {
        board.move({'from': from, 'to': to});
      }
    }
    return board.in_checkmate;
  } catch (_) {
    return false;
  }
}

/// Split a Lichess puzzle into lesson position + solver line.
///
/// Lichess format: FEN is the position BEFORE the opponent's setup move, and
/// moves[0] is that setup (opponent) move. The lesson starts AFTER it, with
/// the solver to move. Trailing opponent replies are trimmed so the user
/// always plays the decisive move last.
({String fen, List<String> solution})? _solvePosition(
  String fen,
  List<String> moves,
) {
  if (moves.length < 2) return null;
  String lessonFen;
  try {
    final board = chess.Chess.fromFEN(fen);
    final setup = moves.first.trim().toLowerCase();
    if (setup.length < 4) return null;
    final from = setup.substring(0, 2);
    final to = setup.substring(2, 4);
    // The setup move must be legal for the side to move (the opponent).
    final legal = board.moves({'verbose': true}) as List;
    var found = false;
    for (final m in legal) {
      final mm = Map<String, dynamic>.from(m as Map);
      if (mm['from'] == from && mm['to'] == to) {
        found = true;
        break;
      }
    }
    if (!found) return null;
    if (setup.length >= 5) {
      board.move({'from': from, 'to': to, 'promotion': setup.substring(4, 5)});
    } else {
      board.move({'from': from, 'to': to});
    }
    lessonFen = board.fen;
  } catch (_) {
    return null;
  }
  var solution = moves.sublist(1).map((m) => m.trim().toLowerCase()).toList();
  if (solution.isEmpty) return null;
  if (solution.length % 2 == 0) {
    // Ends with an opponent reply the user would never play — trim it.
    solution = solution.sublist(0, solution.length - 1);
  }
  if (solution.isEmpty) return null;
  return (fen: lessonFen, solution: solution);
}

/// Narration for one player move, derived from the actual move played.
String _narrate(MotifPack pack, int playerMoveNumber, String san) {
  final clean = san.replaceAll('+', '').replaceAll('#', '');
  final isMate = san.endsWith('#');
  final isCheck = san.endsWith('+') || isMate;
  final isCapture = clean.contains('x');
  final idea = pack.ideaNoun;
  if (isMate) return 'Move $playerMoveNumber: $san — $idea delivers checkmate. ${pack.takeaway}';
  if (isCheck && isCapture) {
    return 'Move $playerMoveNumber: $san — check with capture! $idea wins material with tempo.';
  }
  if (isCheck) {
    return 'Move $playerMoveNumber: $san — forcing check. $idea keeps the initiative: every reply is bad.';
  }
  if (isCapture) {
    return 'Move $playerMoveNumber: $san — $idea collects material. ${pack.takeaway}';
  }
  return 'Move $playerMoveNumber: $san — $idea. ${pack.takeaway}';
}

Map<String, dynamic> _buildChapter(
  MotifPack pack,
  int index,
  Map<String, dynamic> puzzle,
  List<_VerifiedMove> verified,
) {
  final num = index + 1;
  final fen = puzzle['fen'] as String;
  final solutionUci = verified.map((v) => v.uci).toList();
  final playerSans = <String>[];
  for (var i = 0; i < verified.length; i += 2) {
    playerSans.add(verified[i].san);
  }
  final narration = <String>[];
  for (var i = 0; i < playerSans.length; i++) {
    narration.add(_narrate(pack, i + 1, playerSans[i]));
  }
  final firstSan = verified.first.san;
  final side = fen.split(' ')[1] == 'b' ? 'Black' : 'White';
  return {
    'id': '${pack.id}_$num',
    'categoryId': pack.categoryId,
    'type': 'guided_try',
    'title': '${pack.categoryTitle} $num',
    'fen': fen,
    'instruction': '$side to move. ${pack.instruction}',
    'concept': pack.concept,
    'takeaway': pack.takeaway,
    'solutionMoves': solutionUci,
    'narration': narration,
    'shapes': [solutionUci.first],
    'hints': [pack.hintTemplate, 'The key move starts with $firstSan.'],
    'mistakeText': pack.mistakeText,
    'explanation':
        '${pack.takeaway} Solution${solutionUci.length > 1 ? 's' : ''}: ${playerSans.join(', ')}.',
    'quiz': {
      'question': pack.quizQuestion,
      'options': pack.quizOptions,
      'answer': pack.quizAnswer,
    },
  };
}

void main() {
  final puzzlesFile = File('assets/puzzles/puzzles.json');
  final puzzles =
      (json.decode(puzzlesFile.readAsStringSync()) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

  final usedFens = <String>{};
  final chapters = <String, Map<String, dynamic>>{};
  final categories = <String, Map<String, dynamic>>{};
  final report = <String>[];
  var dropped = 0;

  final allPacks = [
    ...kMatePacks,
    ...kFundamentalPacks,
    ...kIntermediatePacks,
    ...kEndgamePacks,
    ...kStrategyPacks,
  ];

  for (final pack in allPacks) {
    final candidates =
        puzzles.where((p) {
          final themes = (p['themes'] ?? '').toString().split(' ');
          final rating = (p['rating'] as num?)?.toInt() ?? 0;
          return themes.contains(pack.puzzleTheme) &&
              rating >= pack.minRating &&
              rating <= pack.maxRating;
        }).toList();
    candidates.sort(
      (a, b) => ((b['popularity'] as num?) ?? 0).compareTo(
        (a['popularity'] as num?) ?? 0,
      ),
    );
    // Progressive difficulty: interleave popularity with rating order.
    candidates.sort((a, b) {
      final pa = ((a['popularity'] as num?) ?? 0).toInt();
      final pb = ((b['popularity'] as num?) ?? 0).toInt();
      final ra = ((a['rating'] as num?) ?? 0).toInt();
      final rb = ((b['rating'] as num?) ?? 0).toInt();
      if ((pa >= 80) != (pb >= 80)) return pb.compareTo(pa);
      return ra.compareTo(rb);
    });

    var made = 0;
    var scanned = 0;
    for (final p in candidates) {
      if (made >= pack.count) break;
      scanned++;
      final rawFen = p['fen'] as String;
      final moves =
          (p['moves'] ?? '').toString().split(' ').where((m) => m.length >= 4).toList();
      if (moves.length < 2) continue;
      // Strip the opponent setup move: lesson starts with solver to move.
      final solved = _solvePosition(rawFen, moves);
      if (solved == null) {
        dropped++;
        continue;
      }
      final key = _normFen(solved.fen);
      if (usedFens.contains(key)) continue;
      final verified = _replay(solved.fen, solved.solution);
      if (verified == null || verified.isEmpty) {
        dropped++;
        continue;
      }
      // Mate lessons must actually end in checkmate.
      if (pack.mustMate && !_endsInMate(solved.fen, solved.solution)) {
        dropped++;
        continue;
      }
      usedFens.add(key);
      made++;
      final puzzle = Map<String, dynamic>.from(p)..['fen'] = solved.fen;
      final chapter = _buildChapter(pack, made - 1, puzzle, verified);
      chapters[chapter['id'] as String] = chapter;
    }
    categories[pack.categoryId] = {
      'id': pack.categoryId,
      'title': pack.categoryTitle,
      'subtitle': pack.categorySubtitle,
      'difficulty': pack.difficulty,
      'icon': pack.icon,
      'chapterIds': List.generate(made, (i) => '${pack.id}_${i + 1}'),
    };
    report.add(
      '${pack.id}: made $made/${pack.count} (scanned $scanned candidates)',
    );
    if (made < pack.count) {
      report.add('  WARNING: shortfall of ${pack.count - made}');
    }
  }

  // ---- Openings: replay lines, derive SAN + FEN, attach family plans ----
  final openings = <Map<String, dynamic>>[];
  final openingCats = <String, List<String>>{};
  var openingDropped = 0;
  var openingIndex = 0;
  for (final spec in kOpeningSpecs) {
    const startFen =
        'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
    final verified = _replay(startFen, spec.uci);
    if (verified == null || verified.isEmpty) {
      openingDropped++;
      report.add('OPENING DROPPED (illegal line): ${spec.eco} ${spec.name}');
      continue;
    }
    openingIndex++;
    final family = kOpeningFamilies[spec.family]!;
    final sans = verified.map((v) => v.san).toList();
    final fen = _finalFen(startFen, spec.uci);
    final id = 'op_${openingIndex}';
    openings.add({
      'id': id,
      'eco': spec.eco,
      'name': spec.name,
      'category': spec.category,
      'type': 'walkthrough',
      'concept':
          'White plan: ${family['white']} Black plan: ${family['black']}',
      'takeaway': 'Ideas over moves: ${family['themes']}.',
      'instruction': 'Play through the main line and learn both sides’ plans.',
      'solutionMoves': spec.uci,
      'movesSan': sans,
      'narration': [
        'Main line: ${sans.join(' ')}. ${spec.note}',
        'White plan: ${family['white']}',
        'Black plan: ${family['black']}',
      ],
      'fen': startFen,
      'finalFen': fen,
      'description':
          '${spec.name} (${spec.eco}). ${spec.note} White plan: ${family['white']} Black plan: ${family['black']}',
      'keyThemes': (family['themes'] as String).split(', '),
      'quiz': {
        'question': 'What matters most when learning ${spec.name}?',
        'options': [
          'Memorizing every move order',
          'Understanding both sides’ plans: ${family['themes']}',
          'Avoiding the opening entirely',
        ],
        'answer': 1,
      },
    });
    openingCats
        .putIfAbsent(spec.category, () => [])
        .add(id);
  }

  // Opening categories + section.
  var opCatNum = 0;
  for (final entry in openingCats.entries) {
    opCatNum++;
    categories['opening_group_$opCatNum'] = {
      'id': 'opening_group_$opCatNum',
      'title': entry.key,
      'subtitle': '${entry.value.length} essential lines with plans',
      'difficulty': 'Intermediate',
      'icon': 'menu_book',
      'chapterIds': entry.value,
    };
  }
  // Merge opening lessons into chapters map.
  for (final o in openings) {
    chapters[o['id'] as String] = o;
  }

  // ---- Curriculum ----
  final sections = [
    {
      'id': 'checkmates',
      'title': 'Checkmate Mastery',
      'description': 'From back-rank basics to famous mating patterns.',
      'icon': 'military_tech',
      'categories':
          categories.values
              .where((c) => kMatePacks.any((p) => p.categoryId == c['id']))
              .toList(),
    },
    {
      'id': 'fundamental_tactics',
      'title': 'Fundamental Tactics',
      'description': 'Forks, pins, skewers and the everyday tools of winning material.',
      'icon': 'flash_on',
      'categories':
          categories.values
              .where(
                (c) => kFundamentalPacks.any((p) => p.categoryId == c['id']),
              )
              .toList(),
    },
    {
      'id': 'advanced_tactics',
      'title': 'Advanced Tactics',
      'description': 'Clearance, interference, zugzwang and quiet killers.',
      'icon': 'psychology',
      'categories':
          categories.values
              .where(
                (c) => kIntermediatePacks.any((p) => p.categoryId == c['id']),
              )
              .toList(),
    },
    {
      'id': 'endgames',
      'title': 'Endgame Essentials',
      'description': 'Rook endings, pawn races, promotion and technique.',
      'icon': 'castle',
      'categories':
          categories.values
              .where((c) => kEndgamePacks.any((p) => p.categoryId == c['id']))
              .toList(),
    },
    {
      'id': 'middlegame_strategy',
      'title': 'Middlegame & Strategy',
      'description': 'Attack the king, press weaknesses, convert advantages.',
      'icon': 'terrain',
      'categories':
          categories.values
              .where((c) => kStrategyPacks.any((p) => p.categoryId == c['id']))
              .toList(),
    },
    {
      'id': 'openings',
      'title': 'Opening Repertoire',
      'description': '80 essential lines taught as plans, not memorization.',
      'icon': 'menu_book',
      'categories':
          categories.values
              .where((c) => (c['id'] as String).startsWith('opening_group_'))
              .toList(),
    },
  ];

  // ---- Backup + write ----
  final backupDir = Directory('assets/lessons/backup');
  backupDir.createSync(recursive: true);
  final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
  for (final name in ['lessons_data.json', 'curriculum.json', 'openings.json']) {
    final f = File('assets/lessons/$name');
    if (f.existsSync()) {
      f.copySync('assets/lessons/backup/${name.replaceAll('.json', '')}_v1_$stamp.json');
    }
  }
  File('assets/lessons/lessons_data.json').writeAsStringSync(json.encode(chapters));
  File(
    'assets/lessons/curriculum.json',
  ).writeAsStringSync(json.encode({'sections': sections}));
  File('assets/lessons/openings.json').writeAsStringSync(json.encode(openings));

  // ---- Report ----
  print('=== LESSON BUILD REPORT ===');
  for (final line in report) {
    print(line);
  }
  final lessonCount = chapters.length - openings.length;
  print('Lessons (tactics/mates/endgames/strategy): $lessonCount');
  print('Opening lessons: ${openings.length}');
  print('TOTAL chapters: ${chapters.length}');
  print('Dropped invalid puzzle lines: $dropped');
  print('Dropped invalid opening lines: $openingDropped');
  print('Categories: ${categories.length}');
}



