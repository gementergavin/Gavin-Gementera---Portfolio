# IT Risk Register, Heat Map & Data Governance Framework

An Excel risk register and a written data governance policy for a mock workforce training organization. It shows how an IT team can score risks, see where they cluster, and set rules for keeping data clean.

## Files

| File | What's in it |
|---|---|
| `IT_Risk_Governance_Framework.xlsx` | Risk register (18 risks), heat map and summary, data governance procedures |
| `Data_Governance_Policy_Procedures_Manual.pdf` | 2-page policy: data entry standards, quality audits, cleanup, change control, roles |

## How the workbook works

**Risk Register tab**
- 18 risks across 7 categories: data privacy and security, data quality, system and vendor management, operations, reporting and compliance, business continuity, change and adoption.
- Likelihood and impact are scored 1-5 (data validation blocks anything else).
- **Risk Score** = likelihood x impact, and **Risk Level** is assigned by formula: 15+ Critical, 10-14 High, 5-9 Medium, under 5 Low. Color coding follows the level.
- Each risk has an owner, a mitigation plan, a status and a last-reviewed date.
- Rows 22-30 are ready for new risks; their score and level fill in automatically.

**Heat Map & Summary tab**
- Counts of risks by level and category, the average score, and how many mitigations are in progress, all calculated from the register.
- A 5x5 heat map that counts risks by likelihood and impact, shaded by severity zone.

**Data Governance Procedures tab**
- Data entry standards, weekly and quarterly quality checks, cleanup and deduplication steps, and change control rules.

## Skills shown

Risk assessment, Excel formulas (COUNTIF, COUNTIFS, nested IF), data validation, conditional formatting, and policy writing.
