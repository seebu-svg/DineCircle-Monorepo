"""Heuristic pass: replace remaining em dashes (mostly in code comments and test names)."""
import os

ROOTS = ["website", "DineCircle-master/lib", "DineCircle-master/server/src",
         "partnerapp/lib", "partnerapp/tool", "DineCircle-master/tool",
         "partnerapp/test", "DineCircle-master/test"]
EXTS = {".dart", ".ts", ".js", ".html", ".py", ".sql"}
DASH = "\u2014"


def trim_space(out):
    if out and out[-1] == " ":
        out.pop()


def convert(text):
    out = []
    i = 0
    n = len(text)
    while i < n:
        ch = text[i]
        if ch != DASH:
            out.append(ch)
            i += 1
            continue
        line_start = text.rfind("\n", 0, i) + 1
        line_end = text.find("\n", i)
        if line_end == -1:
            line_end = n
        line = text[line_start:line_end]
        dashes_on_line = line.count(DASH)

        # dash ends its line: the sentence continues on the next line
        if text[i + 1:line_end].strip() == "":
            trim_space(out)
            out.append(",")
            i += 1
            while i < n and text[i] == " ":
                i += 1
            continue

        # dash opens a line: drop it and the following space
        if text[line_start:i].strip() == "":
            i += 1
            while i < n and text[i] == " ":
                i += 1
            continue

        # a paired dash is a parenthetical aside
        if dashes_on_line >= 2:
            trim_space(out)
            out.append(",")
            i += 1
            while i < n and text[i] == " ":
                i += 1
            continue

        j = i + 1
        while j < n and text[j] == " ":
            j += 1
        nxt = text[j] if j < n else ""
        trim_space(out)
        if nxt and nxt.islower():
            out.append(", ")
        elif not nxt:
            out.append(",")
        else:
            out.append(": ")
        i = j
    return "".join(out)


changed = 0
for root in ROOTS:
    if not os.path.isdir(root):
        continue
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in {"node_modules", "build", ".dart_tool", "dist"}]
        for fn in filenames:
            if os.path.splitext(fn)[1] not in EXTS:
                continue
            p = os.path.join(dirpath, fn)
            text = open(p, encoding="utf-8").read()
            if DASH not in text:
                continue
            new = convert(text)
            if new != text:
                open(p, "w", encoding="utf-8").write(new)
                changed += 1
print("files changed:", changed)
