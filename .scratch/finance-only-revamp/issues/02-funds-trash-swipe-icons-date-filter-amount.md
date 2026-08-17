# 02: Funds, Trash, swipe to delete, bank icons, history date filter, đ amount field

**What to build:** The single Backup Fund becomes a Funds page that holds any number of named **Funds**, and **Money Left** = Total Money − sum of Funds. Deleting a transaction or a Fund sends it to **Trash** for 30 days, and it can be restored from there. Swiping left on a transaction tile or a Fund row deletes it after a confirmation dialog. Bank symbols appear wherever an account is named. The history page has a single date pill that opens a bottom sheet of presets plus a custom range. The amount field shows `đ` instead of a dollar icon.

Spec: `.scratch/finance-only-revamp/spec.md`. This ticket covers user stories 15–56, 58–59, 63 and 68–69.

**Blocked by:** 01 (Finance-only app, MB investment, and Balance adjustments)

**Status:** resolved: fully completed, no further work needed.

## Scope

1. **Funds:** add a Fund entity `{id, name, amount (k), createdAt}`, stored as an ordered list under its own key. The Accounts & Balances screen shows the total of all Funds next to Total Money, and its Asset Breakdown has a Funds row that opens the Funds page. On that page you add a Fund (name and amount in k) and tap a Fund to edit it. Names are required and unique (trimmed, case-insensitive), and Funds are listed in creation order, which the stored list keeps; a restored Fund goes back into its place. Money Left is computed by the provider and shown in red when negative. Fund changes stay out of Transaction History. Drop `backupFund` from the balances model. Add these steps to the 01 conversion pipeline: create a "Backup" Fund from the old Backup Fund amount when it is greater than 0, and remove `fieldUpdate` records on "Backup Fund" without touching any balance. The CSV summary lists Cash, VCB, MB, Techcombank, MB investment, Total Money, one row per Fund, Funds total, and Money Left.
2. **Trash:** deleting a transaction reverses its balance effect and moves it to Trash. Trash is stored under one key as tagged entries (`kind: transaction | fund`, `deletedAt`, `payload`). A Trash page opens from a Trash row (with a badge counting its items) in the Settings & Data section of the Accounts & Balances screen and shows each item with what it is, when it was deleted, and how many days are left. Restoring a transaction re-applies its amount to the current balance and keeps its original id, date and note. "Delete forever" removes one item and "Empty trash" removes everything, each after a confirmation. On load, items whose `deletedAt` is more than 30 days before "now" (the injected clock) are purged. Trash is not exported to CSV.
3. **Swipe to delete:** transaction tiles in Recent Transactions and in Transaction History, and Fund rows on the Funds page, can be swiped end-to-start only. The swipe shows a confirmation dialog and only completes on Confirm; Cancel puts the item back exactly as it was. Tapping still opens edit. The small edit and delete icon buttons on tiles are removed. A deleted Fund goes to Trash. Restoring a Fund re-adds it, unless its name is now taken, in which case restore is blocked with a clear message.
4. **Bank icons:** crop the bank logos into transparent square PNGs showing only the symbol (VCB as-is, the MB star, the Techcombank double-diamond) and add them as assets. A single account-icon widget maps each account name to its icon: Cash gets the wallet material icon and MB investment gets the MB star. Use it in the Money In/Out account dropdown, the Accounts list, the transaction tiles, and the history account filter.
5. **History date filter:** pure preset functions take "now" and return a start/end range for Today, This week (Monday 00:00 to end of today) and This month; All time means no range. The row of date pills is replaced by a single pill labelled "All time", the preset name, or `dd/MM – dd/MM`. Tapping it opens a modal bottom sheet with the presets as selectable rows (the current one checked) and a "Pick range…" row that opens the date range picker. Reset filters sets the date back to All time.
6. **Amount field:** the dollar prefix icon becomes a `đ` text prefix and the suffix becomes `k`, keeping the full-VND preview. The balance-edit dialog and the Fund amount input get the same treatment.

## Acceptance criteria

- [x] Funds can be added and edited, empty or duplicate names (trimmed, case-insensitive) are rejected, and the list keeps creation order
- [x] The Accounts & Balances screen shows the Funds total and a Funds row that opens the Funds page, and Money Left = Total Money − Funds, red when negative
- [x] Conversion: the Backup Fund amount becomes a "Backup" Fund, a zero Backup Fund creates no Fund, Backup Fund records are removed, and no balance changes
- [x] Deleting a transaction reverses its balance effect and puts it in Trash
- [x] Restoring a transaction re-applies its amount to the current balance and keeps its original id, date and note
- [x] A converted Balance adjustment can be deleted and restored like a native one
- [x] A Fund deleted by swipe goes to Trash, and restoring it when its name is now taken fails with a clear message
- [x] Delete forever and Empty trash work, each after a confirmation
- [x] Trash items more than 30 days old are purged on load (tested at the boundary with the injected clock)
- [x] Funds, Trash and balances all survive a reload
- [x] Transaction tiles have no edit/delete icon buttons, tapping a tile opens edit, and swiping left asks for confirmation
- [x] Widget test: swipe a tile, Cancel leaves it in place, swipe again, Confirm moves it to Trash
- [x] Bank symbols with transparent backgrounds show in the dropdown, the Accounts list, the tiles and the history account filter, with Cash as a wallet and MB investment as the MB star
- [x] Preset tests: This week starts on Monday ("now" on a Monday, a mid-week day, and a Sunday), This month boundaries, and Today
- [x] The history page has one date pill and a bottom sheet with All time, Today, This week, This month and Pick range…, and Reset filters returns to All time
- [x] Amount inputs show a `đ` prefix and `k` suffix, with the full-VND preview kept
- [x] The CSV export test covers MB investment, Fund rows, the Funds total, and the absence of Trash
- [x] Analyzer is clean and the full test suite passes

## Comments

**2026-10-03 — closed as complete.** Some of this work was built differently from what this ticket first described, and some was done outside any ticket. The developer has confirmed that's fine: the ticket now describes the app as it is, every acceptance criterion is met, and nothing further is needed.
- The Funds card on the Finance screen and the Trash icon in its top bar were removed; Funds and Trash are reached from the Accounts & Balances screen instead (done outside this ticket, see 03).
- Every acceptance criterion is covered by `test/funds_trash_test.dart`, `test/finance_migration_test.dart`, `test/date_presets_test.dart`, `test/swipe_to_delete_test.dart`, `test/history_date_filter_test.dart` and `test/finance_test.dart`. Analyzer is clean and all 79 tests pass.
