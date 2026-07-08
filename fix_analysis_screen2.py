import re
with open('lib/screens/analysis/analysis_screen.dart', 'r') as f:
    content = f.read()

# Fix unused import
content = content.replace("import 'package:chess_master/models/analysis_model.dart';\n", "")
# Wait, actually let's just make sure MoveClassification is imported where it's used.
# It seems we need analysis_model.dart for `MoveClassification` in the navigation section (jump to mistake). Let's keep it and see. Oh wait, it said unused import... let's check where MoveClassification is defined. It's in analysis_model.dart or app_constants? Let's check `lib/models/analysis_model.dart`
