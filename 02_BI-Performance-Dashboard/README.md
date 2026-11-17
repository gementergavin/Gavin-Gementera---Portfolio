# Program Performance Dashboard (Excel)

An Excel dashboard for a mock workforce training organization. It turns 500 transaction records into KPIs, program and region breakdowns, a quarterly trend, and two charts.

## File

`BI_Performance_Dashboard.xlsx`

| Tab | What's in it |
|---|---|
| `Transaction_Data_Sample` | 500 sample records: program, region, contract type, delivery mode, enrollment date, participants enrolled and completed, revenue, satisfaction score, fiscal year and quarter |
| `Executive_Dashboard` | KPI cards, top 8 programs by revenue, revenue by quarter, revenue and enrollment by region, two charts |
| `Methodology_Data_Dictionary` | Field definitions and a guide for rebuilding the dashboard in Power BI |

## How it works

Every number on the dashboard is a formula over the data tab, so changing or adding data updates it:

- **KPIs:** total revenue, participants enrolled and completed, completion rate (completed / enrolled), average satisfaction.
- **Top 8 programs:** a helper list (columns N-O) totals revenue for all 12 programs with `SUMIFS`; the table ranks them with `LARGE` + `INDEX`/`MATCH`, then pulls enrollment, completions, completion rate, revenue and satisfaction (`AVERAGEIFS`) for each.
- **Quarterly trend:** `SUMIFS` on fiscal year and quarter.
- **Regions:** `SUMIFS` on region.
- **Charts:** a bar chart of revenue by program and a line chart of revenue by quarter, both linked to the tables.

The data is synthetic, created for this project.

## Skills shown

Excel formulas (SUMIFS, AVERAGEIFS, INDEX/MATCH, LARGE), KPI design, charts, and a data dictionary. The methodology tab lists the DAX measures for a Power BI version.
