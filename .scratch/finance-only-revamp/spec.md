# Finance-only revamp: Funds, Trash, Balance adjustments, bank icons

Status: resolved: fully completed, no further work needed. This spec describes the app as it is now (tickets 01–03).

## Problem Statement

The app mixes a journal with personal finance, but the user only uses finance now. Within finance, the current model gets in their way:

- Editing a Liquid account's balance directly (Cash, VCB, MB, Techcombank) produces an opaque "Update" record instead of a real Money In or Money Out, so history doesn't explain where money went.
- There is only one hard-coded "Backup Fund", but the user sets money aside for several purposes.
- "MB fund" is named like a Fund, but it's actually an investment that counts toward Total Money.
- Deleting a transaction is permanent and needs small icon buttons; Recent Transactions can't be deleted at all.
- Accounts are plain text everywhere; bank logos would make them recognisable at a glance.
- The history page has a row of date pills (All time, Today, This Week, This Month, Custom Date) that is cluttered and ugly.
- The amount field shows a US dollar icon, although every amount is in Vietnamese đồng.

## Solution

A finance-only app with no journal and no bottom tab bar. A direct edit to a Liquid account's balance is recorded as a Money In or Money Out (a Balance adjustment); only MB investment (renamed from "MB fund") keeps direct edits as Balance updates. The single Backup Fund becomes a Funds page holding any number of named Funds, and Money Left = Total Money − sum of Funds. The Finance screen stays focused on Money In/Out and recent transactions; everything else (accounts, Funds, Trash, theme, CSV export and import) lives on the Accounts & Balances screen, opened from the info icon or the header. Deletions go to a Trash for 30 days and can be restored. Swiping left on any transaction tile deletes it after confirmation. Bank logos (symbol only, transparent background) appear wherever an account is named. History has one date pill that opens a tidy bottom sheet of presets plus a custom range. The amount field shows `đ`.

Existing data is converted once, safely: old Updates on Liquid accounts become Money In/Out, "MB fund" becomes "MB investment", the Backup Fund amount becomes a "Backup" Fund, and old Backup Fund history records are dropped without touching any balance.

## User Stories

### Finance-only app

1. As the user, I want the app to open straight to Finance with no bottom tab bar, so that I'm not distracted by a journal I no longer use.
2. As the user, I want the journal screens, data handling, and journal CSV import/export removed, so that the app only contains what I use.
3. As the user, I want to keep switching between light and dark theme from a Dark mode switch on the Accounts & Balances screen, so that removing the journal doesn't cost me the theme setting.
4. As the user, I want my old journal data left alone on the device (not wiped), so that nothing is destroyed irreversibly.
5. As the user, I want the app name unchanged, so that my home-screen icon and widget still look the same.

### Balance adjustments

6. As the user, I want editing Cash, VCB, MB or Techcombank directly to record a Money In when the balance goes up, so that history explains the increase.
7. As the user, I want editing a Liquid account directly to record a Money Out when the balance goes down, so that history explains the decrease.
8. As the user, I want a Balance adjustment's amount to be the difference between the old and new balance, so that totals add up.
9. As the user, I want Balance adjustments to get the default note "Balance adjustment", so that I can tell them apart from transactions I typed in.
10. As the user, I want an edit that doesn't change the balance to record nothing, so that history isn't cluttered.
11. As the user, I want to edit or delete a Balance adjustment like any other Money In/Out, so that there are no special cases to remember.
12. As the user, I want MB investment edits to stay Balance updates (with previous and new values), so that my investment's value changes are tracked as revaluations rather than cashflow.

### MB investment

13. As the user, I want "MB fund" renamed to "MB investment" everywhere (accounts list, history, filters, CSV), so that it's never confused with a Fund.
14. As the user, I want MB investment to keep counting toward Total Money, so that my net worth is unchanged by the rename.

### Funds

