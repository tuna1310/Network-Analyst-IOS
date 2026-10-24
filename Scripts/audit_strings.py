import os
import re
import json

views_dir = 'NetworkAnalyst/Views'
viewmodels_dir = 'NetworkAnalyst/ViewModels'
services_dir = 'NetworkAnalyst/Services'

# Load existing xcstrings
with open('NetworkAnalyst/Resources/Localizable.xcstrings', 'r', encoding='utf-8') as f:
    xcstrings_data = json.load(f)
existing_keys = set(xcstrings_data.get('strings', {}).keys())

print(f"Total existing keys in Localizable.xcstrings: {len(existing_keys)}")

hardcoded_text = []

# Regex patterns to detect UI strings
text_regex = re.compile(r'Text\("([^"\n\\]+)"\)')
button_regex = re.compile(r'Button\("([^"\n\\]+)"')
label_regex = re.compile(r'Label\("([^"\n\\]+)"')
navtitle_regex = re.compile(r'navigationTitle\("([^"\n\\]+)"\)')

for search_dir in [views_dir, viewmodels_dir, services_dir]:
    for root, _, files in os.walk(search_dir):
        for file in files:
            if file.endswith('.swift'):
                full_path = os.path.join(root, file)
                with open(full_path, 'r', encoding='utf-8') as f:
                    for i, line in enumerate(f, 1):
                        for r, kind in [(text_regex, 'Text'), (button_regex, 'Button'), (label_regex, 'Label'), (navtitle_regex, 'NavigationTitle')]:
                            for match in r.findall(line):
                                if len(match) > 1 and not match.startswith('%') and not match.startswith('system.'):
                                    hardcoded_text.append((file, i, kind, match))

print(f"Total UI strings matched: {len(hardcoded_text)}")
unregistered = []
for file, line, kind, str_val in hardcoded_text:
    # Check if str_val exists as a key in Localizable.xcstrings
    if str_val not in existing_keys:
        unregistered.append((file, line, kind, str_val))

print(f"Strings NOT directly found in Localizable.xcstrings keys: {len(unregistered)}")
seen = set()
for file, line, kind, str_val in unregistered:
    if str_val not in seen:
        seen.add(str_val)
        print(f"[{file}:{line}] ({kind}) \"{str_val}\"")
