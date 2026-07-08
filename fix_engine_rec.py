with open('lib/screens/analysis/widgets/engine_recommendations.dart', 'r') as f:
    content = f.read()

content = content.replace("final moveList = line.pv.split(' ');", "final moveList = line.sanMoves ?? line.moves;")

with open('lib/screens/analysis/widgets/engine_recommendations.dart', 'w') as f:
    f.write(content)
