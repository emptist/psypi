#!/usr/bin/env python3
import json
import subprocess
import sys

REVIEW_ID = "ca9e914c-cce6-4db4-b3b1-29779d8e1837"

sql = f"""
SELECT json_build_object(
  'review', json_build_object(
    'title', r.title,
    'type', r.review_type,
    'status', r.status,
    'methodology', r.methodology,
    'scope', r.scope,
    'reviewer', r.reviewer_id,
    'git_hash', r.git_hash,
    'git_branch', r.git_branch,
    'created_at', r.created_at::text
  ),
  'severity_breakdown', (
    SELECT json_object_agg(severity, cnt)
    FROM (SELECT severity, COUNT(*) as cnt FROM review_findings WHERE review_id = r.id GROUP BY severity) s
  ),
  'category_breakdown', (
    SELECT json_object_agg(category, cnt ORDER BY cnt DESC)
    FROM (SELECT category, COUNT(*) as cnt FROM review_findings WHERE review_id = r.id GROUP BY category ORDER BY cnt DESC) c
  ),
  'total_findings', (SELECT COUNT(*) FROM review_findings WHERE review_id = r.id),
  'findings', (
    SELECT json_agg(json_build_object(
      'number', f.finding_number,
      'severity', f.severity,
      'category', f.category,
      'module', f.module,
      'title', f.title,
      'description', f.description,
      'evidence', f.evidence,
      'impact', f.impact,
      'status', f.status
    ) ORDER BY CASE f.severity WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 WHEN 'low' THEN 4 END, f.category, f.finding_number)
    FROM review_findings f WHERE f.review_id = r.id
  )
)
FROM system_reviews r
WHERE r.id = '{REVIEW_ID}'
"""

result = subprocess.run(
    ["psql", "-d", "psypi", "-t", "-A", "-c", sql],
    capture_output=True, text=True
)

if result.returncode != 0:
    print(f"psql error: {result.stderr}", file=sys.stderr)
    sys.exit(1)

data = json.loads(result.stdout.strip())
r = data["review"]
findings = data["findings"]

lines = []
lines.append(f"# System Review — psypi — {r['created_at'][:10]} (Database-Backed)")
lines.append("")
lines.append("Generated from `system_reviews` + `review_findings` database tables.")
lines.append(f"Review ID: `{REVIEW_ID}`")
lines.append(f"Type: `{r['type']}` | Methodology: `{r['methodology']}` | Scope: `{r['scope']}`")
lines.append(f"Reviewer: `{r['reviewer']}` | Git: `{r['git_hash']}` (`{r['git_branch']}`)")
lines.append("")

# Severity breakdown
lines.append("## Severity Breakdown")
lines.append("")
lines.append("| Severity | Count | Percentage |")
lines.append("|----------|-------|------------|")
total = data["total_findings"]
for sev in ["critical", "high", "medium", "low", "cosmetic"]:
    cnt = data["severity_breakdown"].get(sev, 0)
    if cnt > 0:
        pct = round(cnt / total * 100, 1)
        lines.append(f"| **{sev.upper()}** | {cnt} | {pct}% |")
lines.append(f"| **TOTAL** | {total} | 100% |")
lines.append("")

# Category breakdown
lines.append("## Category Breakdown")
lines.append("")
lines.append("| Category | Count | Findings |")
lines.append("|----------|-------|----------|")
for cat, cnt in sorted(data["category_breakdown"].items(), key=lambda x: -x[1]):
    cat_findings = [f for f in findings if f["category"] == cat]
    crits = sum(1 for f in cat_findings if f["severity"] == "critical")
    highs = sum(1 for f in cat_findings if f["severity"] == "high")
    detail = f"{crits}C/{highs}H" if crits > 0 or highs > 0 else ""
    lines.append(f"| {cat} | {cnt} | {detail} |")
lines.append("")

# Findings by severity
lines.append("## Findings by Severity")
lines.append("")

prev_sev = ""
for f in findings:
    if f["severity"] != prev_sev:
        prev_sev = f["severity"]
        lines.append(f"### {prev_sev.upper()}")
        lines.append("")
        lines.append("| # | Category | Module | Title | Impact |")
        lines.append("|---|----------|--------|-------|--------|")
    lines.append(f"| {f['number']} | {f['category']} | {f['module'] or '-'} | {f['title']} | {f['impact']} |")
lines.append("")

# Detailed findings
lines.append("## Detailed Findings")
lines.append("")
for f in findings:
    lines.append(f"### #{f['number']} — {f['title']}")
    lines.append("")
    lines.append(f"- **Severity**: {f['severity'].upper()}")
    lines.append(f"- **Category**: {f['category']}")
    lines.append(f"- **Module**: `{f['module'] or 'N/A'}`")
    lines.append(f"- **Status**: {f['status']}")
    lines.append("")
    lines.append(f"**Description**: {f['description']}")
    lines.append("")
    lines.append(f"**Evidence**: `{f['evidence']}`")
    lines.append("")
    lines.append(f"**Impact**: {f['impact']}")
    lines.append("")

# Top 10 system-stopping issues
lines.append("## Top 10 System-Stopping Issues")
lines.append("")
lines.append("| # | Finding | Why It Stops The System |")
lines.append("|---|---------|------------------------|")
top_findings = [f for f in findings if f["severity"] == "critical" and f["status"] == "open"]
top_findings += [f for f in findings if f["severity"] == "high" and f["status"] == "open"]
top_findings = top_findings[:10]
for f in top_findings:
    lines.append(f"| {f['number']} | {f['title']} | {f['impact']} |")
lines.append("")

print("\n".join(lines))
