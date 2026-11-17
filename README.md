# Audit Tracker — SFRS(I) & SSA

A single-page audit testing tracker for Singapore statutory audits. Upload client Excel/CSV schedules (trial balances, journal listings, draft financial statements, lead schedules), run 23 automated tests, and track every exception with its amount, risk category, priority, exact cell location, and the SSA / SFRS(I) paragraph it relates to.

Team members sign in with a username and password (Supabase Auth). Engagements, uploaded workbooks and issues are saved to Supabase and shared by everyone signed in; Excel parsing and the tests run in the browser.

## Features

- **Issue tracker** — amount, risk category (Significant / High / Medium / Low) and priority (P1–P3), ranked against materiality (SSA 320 / SSA 450)
- **Where to find it** — workbook › sheet › cells, with a spreadsheet excerpt highlighting the flagged rows and cells
- **Standards** — each issue links to SSA and SFRS(I) paragraphs; the relevant line is highlighted, and a Standards view lists linked issues per paragraph
- **File upload** — `.xlsx`, `.xlsm`, `.xls`, `.csv` (parsed client-side with SheetJS); tracker backups (`.json`) can be imported too

### Automated tests

Casting, balance sheet agreement, TB Dr = Cr (current and prior year), journal balancing, unapproved / self-approved journals, entries by management or rarely-used accounts, back-dated and post-closing journals, splits under the approval limit, duplicates, round sums, weekend / holiday postings, period-end cut-off, manual revenue entries, unsupported entries, capitalised expenditure, estimate adjustments, items above performance materiality, related parties, year-on-year analytics, estimate balances, credit balances in assets, incomplete records, formula errors.

Line-level journal listings (one row per journal line, with a `JE_ID`-style column) are grouped into journals automatically.

## Sign-in and users

- Sign in with a **username** (e.g. `priya`) and password. Behind the scenes the app uses the Supabase Auth email `<username>@auditapp.local`; no email is ever sent.
- Seeded users: `priya` (administrator), `dan` and `marcus` (auditors), all with the initial password `password`. Everyone is made to choose a new password at first sign-in.
- Administrators get a **Users** page to add users with an initial password, reset passwords, change roles and delete users. These actions run in the `admin-users` Edge Function, which holds the service-role key server-side and checks the caller is an admin.
- Sign out and change password from the avatar menu (top right).
- Work saved in a browser before sign-in was added can be imported into Supabase from a banner on the Overview page.

## Supabase

| Table | Purpose |
|---|---|
| `auth.users` | Supabase Auth accounts; passwords are hashed here and nowhere else |
| `profiles` | Username, display name, role (`admin` / `auditor`), must-change-password flag — one row per auth user, created by trigger |
| `engagements` | One audit file: entity, year end, materiality, thresholds, enabled tests |
| `workbooks` | Uploaded files with their parsed sheets (JSON) |
| `issues` | Findings with amount, risk, priority, status, location, SSA / SFRS(I) references, notes and audit trail (`created_by`, `updated_by`) |

Row level security: only signed-in users can read or write; users can't change their own role; only administrators can delete engagements. The schema is in `supabase/migrations/`, the sample users in `supabase/seed.sql`, and the user-management function in `supabase/functions/admin-users/`.

The Supabase URL and **publishable** key are embedded in `index.html`; they are designed to be public, and access is enforced by row level security. Never put the service-role key in the page.

## Deploy on Vercel

This is a static site — no build step.

1. In Vercel, choose **Add New… → Project** and import `kaiyin8585/audit-app`.
2. Framework preset: **Other**. Leave Build Command and Output Directory empty (root directory `./`).
3. Click **Deploy**.

Every push to `main` redeploys automatically.

To run locally, open `index.html` in a browser, or serve the folder (e.g. `npx serve .`).

## Notes

- Requires internet access to load SheetJS (`cdnjs.cloudflare.com`), supabase-js (`cdn.jsdelivr.net`) and Google Fonts, and to reach `efcrblpnggfwcgjrezfr.supabase.co`.
- **Back up / import data** in the footer copies the current engagement as JSON, or imports a backup into it.
- In Supabase → Authentication → Settings, consider turning on leaked-password protection and a minimum password length of 8.
- Paragraph summaries of the SSAs and SFRS(I) are paraphrased for navigation. Always refer to the authoritative standards, and check which versions apply to the period under audit (e.g. SFRS(I) 18 replaces SFRS(I) 1-1 for annual periods beginning on or after 1 January 2027).
- Automated tests flag items for auditor judgement; they are not audit conclusions.
