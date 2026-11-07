import os, re, collections

ROOTS = [
    "website",
    "DineCircle-master/lib",
    "DineCircle-master/server/src",
    "partnerapp/lib",
    "partnerapp/tool",
    "DineCircle-master/tool",
]
DASH = "\u2014"
STR_RE = re.compile(r"'''(?:.|\n)*?'''|\"\"\"(?:.|\n)*?\"\"\"|'(?:[^'\\\n]|\\.)*'|\"(?:[^\"\\\n]|\\.)*\"")
COMMENT_RE = re.compile(r"//[^\n]*|/\*(?:.|\n)*?\*/|#[^\n]*")

strings = collections.Counter()
comments = 0
other = []

for root in ROOTS:
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in {"node_modules", "build", ".dart_tool", "dist"}]
        for fn in filenames:
            if os.path.splitext(fn)[1] not in {".dart", ".ts", ".js", ".html", ".py"}:
                continue
            p = os.path.join(dirpath, fn)
            text = open(p, encoding="utf-8").read()
            if DASH not in text:
                continue
            covered = [False] * len(text)
            for m in STR_RE.finditer(text):
                if DASH in m.group(0):
                    strings[m.group(0)] += 1
                for i in range(m.start(), m.end()):
                    covered[i] = True
            cm = COMMENT_RE.finditer(text)
            for m in cm:
                if DASH in m.group(0):
                    comments += m.group(0).count(DASH)
                for i in range(m.start(), m.end()):
                    covered[i] = True
            for i, ch in enumerate(text):
                if ch == DASH and not covered[i]:
                    ls = text.rfind("\n", 0, i) + 1
                    le = text.find("\n", i)
                    other.append(f"{p}:{text.count(chr(10), 0, i)+1}: {text[ls:le]}")

print("distinct string literals with dash:", len(strings), "total", sum(strings.values()))
print("dash occurrences in comments:", comments)
print("dash occurrences outside strings/comments:", len(other))
with open(".tmp_emdash/strings.txt", "w", encoding="utf-8") as f:
    for lit, n in strings.most_common():
        f.write(f"[{n}] {lit}\n")
with open(".tmp_emdash/other.txt", "w", encoding="utf-8") as f:
    f.write("\n".join(other))
