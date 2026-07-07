import re

with open('lib/screens/analysis/analysis_menu_screen.dart', 'r') as f:
    content = f.read()

# Fix unused imports
content = content.replace("import 'package:chess_master/models/game_model.dart';\n", "")
content = content.replace("import 'package:chess/chess.dart' as chess;\n", "")

# Fix undefined getter 'board_outlined' -> 'grid_on_outlined'
content = content.replace("icon: Icons.board_outlined,", "icon: Icons.grid_on_outlined,")

# Fix startingFen -> initialFen
content = content.replace("startingFen: activeGame.startingFen,", "startingFen: activeGame.initialFen,")

# Fix withOpacity
content = content.replace("withOpacity(0.5)", "withValues(alpha: 0.5)")
content = content.replace("withOpacity(0.15)", "withValues(alpha: 0.15)")

with open('lib/screens/analysis/analysis_menu_screen.dart', 'w') as f:
    f.write(content)
