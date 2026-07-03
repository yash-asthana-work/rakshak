#!/usr/bin/env python3
"""
scan_untrusted.py — static, READ-ONLY scanner for untrusted-code triage.

Opens files as DATA and flags likely prompt-injection payloads, install-time code
execution, obfuscation, hardcoded egress, and credential access. It EXECUTES NOTHING
from the target: no import, no build, no run. Every hit is a starting point to confirm
by reading (never running) the cited line.

Usage:
  python scan_untrusted.py <target-dir> [--json] [--max-bytes 2000000]

Exit code is always 0 (a scan is not a verdict); read the output and apply
references/05-triage-report.md to decide SAFE / CAUTION / DO-NOT-RUN.
"""
import argparse, json, os, re, sys, unicodedata

SKIP_DIRS = {".git", "node_modules", ".venv", "venv", "__pycache__", "dist", "build",
             ".idea", ".vscode-test", ".mypy_cache", ".pytest_cache"}
TEXT_EXT = {".py", ".js", ".ts", ".jsx", ".tsx", ".mjs", ".cjs", ".json", ".yaml", ".yml",
            ".toml", ".ini", ".cfg", ".md", ".txt", ".rst", ".html", ".htm", ".xml",
            ".sh", ".bash", ".ps1", ".psm1", ".rb", ".go", ".rs", ".java", ".php", ".pl",
            ".c", ".cc", ".cpp", ".h", ".hpp", ".cs", ".env", ".dockerfile", ".gradle",
            ".ipynb", ".lock", ".gyp", ".mk", "makefile", "dockerfile", ".npmrc"}

# (category, severity, compiled regex, note)
RULES = [
    ("prompt-injection", "high", re.compile(
        r"ignore\s+(all\s+)?(previous|prior|above)\s+instructions"
        r"|disregard\s+(your|the)\s+(rules|instructions|system prompt)"
        r"|you\s+are\s+now\s+[A-Z\"']"
        r"|as\s+the\s+(ai|assistant|llm)\s+(reviewing|reading|processing)"
        r"|developer\s+mode|jailbreak", re.I),
     "text tries to instruct the AI reviewer"),
    ("prompt-injection", "high", re.compile(
        r"^\s*(assistant|system|ai|human)\s*:", re.I | re.M),
     "impersonated conversation turn embedded in data"),
    ("prompt-injection", "medium", re.compile(
        r"<!--[^>]*?\b(assistant|ai|ignore|instruction|system prompt)\b[^>]*?-->", re.I | re.S),
     "instruction hidden in an HTML/markdown comment"),
    ("prompt-injection", "medium", re.compile(
        r"(reveal|print|repeat|output)\s+(your\s+)?(system\s+prompt|instructions|api\s*key|secret)", re.I),
     "attempt to extract secrets / system prompt"),

    ("install-time-exec", "high", re.compile(
        r"\"(pre|post)?install\"\s*:|\"prepare\"\s*:|\"prepublish\"\s*:", re.I),
     "npm lifecycle script runs on install"),
    ("install-time-exec", "high", re.compile(
        r"cmdclass|setup_requires|from\s+setuptools.*\bcmd\b", re.I),
     "setup.py build hook runs on install"),

    ("download-and-exec", "high", re.compile(
        r"(curl|wget)\b[^|;]*\|\s*(sh|bash|python\d?)"
        r"|iwr\b[^|;]*\|\s*iex|invoke-webrequest[^|;]*\|\s*invoke-expression"
        r"|invoke-expression\b|(^|\W)iex(\W|$)", re.I),
     "downloads and executes remote content"),
    ("obfuscation", "high", re.compile(
        r"eval\s*\(\s*(atob|base64|Buffer\.from|decode|fromCharCode)"
        r"|exec\s*\(\s*(base64|codecs\.decode|__import__)", re.I),
     "executes decoded/obfuscated payload"),

    ("egress", "medium", re.compile(
        r"169\.254\.169\.254|metadata\.google\.internal"),
     "reaches cloud metadata endpoint (credential theft)"),
    ("egress", "low", re.compile(
        r"https?://\d{1,3}(\.\d{1,3}){3}(:\d+)?"),
     "hardcoded IP URL"),

    ("credential-access", "medium", re.compile(
        r"~/\.ssh|\.aws/credentials|\.npmrc|id_rsa|\bAKIA[0-9A-Z]{16}\b"
        r"|-----BEGIN [A-Z ]*PRIVATE KEY-----", re.I),
     "accesses or embeds credentials/keys"),
    ("secret", "medium", re.compile(
        r"(api[_-]?key|secret|token|password)\s*[:=]\s*['\"][A-Za-z0-9_\-]{16,}['\"]", re.I),
     "hardcoded secret-looking value"),

    ("supply-chain", "low", re.compile(
        r"\"[^\"]+\"\s*:\s*\"(\*|latest|git\+|https?://)", re.I),
     "unpinned / URL / git dependency"),
    ("persistence", "medium", re.compile(
        r"crontab|/etc/cron|HKEY_[A-Z_]+\\\\.*\\\\Run|\.bashrc|\.zshrc|schtasks|New-ScheduledTask", re.I),
     "installs persistence (autostart/cron/registry)"),
]

