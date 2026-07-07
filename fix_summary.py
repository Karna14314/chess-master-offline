with open('lib/screens/analysis/widgets/game_accuracy_summary.dart', 'r') as f:
    content = f.read()

content = content.replace("import 'package:chess_master/models/analysis_model.dart';", "import 'package:chess_master/models/analysis_model.dart';\nimport 'package:chess_master/core/constants/app_constants.dart';")

with open('lib/screens/analysis/widgets/game_accuracy_summary.dart', 'w') as f:
    f.write(content)
