import json

path = 'NetworkAnalyst/Resources/Localizable.xcstrings'
with open(path, 'r', encoding='utf-8') as f:
    d = json.load(f)

missing_en = []
missing_vi = []

for k, val in d.get('strings', {}).items():
    locs = val.get('localizations', {})
    en_val = locs.get('en', {}).get('stringUnit', {}).get('value', '').strip()
    vi_val = locs.get('vi', {}).get('stringUnit', {}).get('value', '').strip()
    if not en_val:
        missing_en.append(k)
    if not vi_val:
        missing_vi.append(k)

print(f"Total keys in Localizable.xcstrings: {len(d.get('strings', {}))}")
print(f"Keys missing EN: {len(missing_en)}")
if missing_en:
    print("Missing EN keys:", missing_en[:10])
print(f"Keys missing VI: {len(missing_vi)}")
if missing_vi:
    print("Missing VI keys:", missing_vi[:10])