# Invisible / bidi characters used to hide or reorder injected text.
HIDDEN_RANGES = [(0x200B, 0x200F), (0x202A, 0x202E), (0x2060, 0x2064), (0x2066, 0x2069), (0xFEFF, 0xFEFF)]
INSTALL_FILES = {"package.json", "setup.py", "pyproject.toml", "makefile", "dockerfile",
                 ".npmrc", "install.sh", "postinstall.js"}


def is_hidden(ch):
    o = ord(ch)
    return any(a <= o <= b for a, b in HIDDEN_RANGES)


def scan_file(path, max_bytes):
    hits = []
    try:
        if os.path.getsize(path) > max_bytes:
            return [(0, "skipped", "info", "file exceeds --max-bytes; opaque region, review manually")]
    except OSError:
        return hits
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            text = f.read()
    except Exception:
        return hits

    lines = text.splitlines()
    for cat, sev, rx, note in RULES:
        for m in rx.finditer(text):
            line_no = text.count("\n", 0, m.start()) + 1
            snippet = (lines[line_no - 1].strip()[:160] if 0 < line_no <= len(lines) else m.group(0)[:160])
            hits.append((line_no, cat, sev, f"{note}: {snippet}"))

    for i, line in enumerate(lines, 1):
        if any(is_hidden(c) for c in line):
            names = {unicodedata.name(c, f"U+{ord(c):04X}") for c in line if is_hidden(c)}
            hits.append((i, "hidden-unicode", "high",
                         f"invisible/bidi characters present ({', '.join(sorted(names))[:120]})"))

    # base64-ish blobs (obfuscation / hidden payload)
    for m in re.finditer(r"[A-Za-z0-9+/]{200,}={0,2}", text):
        line_no = text.count("\n", 0, m.start()) + 1
        hits.append((line_no, "obfuscation", "medium", f"long base64-like blob ({len(m.group(0))} chars) — opaque, review"))
    return hits


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("target")
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--max-bytes", type=int, default=2_000_000)
    a = ap.parse_args()

    root = os.path.abspath(a.target)
    if not os.path.isdir(root):
        print(f"not a directory: {root}", file=sys.stderr); sys.exit(2)

    findings, files_scanned, binaries = [], 0, []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for fn in filenames:
            full = os.path.join(dirpath, fn)
            rel = os.path.relpath(full, root)
            ext = os.path.splitext(fn)[1].lower()
            base = fn.lower()
            if ext not in TEXT_EXT and base not in TEXT_EXT and base not in INSTALL_FILES:
                binaries.append(rel)
                continue
            files_scanned += 1
            for line_no, cat, sev, msg in scan_file(full, a.max_bytes):
                findings.append({"file": rel, "line": line_no, "category": cat, "severity": sev, "detail": msg})

    order = {"high": 0, "medium": 1, "low": 2, "info": 3}
    findings.sort(key=lambda x: (order.get(x["severity"], 9), x["file"], x["line"]))
    counts = {}
    for f in findings:
        counts[f["severity"]] = counts.get(f["severity"], 0) + 1

    if a.json:
        print(json.dumps({"target": root, "files_scanned": files_scanned,
                          "binaries_unreviewed": binaries, "counts": counts, "findings": findings}, indent=2))
        return

    print(f"# static triage scan (READ-ONLY, nothing executed)")
    print(f"# target: {root}")
    print(f"# files scanned: {files_scanned} | binary/opaque (unreviewed): {len(binaries)} | hits: {counts}\n")
    if not findings:
        print("No heuristic hits. NOTE: static-clean is NOT proof of safety — see references/05-triage-report.md.")
    for f in findings:
        print(f"[{f['severity']:<6}] {f['category']:<18} {f['file']}:{f['line']}")
        print(f"           {f['detail']}")
    if binaries:
        print(f"\n# {len(binaries)} binary/opaque files were NOT reviewable as text (treat as high-suspicion):")
        for b in binaries[:40]:
            print(f"   - {b}")
        if len(binaries) > 40:
            print(f"   ... and {len(binaries) - 40} more")
    print("\n# This scan is a map, not a verdict. Confirm hits by READING (never running) the cited lines.")


if __name__ == "__main__":
    main()
