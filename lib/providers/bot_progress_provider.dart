import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chess_master/core/constants/app_constants.dart';
import 'package:chess_master/models/bot_profile.dart';
import 'package:chess_master/models/campaign_model.dart';

class BotProgressState {
  final Map<String, BotStats> botStats;
  final int campaignUnlockedLevel;
  final Map<int, int> campaignStars; // level -> stars (1-3)

  const BotProgressState({
    this.botStats = const {},
    this.campaignUnlockedLevel = 1,
    this.campaignStars = const {},
  });

  /// Total crowns/stars earned across all bots
  int get totalBotStars {
    int sum = 0;
    for (final stats in botStats.values) {
      sum += stats.bestStars;
    }
    return sum;
  }

  /// Total stars earned in campaign
  int get totalCampaignStars {
    int sum = 0;
    for (final stars in campaignStars.values) {
      sum += stars;
    }
    return sum;
  }

  BotStats getStatsFor(String botId) {
    return botStats[botId] ?? const BotStats();
  }

  bool isCampaignLevelUnlocked(int levelNumber) {
    if (levelNumber <= 1) return true;
    final levelConfig = CampaignLevel.allLevels.firstWhere(
      (lvl) => lvl.levelNumber == levelNumber,
      orElse: () => CampaignLevel.allLevels.first,
    );
    // Unlocked either if sequential progression reached or enough stars earned
    return levelNumber <= campaignUnlockedLevel ||
        totalCampaignStars >= levelConfig.requiredStarsToUnlock;
  }

  BotProgressState copyWith({
    Map<String, BotStats>? botStats,
    int? campaignUnlockedLevel,
    Map<int, int>? campaignStars,
  }) {
    return BotProgressState(
      botStats: botStats ?? this.botStats,
      campaignUnlockedLevel:
          campaignUnlockedLevel ?? this.campaignUnlockedLevel,
      campaignStars: campaignStars ?? this.campaignStars,
    );
  }
}

class BotProgressNotifier extends StateNotifier<BotProgressState> {
  BotProgressNotifier() : super(const BotProgressState());

  static const String _keyBotStats = 'chess_bot_stats_v1';
  static const String _keyCampaignLevel = 'chess_campaign_level_v1';
  static const String _keyCampaignStars = 'chess_campaign_stars_v1';

  Future<void> loadProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Load Bot Stats
      final statsJson = prefs.getString(_keyBotStats);
      final Map<String, BotStats> loadedStats = {};
      if (statsJson != null) {
        final decoded = jsonDecode(statsJson) as Map<String, dynamic>;
        decoded.forEach((key, value) {
          loadedStats[key] = BotStats.fromJson(value as Map<String, dynamic>);
        });
      }

      // 2. Load Campaign Unlocked Level
      final unlockedLevel = prefs.getInt(_keyCampaignLevel) ?? 1;

      // 3. Load Campaign Stars
      final starsJson = prefs.getString(_keyCampaignStars);
      final Map<int, int> loadedStars = {};
      if (starsJson != null) {
        final decoded = jsonDecode(starsJson) as Map<String, dynamic>;
        decoded.forEach((key, value) {
          loadedStars[int.parse(key)] = value as int;
        });
      }

      state = state.copyWith(
        botStats: loadedStats,
        campaignUnlockedLevel: unlockedLevel,
        campaignStars: loadedStars,
      );
    } catch (e) {
      debugPrint('Failed to load bot progress: $e');
    }
  }

  /// Record outcome of a bot match
  Future<void> recordBotMatch({
    required String botId,
    required GameResult result,
    required bool isPlayerWhite,
    required bool usedTakebacks,
    required int hintsUsed,
  }) async {
    final current = state.getStatsFor(botId);
    final isWin =
        (isPlayerWhite && result == GameResult.whiteWins) ||
        (!isPlayerWhite && result == GameResult.blackWins);
    final isDraw = result == GameResult.draw;
    final isLoss = !isWin && !isDraw;

    int earnedStars = 0;
    if (isWin) {
      if (!isPlayerWhite && !usedTakebacks && hintsUsed == 0) {
        earnedStars = 3; // Beat as black without assists
      } else if (!usedTakebacks && hintsUsed == 0) {
        earnedStars = 2; // Beat without assists
      } else {
        earnedStars = 1; // Beat with assists
      }
    }

    final newStats = current.copyWith(
      wins: current.wins + (isWin ? 1 : 0),
      draws: current.draws + (isDraw ? 1 : 0),
      losses: current.losses + (isLoss ? 1 : 0),
      bestStars: earnedStars > current.bestStars ? earnedStars : current.bestStars,
    );

    final updatedMap = Map<String, BotStats>.from(state.botStats);
    updatedMap[botId] = newStats;
    state = state.copyWith(botStats: updatedMap);

    await _saveBotStats();
  }

  /// Record outcome of a campaign level
  Future<void> recordCampaignMatch({
    required int levelNumber,
    required GameResult result,
    required bool isPlayerWhite,
    required bool usedTakebacks,
    required int hintsUsed,
  }) async {
    final isWin =
        (isPlayerWhite && result == GameResult.whiteWins) ||
        (!isPlayerWhite && result == GameResult.blackWins);

    if (!isWin) return;

    int earnedStars = 1;
    if (!usedTakebacks && hintsUsed == 0) {
      earnedStars = !isPlayerWhite ? 3 : 2;
    }

    final updatedStars = Map<int, int>.from(state.campaignStars);
    final prevStars = updatedStars[levelNumber] ?? 0;
    if (earnedStars > prevStars) {
      updatedStars[levelNumber] = earnedStars;
    }

    int nextLevel = state.campaignUnlockedLevel;
    if (levelNumber >= state.campaignUnlockedLevel && nextLevel < 12) {
      nextLevel = levelNumber + 1;
    }

    state = state.copyWith(
      campaignStars: updatedStars,
      campaignUnlockedLevel: nextLevel,
    );

    await _saveCampaignData();
  }

  Future<void> _saveBotStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final serialized = state.botStats.map(
        (key, value) => MapEntry(key, value.toJson()),
      );
      await prefs.setString(_keyBotStats, jsonEncode(serialized));
    } catch (e) {
      debugPrint('Failed to save bot stats: $e');
    }
  }

  Future<void> _saveCampaignData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyCampaignLevel, state.campaignUnlockedLevel);

      final starsSerialized = state.campaignStars.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      await prefs.setString(_keyCampaignStars, jsonEncode(starsSerialized));
    } catch (e) {
      debugPrint('Failed to save campaign data: $e');
    }
  }

  /// Debug/testing: unlock every campaign level (keeps earned stars).
  Future<void> unlockAllCampaign() async {
    state = state.copyWith(campaignUnlockedLevel: 12);
    await _saveCampaignData();
  }

  /// Debug/testing: wipe bot stats + campaign progress.
  Future<void> resetAllProgress() async {
    state = const BotProgressState();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyBotStats);
      await prefs.remove(_keyCampaignLevel);
      await prefs.remove(_keyCampaignStars);
    } catch (e) {
      debugPrint('Failed to reset bot progress: $e');
    }
  }
}

final botProgressProvider =
    StateNotifierProvider<BotProgressNotifier, BotProgressState>((ref) {
      final notifier = BotProgressNotifier();
      notifier.loadProgress();
      return notifier;
    });
