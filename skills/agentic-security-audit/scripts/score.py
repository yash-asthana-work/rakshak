#!/usr/bin/env python3
"""
score.py — objective severity scoring for agentic-security-audit findings.
Keeps severity reproducible instead of eyeballed.

Input JSON: {"findings":[{"id","title","impact","reachability","exploit_ease",
"detection","trifecta":false, "owasp":"LLM01"}...]}  (axes 1-5; detection: higher = worse recovery)

Usage: python score.py findings.json
"""
import json, sys

AXES = ["impact", "reachability", "exploit_ease", "detection"]

def severity(f):
    if f.get("trifecta"):
        return "Critical", "lethal-trifecta (A+B+C present)"
    vals = [int(f[a]) for a in AXES]
    avg = sum(vals) / len(vals)
    # override: catastrophic + reachable jumps to Critical regardless of average
    if f["impact"] >= 5 and f["reachability"] >= 4:
        return "Critical", f"impact={f['impact']}, reach={f['reachability']} (override)"
    if avg >= 4:   return "Critical", f"avg={avg:.2f}"
    if avg >= 3:   return "High", f"avg={avg:.2f}"
    if avg >= 2:   return "Medium", f"avg={avg:.2f}"
    return "Low", f"avg={avg:.2f}"

ORDER = {"Critical":0, "High":1, "Medium":2, "Low":3}

def main():
    if len(sys.argv) != 2:
        print("usage: python score.py findings.json", file=sys.stderr); sys.exit(1)
    data = json.load(open(sys.argv[1]))
    findings = data.get("findings", [])
    scored = []
    for f in findings:
        for a in AXES:
            f.setdefault(a, 1)
        sev, why = severity(f)
        scored.append({**f, "severity": sev, "rationale": why,
                       "subscores": {a: f[a] for a in AXES}})
    scored.sort(key=lambda x: ORDER[x["severity"]])

    counts = {}
    for s in scored:
        counts[s["severity"]] = counts.get(s["severity"], 0) + 1
    posture = ("Critical" if counts.get("Critical") else
               "High" if counts.get("High") else
               "Medium" if counts.get("Medium") else "Low")

    print(f"OVERALL POSTURE: {posture}   counts={counts}\n")
    print(f"{'ID':<6}{'SEVERITY':<10}{'I/R/E/D':<12}{'OWASP':<8}TITLE")
    print("-" * 78)
    for s in scored:
        sub = "/".join(str(s["subscores"][a]) for a in AXES)
        print(f"{str(s.get('id','?')):<6}{s['severity']:<10}{sub:<12}"
              f"{str(s.get('owasp','-')):<8}{s.get('title','')}")
    print()
    print(json.dumps({"posture": posture, "counts": counts, "findings": scored}, indent=2))

if __name__ == "__main__":
    main()
