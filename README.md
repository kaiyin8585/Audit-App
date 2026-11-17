# Audit Tracker — SFRS(I) & SSA

A single-page audit testing tracker for Singapore statutory audits. Upload client Excel/CSV schedules (trial balances, journal listings, draft financial statements, lead schedules), run 23 automated tests, and track every exception with its amount, risk category, priority, exact cell location, and the SSA / SFRS(I) paragraph it relates to.

Everything runs in the browser. Uploaded files and issues are stored in the browser's `localStorage` only — nothing is sent to a server.

## Features

- **Issue tracker** — amount, risk category (Significant / High / Medium / Low) and priority (P1–P3), ranked against materiality (SSA 320 / SSA 450)
- **Where to find it** — workbook › sheet › cells, with a spreadsheet excerpt highlighting the flagged rows and cells
- **Standards** — each issue links to SSA and SFRS(I) paragraphs; the relevant line is highlighted, and a Standards view lists linked issues per paragraph
- **File upload** — `.xlsx`, `.xlsm`, `.xls`, `.csv` (parsed client-side with SheetJS); tracker backups (`.json`) can be imported too

### Automated tests

Casting, balance sheet agreement, TB Dr = Cr (current and prior year), journal balancing, unapproved / self-approved journals, entries by management or rarely-used accounts, back-dated and post-closing journals, splits under the approval limit, duplicates, round sums, weekend / holiday postings, period-end cut-off, manual revenue entries, unsupported entries, capitalised expenditure, estimate adjustments, items above performance materiality, related parties, year-on-year analytics, estimate balances, credit balances in assets, incomplete records, formula errors.

Line-level journal listings (one row per journal line, with a `JE_ID`-style column) are grouped into journals automatically.

## Deploy on Vercel

This is a static site — no build step.

1. In Vercel, choose **Add New… → Project** and import `kaiyin8585/audit-app`.
2. Framework preset: **Other**. Leave Build Command and Output Directory empty (root directory `./`).
3. Click **Deploy**.

Every push to `main` redeploys automatically.

To run locally, open `index.html` in a browser, or serve the folder (e.g. `npx serve .`).

## Notes

- Requires internet access to load SheetJS from `cdnjs.cloudflare.com` and fonts from Google Fonts.
- Data lives in one browser on one device. Use **Back up / restore data** in the footer to move or keep it.
- Paragraph summaries of the SSAs and SFRS(I) are paraphrased for navigation. Always refer to the authoritative standards, and check which versions apply to the period under audit (e.g. SFRS(I) 18 replaces SFRS(I) 1-1 for annual periods beginning on or after 1 January 2027).
- Automated tests flag items for auditor judgement; they are not audit conclusions.