15. As the user, I want the Accounts & Balances screen to show the total of all Funds next to Total Money, and a Funds row in the Asset Breakdown, so that I see how much is set aside at a glance.
16. As the user, I want tapping the Funds row to open a Funds page, so that I can manage each Fund.
17. As the user, I want to add a Fund with a name and an amount, so that I can set money aside for a new purpose.
18. As the user, I want to tap a Fund to edit its name or amount, so that I can keep it current.
19. As the user, I want Fund amounts typed in k like everywhere else (`50` = 50,000 đ), so that input is consistent.
20. As the user, I want Fund names to be required and unique, so that I can't create confusing duplicates.
21. As the user, I want Funds listed in the order I created them, so that the list is stable.
22. As the user, I want to swipe a Fund left and confirm to delete it, so that deleting is quick and still deliberate.
23. As the user, I want a deleted Fund to go to Trash, so that I can get it back.
24. As the user, I want Money Left = Total Money − sum of all Funds, so that it shows what is truly free to spend.
25. As the user, I want Money Left shown in red when it's negative, so that over-committing is obvious.
26. As the user, I want Fund changes kept out of Transaction History, so that history only shows money actually moving.
27. As the user, I want my existing Backup Fund amount to appear as a Fund named "Backup", so that nothing is lost in the change.

### Swipe to delete

28. As the user, I want to swipe a Recent Transactions tile left to delete it, so that I can remove a mistake straight from the Finance screen.
29. As the user, I want the same swipe on the Transaction History page, so that deleting works the same everywhere.
30. As the user, I want a confirmation dialog before a swipe deletes anything, so that an accidental swipe doesn't lose data.
31. As the user, I want cancelling the dialog to put the tile back exactly as it was, so that nothing changes.
32. As the user, I want the small edit and delete buttons removed from tiles, so that tiles are cleaner; tapping a tile still opens edit.

### Trash

33. As the user, I want deleted transactions and Funds to go to Trash instead of disappearing, so that every delete can be undone.
34. As the user, I want deleting a transaction to reverse its effect on the balance immediately, so that balances stay correct while it's in Trash.
35. As the user, I want to open Trash from a Trash row in the Settings & Data section of the Accounts & Balances screen, with a badge counting its items, so that it's easy to find.
36. As the user, I want Trash to show each item with what it is, when it was deleted, and how many days are left, so that I know what I'm restoring.
37. As the user, I want to restore a transaction and have its amount applied to the current balance again, so that the books are consistent (restoring a −80 Cash expense takes current Cash down by 80, not back to its old value).
38. As the user, I want a restored transaction to keep its original date and note, so that it lands back where it was in history.
39. As the user, I want to restore a Fund with its name and amount, so that I can undo a deleted set-aside.
40. As the user, I want restoring a Fund whose name is now taken to be blocked with a clear message, so that names stay unique.
41. As the user, I want items in Trash removed for good after 30 days, so that Trash doesn't grow forever.
42. As the user, I want to "Delete forever" a single item, with confirmation, so that I can clean up early.
43. As the user, I want to "Empty trash", with confirmation, so that I can clear everything at once.

### Bank icons

44. As the user, I want each account shown with its bank's symbol (VCB logo, MB star, Techcombank double-diamond), so that I can recognise accounts instantly.
45. As the user, I want only the symbol, with a transparent background and no wordmark, so that it looks right in light and dark themes.
46. As the user, I want MB investment shown with the MB star, so that it's clearly an MB product.
47. As the user, I want Cash shown with a wallet icon, so that every account has an icon.
48. As the user, I want icons in the Money In/Out account dropdown, so that I pick the right account quickly.
49. As the user, I want icons in the Accounts list, so that the balances screen is easy to scan.
50. As the user, I want icons on transaction tiles in Recent Transactions and Transaction History, so that I see the account at a glance.
51. As the user, I want icons in the history account filter, so that filtering is consistent with the rest.

### History date filter

52. As the user, I want a single date pill on the history page showing "All time" by default, so that the filter row is tidy.
53. As the user, I want tapping the date pill to open a bottom sheet with All time, Today, This week, This month and "Pick range…", so that every option is in one clean place.
54. As the user, I want "This week" to mean Monday to today, so that it matches the calendar week.
55. As the user, I want "Pick range…" to open a date range picker, with the chosen range shown on the pill, so that I can see what's applied.
56. As the user, I want "Reset filters" to bring the date back to All time, so that resetting is complete.
57. As the user, I want the type filter's "Updates" option to show only MB investment Balance updates, so that it still has a meaning.

