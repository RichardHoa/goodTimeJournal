# 03: Accounts & Balances layout, CSV export and import, Money In/Out colors

**What was built:** This work was done outside tickets 01 and 02, and is recorded here afterwards. The Finance screen now holds only the header, the Money In / Money Out buttons and Recent Transactions. Everything else lives on the Accounts & Balances screen: accounts, Funds, Trash, the theme switch, and CSV export and import. The export can be saved to a folder or shared, and it carries each transaction's full date and time. A CSV export can be imported to replace the current data. Money In and Money Out tiles have their own colors and arrows.

Spec: `.scratch/finance-only-revamp/spec.md`. This ticket covers user stories 3, 15, 16 and 35 as they read now, plus 70–80.

**Blocked by:** 01, 02

**Status:** resolved: fully completed, no further work needed.

## Scope

1. **Layout:** the Finance screen's top bar keeps only the info icon; the Funds card, Trash icon, theme icon and export icon are removed from it. The Accounts & Balances screen has, in order: the Money Left summary (with Total Net Worth and Funds), Accounts, Asset Breakdown (Total Money, Funds → Funds page, Money Left), Settings & Data (Dark mode switch, Trash with an item-count badge, Export CSV, Import CSV), and credits.
2. **CSV export:** "Export CSV" asks for "Save to folder" (the system save dialog) or "Share" (the system share sheet). The file is named `mixapp_finance_<yyyyMMdd_HHmmss>.csv`. The transactions log has the columns `date, type, account, amount_k_vnd, amount_vnd, note, previous_value_k_vnd, new_value_k_vnd, datetime`.
3. **CSV import:** "Import CSV" opens the system file picker (any file type), reads the file, and shows how many transactions and Funds it holds, its Total Money, and what will be replaced. On confirm, it replaces balances, transactions and Funds and leaves Trash alone. Every imported transaction and Fund gets a new id. Funds keep the file's order and get the import time as their creation time. Exports without `datetime` load with each transaction at 00:00 of its day. A file that isn't a finance export is rejected with a message and nothing changes. Before replacing, the raw stored data is copied to `<key>_before_import`.
4. **Money In/Out colors:** Money In tiles are blue with a ↙ arrow and a `+` sign. Money Out tiles are magenta with a ↗ arrow and a `−` sign. Both get a light tint and a colored border. Balance updates keep the primary color.
5. **Code structure:**
   - The CSV format lives in `lib/services/finance_csv.dart`, as pure functions.
   - `CsvService` only saves, shares and picks files.
   - The export and import flows are in `lib/widgets/finance_csv_actions.dart`.
   - `AccountBalances` owns the mapping between account names and fields.
   - `FinanceMigration.asideKey` names every key used to set raw data aside.

## Acceptance criteria

- [x] The Finance screen shows only the header, Money In / Money Out and Recent Transactions, with only the info icon in its top bar
- [x] Dark mode, Trash (with badge), Export CSV and Import CSV are in Settings & Data on the Accounts & Balances screen
- [x] The Funds total and a Funds row that opens the Funds page are on the Accounts & Balances screen
- [x] Export can save to a chosen folder or share, and includes the `datetime` column
- [x] An export imports back to the same balances, transactions (ids aside) and Funds, and survives a reload
- [x] Exports without `datetime`, with CRLF line ends and a BOM, still import
- [x] Non-exports are rejected and nothing changes
- [x] Import keeps Trash and sets the replaced data aside under `<key>_before_import`
- [x] A transaction restored from Trash after an import never shares an id with an imported one
- [x] A Fund restored from Trash goes back into creation order
- [x] Money In and Money Out tiles show their own color, arrow and sign
- [x] Analyzer is clean and the full test suite passes (79 tests)

## Comments

**2026-10-03 — closed as complete.** The developer made these changes outside the tickets, and confirmed that's fine. Nothing further is needed.
- Known limitation, not open work: CSVs exported before the revamp aren't converted on import.
  - Files that still have an `MB fund` row are rejected.
  - Files with a `Backup Fund` row import without that Fund.
  - Exports from the current format, and from the first Funds format, import fully.
