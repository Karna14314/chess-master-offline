import re

with open('docs/CHANGELOG.md', 'r') as f:
    content = f.read()

# Add the changelog entry
entry = """### 🧩 Puzzles
- **Promotion Dialog Fix**:
  - Fixed a critical bug where making a promotion move in puzzles using the tap-to-move interaction failed the puzzle instantly without showing the piece selection dialog.
  - Achieved full parity with drag-and-drop mechanics.

"""

content = content.replace("### 🛡️ Privacy, Diagnostics & Open Source Positioning", entry + "### 🛡️ Privacy, Diagnostics & Open Source Positioning")

with open('docs/CHANGELOG.md', 'w') as f:
    f.write(content)