### Amount entry

58. As the user, I want the amount field to show `đ` instead of a dollar icon, so that the currency is right.
59. As the user, I want to keep typing amounts in thousands (`50` = 50,000 đ) with the full-VND preview below, so that entry stays quick.

### Data conversion

60. As the user, I want my old Updates on Cash, VCB, MB and Techcombank converted to Money In or Money Out, so that my whole history follows the new rules.
61. As the user, I want converted records to keep their original note, date, and before/after values, so that no information is lost.
62. As the user, I want every balance exactly the same before and after the conversion, so that I can trust it.
63. As the user, I want old Backup Fund history records removed without changing any balance, so that history only shows money moving.
64. As the user, I want "MB fund" records and balances renamed to MB investment, so that the history is consistent.
65. As the user, I want the conversion to run only once, so that opening the app repeatedly never changes data.
66. As the user, I want a raw backup of my data saved before conversion, so that it can be recovered if anything goes wrong.
67. As the user, I want a failed conversion to leave my data untouched, so that a bug can't corrupt my finances.

### CSV export

68. As the user, I want the CSV export to list MB investment, one row per Fund, and a Funds total, so that the export matches the app.
69. As the user, I want trashed items left out of the CSV, so that the export shows only live data.
70. As the user, I want to export from an "Export CSV" row in Settings & Data and choose either "Save to folder" (system save dialog) or "Share" (system share sheet), so that the file goes where I want.
71. As the user, I want each exported transaction to carry its full date and time, so that an import puts it back at the same moment.

### CSV import

72. As the user, I want to import a CSV made by the export from an "Import CSV" row in Settings & Data, so that I can restore my data on a new or reinstalled phone.
73. As the user, I want to see what the file holds (transactions, Funds, Total Money) and what it will replace before confirming, so that I don't overwrite my data by accident.
74. As the user, I want the import to replace my balances, transactions and Funds, and to leave Trash alone, so that the result matches the export.
75. As the user, I want exports made before the time column existed to import too, with each transaction at the start of its day, so that my old exports are still useful.
76. As the user, I want a file that isn't a finance export rejected with a clear message and nothing changed, so that a wrong pick is harmless.
77. As the user, I want my data from just before the import kept aside on the device, so that it can be recovered by hand if the import was a mistake.

### Money In / Money Out look

78. As the user, I want Money In tiles in blue with an arrow pointing in (↙) and a `+`, so that money arriving stands out.
79. As the user, I want Money Out tiles in magenta with an arrow pointing out (↗) and a `−`, so that spending stands out, and direction reads even without color.
80. As the user, I want Money In and Money Out tiles lightly tinted with a colored border, and Balance updates left plain, so that cashflow and revaluations look different at a glance.

## Implementation Decisions

- **Journal removal**: delete the journal provider, model, storage, screens, widgets, and the journal half of the CSV service, and the main shell's tab bar. The theme-mode setting (currently held by the journal provider) moves to a small settings holder used by the app root and toggled from the Accounts & Balances screen. Journal keys in SharedPreferences are left in place, unread, except the theme key `gtj_is_dark_mode`, which the settings holder reuses so the saved theme carries over.
- **Accounts model**: the balances model replaces `mbFund` with `mbInvestment` and drops `backupFund`. Account names used as transaction `account` strings: `Cash`, `VCB`, `MB`, `Techcombank`, `MB investment`. Liquid accounts are the first four. Total Money = Liquid accounts + MB investment.
- **Funds model**: a new Fund entity `{id, name, amount (k), createdAt}`, stored as an ordered list under its own SharedPreferences key. Money Left = Total Money − Σ Fund amounts, computed by the provider (it needs both balances and Funds).
- **Provider interface** (FinanceProvider stays the single seam):
  - Direct balance edit: for a Liquid account, records Money In/Out of `|new − old|` with note "Balance adjustment" (custom note if given) and previous/new values; for MB investment, records a Balance update; no-op if unchanged.
  - Funds: add, update (name/amount), delete (→ Trash); reject empty or duplicate names (case-insensitive, trimmed).
  - Transactions: delete moves to Trash after reversing the balance effect; edit unchanged.
  - Trash: list, restore (transaction: re-apply its delta to current balance, keep original date/note/id; Fund: re-add if name is free, otherwise fail with a reason), delete forever, empty. Each trashed item stores `deletedAt`.
  - Purge: on load, drop Trash items whose `deletedAt` is more than 30 days before "now".
  - A `ready` future that completes when loading (including conversion and purge) is done.
  - An optional injected clock (`DateTime Function() now`), defaulting to `DateTime.now`.
