import os, re, sys, json, collections

ROOTS = [
    "website",
    "DineCircle-master/lib",
    "DineCircle-master/server/src",
    "partnerapp/lib",
    "partnerapp/tool",
    "DineCircle-master/tool",
]
EXTS = {".dart", ".ts", ".js", ".html", ".py", ".css", ".yaml", ".yml"}
DASH = "\u2014"

ctx = collections.Counter()
files = []
for root in ROOTS:
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in {"node_modules", "build", ".dart_tool", "dist"}]
        for fn in filenames:
            if os.path.splitext(fn)[1] not in EXTS:
                continue
            p = os.path.join(dirpath, fn)
            files.append(p)
            text = open(p, encoding="utf-8").read()
            for m in re.finditer(re.escape(DASH), text):
                s = max(0, m.start() - 70)
                e = min(len(text), m.end() + 70)
                frag = text[s:e].replace("\n", "\\n")
                ctx[frag] += 1

print("FILES:", len(files), "OCCURRENCES:", sum(ctx.values()), "DISTINCT:", len(ctx))
with open(".tmp_emdash/contexts.txt", "w", encoding="utf-8") as f:
    for frag, n in ctx.most_common():
        f.write(f"[{n}] {frag}\n")
