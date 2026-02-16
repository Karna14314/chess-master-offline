# Critical Issues and Fixes for ChessMaster Offline

## Issue 1: Pieces Not Showing (CRITICAL)

### Problem
Chess pieces are not rendering on the board in any screen (game, puzzles, analysis).

### Root Cause Analysis
The SVG files exist in the correct locations, but there may be issues with:
1. SVG file format/content
2. flutter_svg package not loading properly
3. Asset path resolution

### Immediate Fix Steps

1. **Verify SVG files are valid**:
   - Open one of the SVG files (e.g., `assets/pieces/traditional/wK.svg`)
   - Ensure it contains valid SVG XML

2. **Test with fallback Unicode pieces**:
   - The ChessPiece widget has a fallback to Unicode symbols
   - If pieces show as Unicode but not SVG, it's an SVG loading issue

3. **Check flutter_svg version**:
   - Current: `flutter_svg: ^2.0.17`
   - May need to run `flutter pub get` or `flutter clean`

4. **Add debug logging**:
   ```dart
   // In chess_piece.dart _buildPiece()
   debugPrint('Loading piece: $piece from $assetPath');
   ```

### Quick Test
Run this command to verify assets are bundled:
```bash
flutter build apk --debug
# Then check the APK contents for assets/pieces/
```

## Issue 2: Bot Not Making Moves

### Problem
The bot doesn't make moves after player moves.

### Root Cause
Stockfish engine may not be initializing properly or timing out.

### Fix Steps

1. **Add initialization check in game_screen.dart**:
   ```dart
   @override
   void initState() {
     super.initState();
     WidgetsBinding.instance.addPostFrameCallback((_) async {
       // Ensure engine is initialized
       final engineNotifier = ref.read(engineProvider.notifier);
       await engineNotifier.initialize();
       
       _initializeTimer();
       _checkBotMove();
     });
   }
   ```

2. **Add error handling**:
   - Check console for Stockfish errors
   - Verify native library is included in build

3. **Test with simple position**:
   - Start a new game
   - Make one move
   - Check if bot responds within 5 seconds

## Issue 3: Analysis Not Working

### Problem
Analysis screen doesn't show move classifications or evaluation changes.

### Likely Causes
1. Engine not analyzing positions
2. Move classification logic not being called
3. Evaluation data not being passed correctly

### Fix
The analysis provider needs to be properly initialized and connected to the engine.

## Issue 4: Database "No Table Exists" Error

### Status
✅ FIXED in database_service.dart

The `_onUpgrade` method now properly checks for table existence and creates them if missing.

## Issue 5: Sound Effects Not Working

### Status
✅ PARTIALLY FIXED

- Added sound assets directory to pubspec.yaml
- Added sound playback in analysis screen
- Need to add actual MP3 files to `assets/sounds/`

### Required Sound Files
Create or download these files:
- move.mp3
- capture.mp3
- check.mp3
- game_end.mp3
- game_start.mp3
- low_time.mp3

Free sources:
- Lichess sounds (CC0): https://github.com/lichess-org/lila/tree/master/public/sound
- Freesound.org

## Issue 6: Notation Toggle

### Status
✅ FIXED

Added `showNotation` setting that can be toggled from the game screen.

## Issue 7: Player Labels in Local Multiplayer

### Status
✅ FIXED

Game screen now shows "Player 1" and "Player 2" when in local multiplayer mode.

## Testing Checklist

### Before Release
- [ ] Verify pieces render on game screen
- [ ] Verify pieces render on puzzle screen
- [ ] Verify pieces render on analysis screen
- [ ] Test bot makes moves (all difficulty levels)
- [ ] Test puzzle database loads
- [ ] Test analysis shows move classifications
- [ ] Test sound effects play (if files added)
- [ ] Test notation toggle works
- [ ] Test local multiplayer labels
- [ ] Test resume game functionality

### Debug Commands
```bash
# Clean build
flutter clean
flutter pub get

# Run with verbose logging
flutter run --verbose

# Check for asset issues
flutter build apk --debug
unzip -l build/app/outputs/flutter-apk/app-debug.apk | grep assets/pieces

# Check for native library
unzip -l build/app/outputs/flutter-apk/app-debug.apk | grep libstockfish
```

## Next Steps

1. **Immediate Priority**: Fix piece rendering
   - This is blocking all gameplay
   - Test SVG loading
   - Add debug logs

2. **High Priority**: Fix bot moves
   - Verify Stockfish initialization
   - Add timeout handling
   - Test with different positions

3. **Medium Priority**: Complete sound assets
   - Add MP3 files
   - Test audio playback

4. **Low Priority**: Polish
   - Analysis improvements
   - UI refinements