- **Trash storage**: one SharedPreferences key holding a list of tagged entries (`kind: transaction | fund`, `deletedAt`, `payload`).
- **Conversion** (runs during load, gated by a stored data-version number; current data has no version and is treated as v1, target v2):
  1. Copy the raw balances and transactions strings to backup keys first.
  2. Rename `mbFund` → `mbInvestment` in balances, and `account: "MB fund"` → `"MB investment"` in transactions.
  3. For `fieldUpdate` records on Liquid accounts: type becomes `moneyIn` if `newValue > previousValue`, `moneyOut` if lower; amount = `|newValue − previousValue|`; note, date, id, previous/new values kept. Records without both values fall back to their stored amount and keep their type if direction can't be determined (they stay `fieldUpdate`).
  4. Remove `fieldUpdate` records with `account: "Backup Fund"`, without adjusting balances.
  5. Create a Fund named "Backup" with the old `backupFund` amount if it's greater than 0.
  6. Write everything, then set the version to 2. Any exception → keep the original in-memory data, don't write, don't bump the version, log the error.
- **Date presets**: pure functions returning a start/end range for Today, This week (Monday 00:00 → end of today), This month, given "now". The history screen uses them; All time = no range.
- **History UI**: one date pill (label: "All time", preset name, or `dd/MM – dd/MM`) opening a modal bottom sheet with the presets as selectable rows (current one checked) and a "Pick range…" row that opens the date range picker.
- **Swipe to delete**: transaction tiles (and Fund rows) are wrapped in a dismissible, end-to-start only, whose confirm callback shows the confirmation dialog and only lets the swipe finish when the user confirms. Tap still opens edit. Edit/delete icon buttons are removed from tiles.
- **Bank icons**: transparent square PNGs cropped to the symbol (VCB as-is; MB star; Techcombank double-diamond), added as Flutter assets. A single account-icon widget maps an account name to its asset (Cash → wallet material icon, MB investment → MB star) and is used in the dropdown, Accounts list, tiles, and history account filter.
- **Money In/Out colors**: theme colors `lightMoneyIn`/`darkMoneyIn` (blue) and `lightMoneyOut`/`darkMoneyOut` (magenta), chosen to sit either side of the iris primary. The transaction tile picks icon, color, label and sign from the transaction type in one place.
- **Amount field**: the dollar prefix icon is replaced by a `đ` text prefix; the suffix becomes `k`; the full-VND helper preview stays. The balance-edit dialog uses the same treatment.
- **Screen layout**: the Finance screen has the header drawing, Money In / Money Out buttons and Recent Transactions; its top bar has only the info icon. The Accounts & Balances screen has, in order: the Money Left summary (with Total Net Worth and Funds), Accounts, Asset Breakdown (Total Money, Funds → Funds page, Money Left), Settings & Data (Dark mode, Trash, Export CSV, Import CSV), and credits.
- **CSV export**: the summary lists Cash, VCB, MB, Techcombank, MB investment, Total Money, one row per Fund, Funds total, Money Left. The transactions log has the columns `date, type, account, amount_k_vnd, amount_vnd, note, previous_value_k_vnd, new_value_k_vnd, datetime` (`datetime` is ISO 8601). Trash is not exported. The CSV encoding and decoding are pure functions with no platform dependencies; saving and sharing the file are a separate service.
- **CSV import**: reads a file picked with the system file picker (any type, since CSV filters hide valid files on some Android devices), decoded as UTF-8 with an optional BOM and CRLF or LF line ends. The transactions log is read by column name, so older exports without `datetime` still load (the `date` column is used, at 00:00). Funds are read from the `Fund: ` rows. Every imported transaction and Fund gets a new id, so they can never collide with items in Trash; Funds keep the file's order and all get the import time as their creation time. Any missing section, missing balance row, missing column, or unreadable date, type or amount rejects the whole file. After the user confirms, the raw stored balances, transactions and Funds are copied to `<key>_before_import` (replacing any earlier copy), then replaced. Trash is untouched.

