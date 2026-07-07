with open('lib/screens/analysis/analysis_screen.dart', 'r') as f:
    content = f.read()

# Fix unused _isAnalyzing
content = content.replace("bool _isAnalyzing = false;", "")
content = content.replace("setState(() => _isAnalyzing = true);", "")
content = content.replace("setState(() => _isAnalyzing = false);", "")

# Import MoveClassification
content = content.replace("import 'package:chess_master/models/analysis_model.dart';", "import 'package:chess_master/models/analysis_model.dart';\nimport 'package:chess_master/core/constants/app_constants.dart';")

with open('lib/screens/analysis/analysis_screen.dart', 'w') as f:
    f.write(content)
