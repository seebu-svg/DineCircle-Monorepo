import os, re, glob, sys

root = os.path.dirname(os.path.abspath(__file__))
bad = []
broken_ids = []
for path in glob.glob(os.path.join(root, "**", "*.html"), recursive=True):
    rel = os.path.relpath(path, root)
    html = open(path, encoding="utf-8").read()
    folder = os.path.dirname(rel)
    ids = set(re.findall(r'id="([^"]+)"', html))
    for raw in re.findall(r'(?:href|src)="([^"]+)"', html):
        if raw.startswith(("http://", "https://", "mailto:", "tel:", "data:", "javascript:")):
            continue
        target, _, frag = raw.partition("#")
        target = target.split("?")[0]
        if not target:
            if frag and frag not in ids:
                broken_ids.append((rel, raw))
            continue
        resolved = os.path.normpath(os.path.join(root, folder, target))
        if not os.path.exists(resolved):
            bad.append((rel, raw))
        elif frag and resolved.endswith(".html"):
            other = set(re.findall(r'id="([^"]+)"', open(resolved, encoding="utf-8").read()))
            if frag not in other:
                broken_ids.append((rel, raw))

print("broken files:", len(bad))
for item in sorted(set(bad)):
    print("  FILE", item[0], "->", item[1])
print("broken anchors:", len(broken_ids))
for item in sorted(set(broken_ids)):
    print("  ANCHOR", item[0], "->", item[1])
sys.exit(1 if bad or broken_ids else 0)
