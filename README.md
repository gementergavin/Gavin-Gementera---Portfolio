# Gavin Gementera — IT & Data Portfolio

Projects I built to practice IT support, data, and governance work. I have a B.S. in Business Administration (Information Systems) from CSU Fullerton (2025).

## Projects

| Project | What it is | Tools |
|---|---|---|
| [Inventory Management System](./03_Inventory-Management-System) | Command-line app that tracks stock across 4 locations, rejects bad input, flags low stock, and logs every change. Includes 11 unit tests. | Python, SQLite, SQL |
| [Program Performance Dashboard](./02_BI-Performance-Dashboard) | Excel dashboard built on 500 sample records: KPIs, top programs, regions, quarterly trend, charts. Every number is a live formula. | Excel |
| [IT Risk Register & Data Governance Framework](./01_Risk-Governance-Framework) | 18 IT risks scored by likelihood and impact, a 5x5 heat map, and a 2-page data governance policy. | Excel, technical writing |

## Try the inventory app

Requires Python 3.9+; nothing to install.

```bash
git clone https://github.com/gementergavin/Gavin-Gementera---Portfolio.git
cd Gavin-Gementera---Portfolio/03_Inventory-Management-System
python inventory_app.py
```

Run the tests with `python -m unittest discover tests` from the same folder.

## Excel projects

Download the `.xlsx` files and open them in Excel or Google Sheets. GitHub can't preview Excel files.
