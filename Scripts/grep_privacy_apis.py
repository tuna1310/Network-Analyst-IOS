import os
import re

KEYWORDS = [
    "mach_absolute_time",
    "systemUptime",
    "ProcessInfo",
    "clock_gettime",
    "CFAbsoluteTime",
    "stat",
    "fstat",
    "NSFileCreationDate",
    "ModificationDate",
    "modificationDate",
    "volumeAvailableCapacity",
    "UserDefaults",
    "@AppStorage",
]

TARGET_DIRS = ["NetworkAnalyst", "NetworkCore"]
EXTENSIONS = [".swift", ".m", ".h", ".c", ".cpp"]

def run_grep():
    results = {kw: [] for kw in KEYWORDS}
    for tdir in TARGET_DIRS:
        if not os.path.exists(tdir):
            continue
        for root, dirs, files in os.walk(tdir):
            for file in files:
                if any(file.endswith(ext) for ext in EXTENSIONS):
                    filepath = os.path.join(root, file)
                    rel_path = os.path.relpath(filepath).replace("\\", "/")
                    with open(filepath, "r", encoding="utf-8", errors="ignore") as f:
                        for line_no, line in enumerate(f, 1):
                            line_content = line.strip()
                            for kw in KEYWORDS:
                                # regex to match keyword as identifier or specific token
                                if kw == "stat":
                                    # match whole word 'stat' but not status or state
                                    pattern = r"\bstat\b"
                                    if re.search(pattern, line):
                                        results[kw].append((rel_path, line_no, line_content))
                                elif kw == "fstat":
                                    pattern = r"\bfstat\b"
                                    if re.search(pattern, line):
                                        results[kw].append((rel_path, line_no, line_content))
                                else:
                                    if kw in line:
                                        results[kw].append((rel_path, line_no, line_content))
    return results

if __name__ == "__main__":
    res = run_grep()
    for kw, hits in res.items():
        print(f"=== KEYWORD: {kw} (Hits: {len(hits)}) ===")
        for path, line_no, content in hits:
            print(f"  {path}:{line_no}: {content}")
        print()
