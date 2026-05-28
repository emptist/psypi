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
  'open_severity_breakdown', (
    SELECT json_object_agg(severity, cnt)
    FROM (SELECT severity, COUNT(*) as cnt FROM review_findings WHERE review_id = r.id AND status = 'open' GROUP BY severity) s
  ),
  'open_category_breakdown', (
    SELECT json_object_agg(category, cnt ORDER BY cnt DESC)
    FROM (SELECT category, COUNT(*) as cnt FROM review_findings WHERE review_id = r.id AND status = 'open' GROUP BY category ORDER BY cnt DESC) c
  ),
  'open_total', (SELECT COUNT(*) FROM review_findings WHERE review_id = r.id AND status = 'open'),
  'retracted_total', (SELECT COUNT(*) FROM review_findings WHERE review_id = r.id AND status = 'retracted'),
  'duplicate_total', (SELECT COUNT(*) FROM review_findings WHERE review_id = r.id AND status = 'duplicate'),
  'all_total', (SELECT COUNT(*) FROM review_findings WHERE review_id = r.id),
  'open_findings', (
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
    FROM review_findings f WHERE f.review_id = r.id AND f.status = 'open'
  ),
  'retracted_findings', (
    SELECT json_agg(json_build_object(
      'number', f.finding_number,
      'title', f.title,
      'status', f.status
    ) ORDER BY f.finding_number)
    FROM review_findings f WHERE f.review_id = r.id AND f.status IN ('retracted', 'duplicate')
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
findings = data["open_findings"]
retracted = data.get("retracted_findings") or []

lines = []
lines.append(f"# System Review — psypi — {r['created_at'][:10]} (Database-Backed, Re-verified)")
lines.append("")
lines.append("Generated from `system_reviews` + `review_findings` database tables.")
lines.append(f"Review ID: `{REVIEW_ID}`")
lines.append(f"Type: `{r['type']}` | Methodology: `{r['methodology']}` | Scope: `{r['scope']}`")
lines.append(f"Reviewer: `{r['reviewer']}` | Git: `{r['git_hash']}` (`{r['git_branch']}`)")
lines.append("")
lines.append("### Re-verification Notes")
lines.append("")
lines.append("This review was re-verified against actual code flow and database schema. Key corrections:")
lines.append("- Retracted 11 false-positive uuid-without-::text findings (node-postgres returns uuid as string automatically)")
lines.append("- Retracted findings based on incorrect assumptions (e.g., #124 Gleam Bool=JS boolean, #158 Gleam package imports, #162 SQL injection)")
lines.append("- Corrected severity: only 1 CRITICAL finding remains (#249 FFI type mismatch)")
lines.append("- Added type alignment audit findings (#274-#287) based on systematic PG-column-type vs Gleam-decoder-type comparison")
lines.append("- All findings verified against: (1) actual source code, (2) database CHECK constraints, (3) node-postgres type mapping rules")
lines.append("")

lines.append("## Severity Breakdown (Open Findings Only)")
lines.append("")
lines.append("| Severity | Count | Percentage |")
lines.append("|----------|-------|------------|")
total = data["open_total"]
for sev in ["critical", "high", "medium", "low", "cosmetic"]:
    cnt = data["open_severity_breakdown"].get(sev, 0)
    if cnt > 0:
        pct = round(cnt / total * 100, 1)
        lines.append(f"| **{sev.upper()}** | {cnt} | {pct}% |")
lines.append(f"| **TOTAL (open)** | {total} | 100% |")
lines.append(f"| Retracted | {data['retracted_total']} | - |")
lines.append(f"| Duplicate | {data['duplicate_total']} | - |")
lines.append(f"| **ALL findings** | {data['all_total']} | - |")
lines.append("")

lines.append("## Category Breakdown (Open Findings)")
lines.append("")
lines.append("| Category | Count | C/H |")
lines.append("|----------|-------|-----|")
for cat, cnt in sorted(data["open_category_breakdown"].items(), key=lambda x: -x[1]):
    cat_findings = [f for f in findings if f["category"] == cat]
    crits = sum(1 for f in cat_findings if f["severity"] == "critical")
    highs = sum(1 for f in cat_findings if f["severity"] == "high")
    detail = f"{crits}C/{highs}H" if crits > 0 or highs > 0 else "-"
    lines.append(f"| {cat} | {cnt} | {detail} |")
lines.append("")

lines.append("## Type Alignment Reference")
lines.append("")
lines.append("node-postgres type mapping rules (verified):")
lines.append("| PG Type | JS Type | Gleam Decoder | Cast Needed |")
lines.append("|---------|---------|---------------|-------------|")
lines.append("| uuid | string | decode.string | No |")
lines.append("| timestamptz | Date object | decode.string | **YES: ::text** |")
lines.append("| bigint/int8 | string | decode.int | **YES: ::int or custom** |")
lines.append("| jsonb | parsed object | decode.string | **YES: ::text** |")
lines.append("| integer | number | decode.int | No |")
lines.append("| boolean | boolean | decode.bool | No |")
lines.append("| text/varchar | string | decode.string | No |")
lines.append("| ARRAY | array | decode.list | No (for text[]) |")
lines.append("")

lines.append("## Findings by Severity (Open Only)")
lines.append("")

prev_sev = ""
for f in findings:
    if f["severity"] != prev_sev:
        prev_sev = f["severity"]
        lines.append(f"### {prev_sev.upper()}")
        lines.append("")
        lines.append("| # | Category | Module | Title |")
        lines.append("|---|----------|--------|-------|")
    lines.append(f"| {f['number']} | {f['category']} | {f['module'] or '-'} | {f['title']} |")
lines.append("")

lines.append("## Detailed Findings (Open Only)")
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
    if f['evidence']:
        lines.append(f"**Evidence**: `{f['evidence']}`")
        lines.append("")
    if f['impact']:
        lines.append(f"**Impact**: {f['impact']}")
        lines.append("")

lines.append("## Retracted/Duplicate Findings")
lines.append("")
lines.append("| # | Title | Status |")
lines.append("|---|-------|--------|")
for f in retracted:
    lines.append(f"| {f['number']} | {f['title']} | {f['status']} |")
lines.append("")

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

lines.append("## Verification Instructions")
lines.append("")
lines.append("Any AI can verify this review by:")
lines.append("1. `psql -d psypi -c \"SELECT severity, COUNT(*) FROM review_findings WHERE review_id = 'ca9e914c-cce6-4db4-b3b1-29779d8e1837' AND status = 'open' GROUP BY severity\"`")
lines.append("2. `psql -d psypi -c \"SELECT * FROM table_documentation WHERE table_name = 'type_alignment_reference'\"`")
lines.append("3. Cross-reference each finding with source code and database schema")
lines.append("4. Verify node-postgres type mapping: https://node-postgres.com/features/types")
lines.append("")

print("\n".join(lines))
