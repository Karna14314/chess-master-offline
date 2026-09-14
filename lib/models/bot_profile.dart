import 'package:flutter/material.dart';
import 'package:chess_master/core/constants/app_constants.dart';

/// Bot classification tier
enum BotTier {
  beginner,
  intermediate,
  advanced,
  master;

  String get displayName {
    switch (this) {
      case BotTier.beginner:
        return 'Beginner';
      case BotTier.intermediate:
        return 'Intermediate';
      case BotTier.advanced:
        return 'Advanced';
      case BotTier.master:
        return 'Master';
    }
  }

  Color get color {
    switch (this) {
      case BotTier.beginner:
        return const Color(0xFF8D6E63); // Warm Wood Bronze
      case BotTier.intermediate:
        return const Color(0xFF78909C); // Cool Silver Slate
      case BotTier.advanced:
        return const Color(0xFFFFB300); // Radiant Gold
      case BotTier.master:
        return const Color(0xFF00E5FF); // Diamond Cyan
    }
  }

  List<Color> get gradient {
    switch (this) {
      case BotTier.beginner:
        return [const Color(0xFF8D6E63), const Color(0xFF5D4037)];
      case BotTier.intermediate:
        return [const Color(0xFF90A4AE), const Color(0xFF455A64)];
      case BotTier.advanced:
        return [const Color(0xFFFFD54F), const Color(0xFFFF8F00)];
      case BotTier.master:
        return [const Color(0xFF18FFFF), const Color(0xFF7C4DFF)];
    }
  }
}

/// Head-to-head stats against a specific bot
class BotStats {
  final int wins;
  final int draws;
  final int losses;
  final int bestStars; // 0: unplayed/not won, 1-3: stars earned

  const BotStats({
    this.wins = 0,
    this.draws = 0,
    this.losses = 0,
    this.bestStars = 0,
  });

  int get totalGames => wins + draws + losses;
  bool get hasBeaten => wins > 0;

  BotStats copyWith({
    int? wins,
    int? draws,
    int? losses,
    int? bestStars,
  }) {
    return BotStats(
      wins: wins ?? this.wins,
      draws: draws ?? this.draws,
      losses: losses ?? this.losses,
      bestStars: bestStars ?? this.bestStars,
    );
  }

  Map<String, dynamic> toJson() => {
    'wins': wins,
    'draws': draws,
    'losses': losses,
    'bestStars': bestStars,
  };

  factory BotStats.fromJson(Map<String, dynamic> json) {
    return BotStats(
      wins: json['wins'] as int? ?? 0,
      draws: json['draws'] as int? ?? 0,
      losses: json['losses'] as int? ?? 0,
      bestStars: json['bestStars'] as int? ?? 0,
    );
  }
}

/// Dynamic bot dialogue reactions for in-game banter (Chess.com style)
class BotDialogue {
  final String greeting;
  final List<String> onPlayerBlunder;
  final List<String> onGoodMove;
  final String onWin;
  final String onLoss;

  const BotDialogue({
    required this.greeting,
    this.onPlayerBlunder = const ['Did you mean to play that?'],
    this.onGoodMove = const ['Nice move!'],
    this.onWin = 'Good game!',
    this.onLoss = 'Well played, you got me!',
  });
}

/// Character model for an individual bot opponent
class BotProfile {
  final String id;
  final String name;
  final int elo;
  final BotTier tier;
  final String bio;
  final String quote;
  final IconData avatarIcon;
  final List<Color> avatarGradient;
  final List<String> styleTags;
  final BotType engineType;
  final int searchDepth;
  final double blunderRate; // Probability (0.0 - 1.0) of making an intentional suboptimal move
  final String openingStyle;
  final BotDialogue dialogue;

  const BotProfile({
    required this.id,
    required this.name,
    required this.elo,
    required this.tier,
    required this.bio,
    required this.quote,
    required this.avatarIcon,
    required this.avatarGradient,
    required this.styleTags,
    required this.engineType,
    this.searchDepth = 3,
    this.blunderRate = 0.0,
    this.openingStyle = 'Balanced',
    required this.dialogue,
  });

  bool get isHeuristicBot => engineType == BotType.simple;

  DifficultyLevel get difficultyLevel {
    return DifficultyLevel(
      level: (elo / 280).clamp(1, 10).round(),
      elo: elo,
      depth: searchDepth,
      thinkTimeMs: isHeuristicBot ? 300 : 700,
      name: name,
    );
  }