## Testing Decisions

- Good tests assert only externally visible behaviour (balances, Money Left, transaction list contents and types, Funds list, Trash contents, CSV text, what survives a reload), never private fields or call order.
- **Main seam: FinanceProvider over mocked SharedPreferences.** Tests seed `SharedPreferences.setMockInitialValues`, build the provider (with an injected clock where time matters), and `await provider.ready`. Replace the existing 50 ms delays with `ready`.
- **Conversion tests** (seed v1-format JSON):
  - increases become Money In, decreases become Money Out, with correct amounts; notes, dates, ids, and previous/new values kept;
  - every balance is identical before and after;
  - replay check: summing every transaction's signed effect per account from zero equals the current balance, for every account where that held before conversion;
  - MB fund → MB investment in both balances and records; its records stay Balance updates;
  - Backup Fund records removed with no balance change; Backup Fund amount becomes a "Backup" Fund; zero Backup Fund creates no Fund;
  - a converted record can then be edited, deleted, and restored like a native one;
  - running the load twice (and a fresh provider on converted data) changes nothing;
  - partial records (missing previous/new values, or an unknown account) don't crash and are left as they are, and the conversion still completes and sets the version;
  - malformed data (bad JSON, or entries that aren't records) doesn't crash, writes nothing, and doesn't bump the version;
  - backup keys hold the original raw strings.
- **Behaviour tests** through the provider: Balance adjustments for each direction and the no-op case; MB investment Balance update; Fund add/edit/delete/validation; Money Left including negative; transaction delete → Trash with balance reversal; restore re-applies to current balance; Fund restore with a name clash fails; delete forever; empty; purge at exactly >30 days using the injected clock; everything survives a reload.
- **Date preset functions**: This week starts on Monday (test with "now" on a Monday, a mid-week day, and a Sunday), This month boundaries, Today.
- **CSV**: extend the existing export test for MB investment, Fund rows, Funds total, and no Trash. Import tests: a round trip through export and import reproduces the data (ids aside); an older export without `datetime`, with CRLF and a BOM, loads; non-exports are rejected; importing keeps Trash, copies the old data aside, survives a reload, and a restored Trash item never shares an id with an imported one.
- **One widget test**: swipe a transaction tile left → dialog appears → Cancel leaves it in place → swipe again → Confirm moves it to Trash.
- Prior art: the existing provider and CSV tests already use mocked SharedPreferences. The journal tests are deleted along with the journal.

## Out of Scope

- Renaming the app or changing the home-screen widget beyond keeping it working with the new model.
- Switching to typing full VND amounts (amounts stay in k).
- Logging Fund changes in history.
- Restoring by setting a balance back to its old value (restore always applies the amount to the current balance).
- Wiping old journal data from the device.
- Merging an import with existing data (import always replaces).
- Converting CSVs exported before the revamp on import: a file with an `MB fund` row is rejected, and a `Backup Fund` row is not turned into a Fund.
- Icons for accounts other than the five fixed ones; user-defined accounts.

## Further Notes

- Amounts remain stored in thousands of đồng ("k"); see `CONTEXT.md`.
- The conversion rewrites old history and is hard to undo. Recording it as an ADR (`docs/adr/0001-balance-edits-become-money-in-out.md`) was offered and is pending the user's answer.
- Per the user's global rule, implementation must not run `git commit`; changes are left for the developer to review.
