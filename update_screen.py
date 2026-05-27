with open('lib/screens/position_setup/position_setup_screen.dart', 'r') as f:
    content = f.read()

import re

old_code = """      for (int rank = 0; rank < 8; rank++) {
        int file = 0;
        for (final char in ranks[rank].split('')) {
          final num = int.tryParse(char);
          if (num != null) {
            file += num;
          } else {
            if (file < 8) {
              newBoard[rank][file] = char;
              file++;
            }
          }
        }
      }"""

new_code = """      for (int rank = 0; rank < 8; rank++) {
        int file = 0;
        final rankStr = ranks[rank];
        for (int i = 0; i < rankStr.length; i++) {
          final codeUnit = rankStr.codeUnitAt(i);
          // '0' is 48, '9' is 57
          if (codeUnit >= 48 && codeUnit <= 57) {
            file += (codeUnit - 48);
          } else {
            if (file < 8) {
              newBoard[rank][file] = rankStr[i];
              file++;
            }
          }
        }
      }"""

content = content.replace(old_code, new_code)

with open('lib/screens/position_setup/position_setup_screen.dart', 'w') as f:
    f.write(content)