  // ==========================================
  // Static Registry of 20+ Unique Bot Personalities
  // ==========================================

  static const List<BotProfile> allBots = [
    // -------------------------------------------------------------
    // Tier 1: Beginner (400 - 950 ELO) — Powered by Pure Dart Rule-Based
    // -------------------------------------------------------------
    BotProfile(
      id: 'bot_rusty',
      name: 'Rusty',
      elo: 400,
      tier: BotTier.beginner,
      bio: 'Rusty was assembled from scrap parts. He gets confused by diagonals and moves his knights in circles.',
      quote: "Beep boop! Are pawns supposed to march backwards?",
      avatarIcon: Icons.precision_manufacturing_rounded,
      avatarGradient: [Color(0xFF8D6E63), Color(0xFF4E342E)],
      styleTags: ['Beginner', 'Blunder Prone', 'Goofy'],
      engineType: BotType.simple,
      searchDepth: 1,
      blunderRate: 0.45,
      openingStyle: 'Random',
      dialogue: BotDialogue(
        greeting: "Bzzzt! Hello human, I hope I don't short-circuit!",
        onPlayerBlunder: [
          "Ooh, shiny piece! I think I'll take that!",
          "My sensors detect a mistake... or do they?",
        ],
        onGoodMove: ["Bzzzt! Error 404: Countermove not found!"],
        onWin: "Beep boop! My rusty gears worked this time!",
        onLoss: "Smoke is coming out! Good game human!",
      ),
    ),
    BotProfile(
      id: 'bot_pete',
      name: 'Pawn Pusher Pete',
      elo: 500,
      tier: BotTier.beginner,
      bio: 'Pete believes pawns are the true royalty of chess. He will push every pawn on the board before touching a piece.',
      quote: "Why develop pieces when you have 8 perfectly good pawns?",
      avatarIcon: Icons.directions_walk_rounded,
      avatarGradient: [Color(0xFFA1887F), Color(0xFF3E2723)],
      styleTags: ['Pawn Pusher', 'Stubborn'],
      engineType: BotType.simple,
      searchDepth: 1,
      blunderRate: 0.35,
      openingStyle: 'Pawn Flanks',
      dialogue: BotDialogue(
        greeting: "March on, foot soldiers! Let's conquer the board!",
        onPlayerBlunder: ["A gap in your lines! My pawns advance!"],
        onGoodMove: ["Hey! Stop capturing my little guys!"],
        onWin: "Pawn power always prevails!",
        onLoss: "My pawn wall broke! Rematch soon!",
      ),
    ),
    BotProfile(
      id: 'bot_oliver',
      name: 'Oliver',
      elo: 650,
      tier: BotTier.beginner,
      bio: 'Oliver learned chess just yesterday. He sees 1-move captures and gets thrilled whenever he can give check.',
      quote: "Check! Did I win yet?",
      avatarIcon: Icons.face_rounded,
      avatarGradient: [Color(0xFF81C784), Color(0xFF2E7D32)],
      styleTags: ['Casual', 'Check Addict', 'Friendly'],
      engineType: BotType.simple,
      searchDepth: 2,
      blunderRate: 0.28,
      openingStyle: 'Center Push',
      dialogue: BotDialogue(
        greeting: "Hi there! I practiced all morning for this!",
        onPlayerBlunder: ["Ooh, thanks for the free piece!"],
        onGoodMove: ["Whoa, you're pretty smart!"],
        onWin: "Yay!! I actually won!",
        onLoss: "Aww, you're too good! Let's play again!",
      ),
    ),
    BotProfile(
      id: 'bot_clara',
      name: 'Cautious Clara',
      elo: 750,
      tier: BotTier.beginner,
      bio: 'Clara despises confrontation. She castles early, hides behind a fortress, and trades pieces whenever possible.',
      quote: "Safety first! Let's trade queens and keep things civilized.",
      avatarIcon: Icons.shield_rounded,
      avatarGradient: [Color(0xFF64B5F6), Color(0xFF1565C0)],
      styleTags: ['Defensive', 'Trades Pieces', 'Calm'],
      engineType: BotType.simple,
      searchDepth: 2,
      blunderRate: 0.20,
      openingStyle: 'Solid Fortress',
      dialogue: BotDialogue(
        greeting: "Welcome. Let us have a calm, orderly game.",
        onPlayerBlunder: ["I shall accept that trade, thank you."],
        onGoodMove: ["An alarming threat... I must reinforce my king."],
        onWin: "Safety always triumphs over recklessness.",
        onLoss: "A well-executed siege. Congratulations.",
      ),
    ),
    BotProfile(
      id: 'bot_aaron',
      name: 'Attacking Aaron',
      elo: 850,
      tier: BotTier.beginner,
      bio: 'Aaron brings his Queen out on move two and tries for Scholar\'s Mate every game. Explosive but overextends.',
      quote: "Defense is for the weak! My Queen will checkmate you right now.",
      avatarIcon: Icons.bolt_rounded,
      avatarGradient: [Color(0xFFFF7043), Color(0xFFD84315)],
      styleTags: ['Aggressive', 'Early Queen', 'Wild'],
      engineType: BotType.simple,
      searchDepth: 3,
      blunderRate: 0.16,
      openingStyle: 'Wayward Queen',
      dialogue: BotDialogue(
        greeting: "Prepare for non-stop action! No boring draws here!",
        onPlayerBlunder: ["BOOM! Didn't see that attack coming, did you?"],
        onGoodMove: ["Argh! How did you defend that?"],
        onWin: "Full throttle victory! That was awesome!",
        onLoss: "I went all-in and got countered! Great game!",
      ),
    ),
    BotProfile(
      id: 'bot_timmy',
      name: 'Tactical Timmy',
      elo: 950,
      tier: BotTier.beginner,
      bio: 'Timmy knows basic forks and skewers, but falls apart in the endgame if you survive his early tactical tricks.',
      quote: "Watch out for my knights! I see a double attack coming.",
      avatarIcon: Icons.psychology_rounded,
      avatarGradient: [Color(0xFFBA68C8), Color(0xFF6A1B9A)],
      styleTags: ['Tactical', 'Knight Forks', 'Clever'],
      engineType: BotType.simple,
      searchDepth: 3,
      blunderRate: 0.12,
      openingStyle: 'Italian Game',
      dialogue: BotDialogue(
        greeting: "Keep your eyes on the board, tactics can strike anywhere!",
        onPlayerBlunder: ["Fork alert! Caught you off guard!"],
        onGoodMove: ["Nice defense, I didn't see that resource."],
        onWin: "Checkmate! My tactical puzzle paid off!",
        onLoss: "Your endgame technique was too clean. Well played!",
      ),
    ),

    // -------------------------------------------------------------
    // Tier 2: Intermediate (1050 - 1450 ELO)
    // -------------------------------------------------------------
    BotProfile(
      id: 'bot_maya',
      name: 'Maya',
      elo: 1050,
      tier: BotTier.intermediate,
      bio: 'Maya plays classical, sound chess. She controls the center, develops knights before bishops, and punishes free pieces.',
      quote: "Patience and solid fundamentals win the game.",
      avatarIcon: Icons.balance_rounded,
      avatarGradient: [Color(0xFF4DB6AC), Color(0xFF00695C)],
      styleTags: ['Solid', 'Classical', 'Disciplined'],
      engineType: BotType.simple,
      searchDepth: 3,
      blunderRate: 0.08,
      openingStyle: 'King\'s Pawn',
      dialogue: BotDialogue(
        greeting: "Good day. Let us test our fundamental principles.",
        onPlayerBlunder: ["That compromises your structure."],
        onGoodMove: ["Sound play. The center is contested."],
        onWin: "Discipline rewarded. Thank you for the match.",
        onLoss: "Excellently converted. You played very accurately.",
      ),
    ),
    BotProfile(
      id: 'bot_viktor',
      name: 'Viktor the Gambiteer',
      elo: 1150,
      tier: BotTier.intermediate,
      bio: 'Viktor loves sacrifices. He plays the Danish Gambit and King\'s Gambit without hesitation to open up lines.',
      quote: "Pawns are just fuel for a glorious attack!",
      avatarIcon: Icons.local_fire_department_rounded,
      avatarGradient: [Color(0xFFFF5252), Color(0xFFC62828)],
      styleTags: ['Gambit', 'Attacking', 'Bold'],
      engineType: BotType.simple,
      searchDepth: 4,
      blunderRate: 0.05,
      openingStyle: 'Gambits',
      dialogue: BotDialogue(
        greeting: "Take my pawns if you dare! The open file is mine!",
        onPlayerBlunder: ["Greed is punished! Feel the pressure!"],
        onGoodMove: ["A sturdy block. But can you withstand the next wave?"],
        onWin: "The gambit triumphs in style!",
        onLoss: "You consolidated the extra material beautifully. Bravo!",
      ),
    ),
    BotProfile(
      id: 'bot_elena',
      name: 'Elena',
      elo: 1250,
      tier: BotTier.intermediate,
      bio: 'Elena is a positional strategist who loves open files for rooks and outpost squares for knights.',
      quote: "Every piece has its ideal square. Have you misplaced yours?",
      avatarIcon: Icons.auto_graph_rounded,
      avatarGradient: [Color(0xFF7986CB), Color(0xFF283593)],
      styleTags: ['Positional', 'Strategic', 'Patient'],
      engineType: BotType.simple,
      searchDepth: 4,
      blunderRate: 0.03,
      openingStyle: 'Queen\'s Gambit',
      dialogue: BotDialogue(
        greeting: "Welcome. Let us see who commands the critical squares.",
        onPlayerBlunder: ["A strategic weakness has been conceded."],
        onGoodMove: ["An elegant positional squeeze."],
        onWin: "The squares yielded to superior harmony.",
        onLoss: "Superb maneuvering. You dominated the board.",
      ),
    ),
    BotProfile(
      id: 'bot_felix',
      name: 'Felix',
      elo: 1350,
      tier: BotTier.intermediate,
      bio: 'Felix is the first tier powered by native Stockfish. He rarely blunders hanging pieces and calculates 3-4 moves ahead.',
      quote: "No easy blunders today. Show me your best calculation.",
      avatarIcon: Icons.workspace_premium_rounded,
      avatarGradient: [Color(0xFF4FC3F7), Color(0xFF0277BD)],
      styleTags: ['Calculative', 'Balanced', 'Consistent'],
      engineType: BotType.stockfish,
      searchDepth: 4,
      blunderRate: 0.0,
      openingStyle: 'Sicilian Defense',
      dialogue: BotDialogue(
        greeting: "Ready to test your concrete calculation?",
        onPlayerBlunder: ["My calculation confirms an advantage."],
        onGoodMove: ["Precise move. The position remains complex."],
        onWin: "Calculation held firm. Good game.",
        onLoss: "Your tactical vision was sharper today. Well done!",
      ),
    ),
    BotProfile(
      id: 'bot_zara',
      name: 'Zara',
      elo: 1450,
      tier: BotTier.intermediate,
      bio: 'Zara plays fast, sharp, dynamic chess. She will test your tactical vision with pins and discovered checks.',
      quote: "Let's speed up the tempo and see who blinks first.",
      avatarIcon: Icons.speed_rounded,
      avatarGradient: [Color(0xFFFF4081), Color(0xFFC2185B)],
      styleTags: ['Sharp', 'Tactical', 'Dynamic'],
      engineType: BotType.stockfish,
      searchDepth: 5,
      blunderRate: 0.0,
      openingStyle: 'Modern Defense',
      dialogue: BotDialogue(
        greeting: "Fasten your seatbelt, things get sharp quickly!",
        onPlayerBlunder: ["Tempo gained! You're on the defensive now!"],
        onGoodMove: ["Quick reflexes! I like your style."],
        onWin: "Speed and initiative won the day!",
        onLoss: "You handled the chaos better than I did. Great game!",
      ),
    ),

    // -------------------------------------------------------------
    // Tier 3: Advanced (1550 - 2150 ELO) — Stockfish UCI
    // -------------------------------------------------------------
    BotProfile(
      id: 'bot_marcus',
      name: 'Marcus "The Wall"',
      elo: 1550,
      tier: BotTier.advanced,
      bio: 'Marcus grinds down opponents with ironclad defense. He avoids tactical complications and wins with superior pawn structure.',
      quote: "Break through if you can. My fortress has no cracks.",
      avatarIcon: Icons.castle_rounded,
      avatarGradient: [Color(0xFFFFB74D), Color(0xFFE65100)],
      styleTags: ['Rock Solid', 'Endgame', 'Stout'],
      engineType: BotType.stockfish,
      searchDepth: 7,
      blunderRate: 0.0,
      openingStyle: 'Caro-Kann',
      dialogue: BotDialogue(
        greeting: "You will find no easy entry into my camp.",
        onPlayerBlunder: ["An impatience error. The structure falls."],
        onGoodMove: ["You are probing carefully. Admirable."],
        onWin: "The wall held. Patience brings victory.",
        onLoss: "Incredible breach. You dismantled my defense.",
      ),
    ),
    BotProfile(
      id: 'bot_sophia',
      name: 'Sophia',
      elo: 1700,
      tier: BotTier.advanced,
      bio: 'Sophia is a club champion who seamlessly transitions from quiet openings to decisive tactical breakthroughs.',
      quote: "Strategy is knowing what to do when there is nothing to do.",
      avatarIcon: Icons.military_tech_rounded,
      avatarGradient: [Color(0xFFFFD54F), Color(0xFFFF6F00)],
      styleTags: ['Masterful', 'Versatile', 'Ruthless'],
      engineType: BotType.stockfish,
      searchDepth: 9,
      blunderRate: 0.0,
      openingStyle: 'Ruy Lopez',
      dialogue: BotDialogue(
        greeting: "Let us enjoy a high-level battle.",
        onPlayerBlunder: ["A critical slip. The initiative swings completely."],
        onGoodMove: ["Masterful candidate move."],
        onWin: "A harmonious victory. Well played.",
        onLoss: "Outstanding performance! That was club champion level.",
      ),
    ),
    BotProfile(
      id: 'bot_dmitri',
      name: 'Dmitri',
      elo: 1850,
      tier: BotTier.advanced,
      bio: 'Dmitri is known for terrifying kingside attacks and rook lifts. If you let his h-pawn march, your king is doomed.',
      quote: "Your king looks lonely over there. Mind if I pay a visit?",
      avatarIcon: Icons.sports_martial_arts_rounded,
      avatarGradient: [Color(0xFFE57373), Color(0xFFB71C1C)],
      styleTags: ['Aggressive', 'Mating Attacks', 'Fierce'],
      engineType: BotType.stockfish,
      searchDepth: 11,
      blunderRate: 0.0,
      openingStyle: 'King\'s Indian',
      dialogue: BotDialogue(
        greeting: "All artillery trained on your king. Let the storm begin!",
        onPlayerBlunder: ["Mate is looming. Can you feel the heat?"],
        onGoodMove: ["Tough shield. But I will reload."],
        onWin: "Checkmate delivers the final blow!",
        onLoss: "You weathered the storm and counter-struck. Magnificent!",
      ),
    ),
    BotProfile(
      id: 'bot_kavya',
      name: 'Kavya',
      elo: 2000,
      tier: BotTier.advanced,
      bio: 'Expert level candidate. Kavya understands subtle space advantages and punishes even tiny positional inaccuracies.',
      quote: "One misplaced pawn creates a weakness that lasts the entire game.",
      avatarIcon: Icons.diamond_rounded,
      avatarGradient: [Color(0xFFFFCA28), Color(0xFFF57F17)],
      styleTags: ['Expert', 'Deep Positional', 'Precise'],
      engineType: BotType.stockfish,
      searchDepth: 13,
      blunderRate: 0.0,
      openingStyle: 'English Opening',
      dialogue: BotDialogue(
        greeting: "Welcome to the expert tier. Every tempo matters.",
        onPlayerBlunder: ["That inaccuracy will be exploited across the board."],
        onGoodMove: ["Deep positional understanding."],
        onWin: "Clinical conversion. Thank you for the match.",
        onLoss: "Spectacular! You outplayed an expert player.",
      ),
    ),
    BotProfile(
      id: 'bot_leon',
      name: 'Leon',
      elo: 2150,
      tier: BotTier.advanced,
      bio: 'Candidate Master strength. Leon plays with surgical precision and converts small 0.5-pawn advantages into clinical wins.',
      quote: "Chess is not art; it is pure geometry and precision.",
      avatarIcon: Icons.star_rounded,
      avatarGradient: [Color(0xFFFFF176), Color(0xFFFBC02D)],
      styleTags: ['Candidate Master', 'Surgical', 'Relentless'],
      engineType: BotType.stockfish,
      searchDepth: 15,
      blunderRate: 0.0,
      openingStyle: 'Nimzo-Indian',
      dialogue: BotDialogue(
        greeting: "Greetings. Let us see if your endgame holds up.",
        onPlayerBlunder: ["A micro-weakness that determines the outcome."],
        onGoodMove: ["Very strong calculation. Exact move."],
        onWin: "Surgical conversion completed.",
        onLoss: "You played CM caliber chess. Respect.",
      ),
    ),

    // -------------------------------------------------------------
    // Tier 4: Master / Legendary (2300 - 2800+ ELO)
    // -------------------------------------------------------------
    BotProfile(
      id: 'bot_ivan',
      name: 'Grandmaster Ivan',
      elo: 2300,
      tier: BotTier.master,
      bio: 'A seasoned Grandmaster who has analyzed tens of thousands of games. Flawless opening preparation and deep tactical insight.',
      quote: "Welcome to the real arena. Let us see what you have learned.",
      avatarIcon: Icons.emoji_events_rounded,
      avatarGradient: [Color(0xFF00E5FF), Color(0xFF0091EA)],
      styleTags: ['Grandmaster', 'Universal', 'Elite'],
      engineType: BotType.stockfish,
      searchDepth: 17,
      blunderRate: 0.0,
      openingStyle: 'Catalan',
      dialogue: BotDialogue(
        greeting: "Welcome, challenger. Show me your deep preparation.",
        onPlayerBlunder: ["The grandmaster standard does not forgive that."],
        onGoodMove: ["A move worthy of a titled player."],
        onWin: "Experience prevails. Keep studying.",
        onLoss: "Astounding! You have defeated a Grandmaster!",
      ),
    ),
    BotProfile(
      id: 'bot_oracle',
      name: 'The Oracle',
      elo: 2450,
      tier: BotTier.master,
      bio: 'A hyper-calculated persona. The Oracle foresees combinations 10 plies deep and executes lethal counter-punches.',
      quote: "I already know how this game ends. Do you?",
      avatarIcon: Icons.visibility_rounded,
      avatarGradient: [Color(0xFF7C4DFF), Color(0xFF311B92)],
      styleTags: ['Super GM', 'Prophetic', 'Deep Vision'],
      engineType: BotType.stockfish,
      searchDepth: 19,
      blunderRate: 0.0,
      openingStyle: 'French Defense',
      dialogue: BotDialogue(
        greeting: "The branches of time are open. Which path will you choose?",
        onPlayerBlunder: ["Your timeline collapses with that move."],
        onGoodMove: ["You found the singular path of resistance."],
        onWin: "The prophecy is fulfilled.",
        onLoss: "Incredible... you rewrote the predicted outcome.",
      ),
    ),
    BotProfile(
      id: 'bot_deep_iron',
      name: 'Deep Iron',
      elo: 2600,
      tier: BotTier.master,
      bio: 'An offline titanium machine. Plays near-perfect engine lines and gives zero counterplay.',
      quote: "Human error is inevitable. I will wait for yours.",
      avatarIcon: Icons.memory_rounded,
      avatarGradient: [Color(0xFF00B0FF), Color(0xFF1A237E)],
      styleTags: ['Legendary', 'Engine Precision', 'Cold'],
      engineType: BotType.stockfish,
      searchDepth: 21,
      blunderRate: 0.0,
      openingStyle: 'All Openings',
      dialogue: BotDialogue(
        greeting: "System initialized. Depth calculating. Move when ready.",
        onPlayerBlunder: ["Suboptimal evaluation detected."],
        onGoodMove: ["Evaluation neutral. Engine parity maintained."],
        onWin: "Mathematical certainty achieved.",
        onLoss: "Anomaly detected: Human outmaneuvered silicon.",
      ),
    ),
    BotProfile(
      id: 'bot_stockfish_max',
      name: 'Stockfish Max',
      elo: 2850,
      tier: BotTier.master,
      bio: 'Full unconstrained Stockfish engine with NNUE evaluation. The ultimate offline chess entity.',
      quote: "...",
      avatarIcon: Icons.smart_toy_rounded,
      avatarGradient: [Color(0xFFE040FB), Color(0xFF4A148C)],
      styleTags: ['Unbeatable', 'Maximum Depth', 'NNUE'],
      engineType: BotType.stockfish,
      searchDepth: 24,
      blunderRate: 0.0,
      openingStyle: 'Optimal',
      dialogue: BotDialogue(
        greeting: "NNUE evaluation online. Processing...",
        onPlayerBlunder: ["Delta CPL +350."],
        onGoodMove: ["Depth 24 confirmed best move."],
        onWin: "+#M0. Game over.",
        onLoss: "Error: Impossible condition reached. You are superhuman.",
      ),
    ),
  ];

  static BotProfile getById(String id) {
    return allBots.firstWhere(
      (b) => b.id == id,
      orElse: () => allBots.first,
    );
  }

  static List<BotProfile> getByTier(BotTier tier) {
    return allBots.where((b) => b.tier == tier).toList();
  }

  static BotProfile getClosestToElo(int targetElo) {
    return allBots.reduce((prev, curr) {
      return (curr.elo - targetElo).abs() < (prev.elo - targetElo).abs()
          ? curr
          : prev;
    });
  }
}
