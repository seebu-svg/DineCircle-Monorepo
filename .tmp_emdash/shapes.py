import os, collections

ROOTS = ["website", "DineCircle-master/lib", "DineCircle-master/server/src",
         "partnerapp/lib", "partnerapp/tool", "DineCircle-master/tool"]
DASH = "\u2014"
shapes = collections.Counter()
examples = collections.defaultdict(list)

for root in ROOTS:
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in {"node_modules", "build", ".dart_tool", "dist"}]
        for fn in filenames:
            if os.path.splitext(fn)[1] not in {".dart", ".ts", ".js", ".html", ".py", ".sql", ".yaml", ".yml"}:
                continue
            p = os.path.join(dirpath, fn)
            text = open(p, encoding="utf-8").read()
            for i, ch in enumerate(text):
                if ch != DASH:
                    continue
                prev = text[i-1] if i else ""
                nxt = text[i+1] if i + 1 < len(text) else ""
                if prev == "\n":
                    shape = "dash-at-line-start"
                elif nxt == "\n":
                    shape = "dash-at-line-end"
                elif prev == " " and nxt == " ":
                    # look ahead to first nonspace
                    j = i + 1
                    while j < len(text) and text[j] == " ":
                        j += 1
                    c = text[j] if j < len(text) else ""
                    shape = " spaced-next-upper" if c.isupper() else (" spaced-next-lower" if c.islower() else " spaced-next-other:" + repr(c))
                elif prev == " ":
                    shape = " space-before-only"
                elif nxt == " ":
                    shape = " space-after-only"
                else:
                    shape = "no-spaces"
                shapes[shape] += 1
                if len(examples[shape]) < 4:
                    ls = text.rfind("\n", 0, i) + 1
                    le = text.find("\n", i)
                    examples[shape].append(f"{p}: {text[ls:le].strip()[:120]}")

for shape, n in shapes.most_common():
    print(f"{n:5d}  {shape}")
    for e in examples[shape]:
        print("        ", e)
