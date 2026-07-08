with open('lib/screens/analysis/analysis_menu_screen.dart', 'r') as f:
    content = f.read()

# GameState does not have initialFen or startingFen natively exposed,
# but it has `board.fen` ? wait. Let's look at GameState fen or let's just pass null.
# Since analysis screen handles null startingFen, we can just pass null for activeGame or activeGame.moveHistory.first.fen?
# Actually in GameState, we can check if there's a starting fen. Let's just use 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1'
content = content.replace("startingFen: activeGame.initialFen,", "startingFen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',")

with open('lib/screens/analysis/analysis_menu_screen.dart', 'w') as f:
    f.write(content)
