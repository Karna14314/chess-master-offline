import os
import glob

def fix_withopacity(path):
    for root, dirs, files in os.walk(path):
        for file in files:
            if file.endswith(".dart"):
                filepath = os.path.join(root, file)
                with open(filepath, "r") as f:
                    content = f.read()

                new_content = content.replace("withOpacity(", "withValues(alpha: ")
                if new_content != content:
                    with open(filepath, "w") as f:
                        f.write(new_content)

fix_withopacity("lib")
