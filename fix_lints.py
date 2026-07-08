import re

with open('lib/screens/analysis/analysis_screen.dart', 'r') as f:
    content = f.read()

# Fix unused import in analysis_screen.dart
content = content.replace("import 'package:chess_master/models/analysis_model.dart';\n", "")

with open('lib/screens/analysis/analysis_screen.dart', 'w') as f:
    f.write(content)
