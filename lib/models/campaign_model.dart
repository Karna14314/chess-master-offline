import 'package:chess_master/models/bot_profile.dart';

/// Represents a level in the 12-Level Master Campaign
class CampaignLevel {
  final int levelNumber;
  final String botId;
  final String title;
  final String description;
  final int targetElo;
  final String conditionDescription;
  final String rewardBadge;
  final int requiredStarsToUnlock;

  const CampaignLevel({
    required this.levelNumber,
    required this.botId,
    required this.title,
    required this.description,
    required this.targetElo,
    required this.conditionDescription,
    required this.rewardBadge,
    this.requiredStarsToUnlock = 0,
  });

  BotProfile get bot => BotProfile.getById(botId);

  // 12-Level sequential challenge ladder
  static const List<CampaignLevel> allLevels = [
    CampaignLevel(
      levelNumber: 1,
      botId: 'bot_rusty',
      title: 'First Contact',
      description: 'Defeat Rusty to prove your fundamental chess mechanics.',
      targetElo: 400,
      conditionDescription: 'Win the match',
      rewardBadge: 'Bronze Pawn ♟️',
      requiredStarsToUnlock: 0,
    ),
    CampaignLevel(
      levelNumber: 2,
      botId: 'bot_pete',
      title: 'The Pawn Wall',
      description: 'Pete will swarm the board with pawns. Breakthrough his structure!',
      targetElo: 500,
      conditionDescription: 'Win the match',
      rewardBadge: 'Pawn Breaker 🔨',
      requiredStarsToUnlock: 1,
    ),
    CampaignLevel(
      levelNumber: 3,
      botId: 'bot_oliver',
      title: 'Casual Skirmish',
      description: 'Oliver loves giving check. Stay calm, deflect checks, and strike.',
      targetElo: 650,
      conditionDescription: 'Win the match',
      rewardBadge: 'Shield Bearer 🛡️',
      requiredStarsToUnlock: 2,
    ),
    CampaignLevel(
      levelNumber: 4,
      botId: 'bot_clara',
      title: 'Siege the Fortress',
      description: 'Clara plays ultra-cautious. Win as Black against her defensive setup.',
      targetElo: 750,
      conditionDescription: 'Win as Black',
      rewardBadge: 'Fortress Crusher 🏰',
      requiredStarsToUnlock: 4,
    ),
    CampaignLevel(
      levelNumber: 5,
      botId: 'bot_aaron',
      title: 'Tame the Storm',
      description: 'Survive Aaron\'s aggressive early queen attacks and counter-attack.',
      targetElo: 850,
      conditionDescription: 'Win without early queen loss',
      rewardBadge: 'Storm Tamer ⚡',
      requiredStarsToUnlock: 6,
    ),
    CampaignLevel(
      levelNumber: 6,
      botId: 'bot_timmy',
      title: 'Tactical Trial',
      description: 'Timmy knows basic forks. Neutralize his knights to advance.',
      targetElo: 950,
      conditionDescription: 'Win the match',
      rewardBadge: 'Silver Knight ♞',
      requiredStarsToUnlock: 8,
    ),
    CampaignLevel(
      levelNumber: 7,
      botId: 'bot_maya',
      title: 'Classical Duel',
      description: 'Test your fundamentals against Maya\'s disciplined center play.',
      targetElo: 1050,
      conditionDescription: 'Win the match',
      rewardBadge: 'Bishop Tactician ♝',
      requiredStarsToUnlock: 11,
    ),
    CampaignLevel(
      levelNumber: 8,
      botId: 'bot_viktor',
      title: 'Gambiteer\'s Gauntlet',
      description: 'Viktor will sacrifice material for initiative. Punish his over-aggression.',
      targetElo: 1150,
      conditionDescription: 'Win the match',
      rewardBadge: 'Gambit Master ⚔️',
      requiredStarsToUnlock: 14,
    ),
    CampaignLevel(
      levelNumber: 9,
      botId: 'bot_elena',
      title: 'Positional Mastery',
      description: 'Elena gives no easy tactical targets. Out-maneuver her pieces.',
      targetElo: 1250,
      conditionDescription: 'Win the match',
      rewardBadge: 'Golden Rook ♜',
      requiredStarsToUnlock: 17,
    ),
    CampaignLevel(
      levelNumber: 10,
      botId: 'bot_felix',
      title: 'Stockfish Ascent',
      description: 'Face the first native Stockfish tier. Accurate calculation is required.',
      targetElo: 1350,
      conditionDescription: 'Win the match',
      rewardBadge: 'Calculation Ace 🎯',
      requiredStarsToUnlock: 20,
    ),
    CampaignLevel(
      levelNumber: 11,
      botId: 'bot_marcus',
      title: 'The Iron Gate',
      description: 'Marcus has rock-solid defense. Break him down in a patient endgame.',
      targetElo: 1550,
      conditionDescription: 'Win without takebacks',
      rewardBadge: 'Iron Champion 👑',
      requiredStarsToUnlock: 24,
    ),
    CampaignLevel(
      levelNumber: 12,
      botId: 'bot_ivan',
      title: 'Grandmaster Finale',
      description: 'The ultimate campaign trial: Defeat Grandmaster Ivan in classical battle.',
      targetElo: 2300,
      conditionDescription: 'Defeat Grandmaster Ivan',
      rewardBadge: 'Offline Grandmaster 🏆',
      requiredStarsToUnlock: 28,
    ),
  ];
}
