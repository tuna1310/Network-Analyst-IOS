import json
import re
import os

xcstrings_path = 'NetworkAnalyst/Resources/Localizable.xcstrings'
with open(xcstrings_path, 'r', encoding='utf-8') as f:
    data = json.load(f)
keys = set(data.get('strings', {}).keys())

called_keys = []
pattern1 = re.compile(r'String\(localized:\s*"([^"]+)"')
pattern2 = re.compile(r'LocalizedStringKey\("([^"]+)"\)')
pattern_text = re.compile(r'Text\("([^"]+)"\)')

for root, dirs, files in os.walk('NetworkAnalyst'):
    for f in files:
        if f.endswith('.swift'):
            filepath = os.path.join(root, f)
            with open(filepath, 'r', encoding='utf-8') as sf:
                for line_no, line in enumerate(sf, 1):
                    for m in pattern1.finditer(line):
                        called_keys.append((m.group(1), filepath, line_no))
                    for m in pattern2.finditer(line):
                        called_keys.append((m.group(1), filepath, line_no))
                    for m in pattern_text.finditer(line):
                        # check if it looks like a localization key (contains dot)
                        val = m.group(1)
                        if '.' in val and ' ' not in val:
                            called_keys.append((val, filepath, line_no))

missing = []
for k, path, line_no in called_keys:
    if k not in keys:
        missing.append((k, path, line_no))

print(f"Total keys in xcstrings: {len(keys)}")
print(f"Total localized calls in code: {len(called_keys)}")
print(f"Missing keys: {len(missing)}")
for k, path, line_no in missing:
    print(f"  - Line {line_no} in {path}: '{k}'")

# Also check NetworkCore
print("\nChecking NetworkCore:")
nc_called = []
for root, dirs, files in os.walk('NetworkCore'):
    for f in files:
        if f.endswith('.swift'):
            filepath = os.path.join(root, f)
            with open(filepath, 'r', encoding='utf-8') as sf:
                for line_no, line in enumerate(sf, 1):
                    for m in pattern1.finditer(line):
                        nc_called.append((m.group(1), filepath, line_no))
print(f"NetworkCore localized calls: {len(nc_called)}")
for k, path, line_no in nc_called:
    print(f"  - Line {line_no} in {path}: '{k}'")
