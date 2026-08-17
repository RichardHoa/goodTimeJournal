# 01: Finance-only app, MB investment, and Balance adjustments

**What to build:** The app opens straight to Finance with no journal and no bottom tab bar, and theme switching still works, now from a Dark mode switch on the Accounts & Balances screen. "MB fund" becomes **MB investment** everywhere, and it still counts toward **Total Money**. Editing a **Liquid account** directly records a **Balance adjustment**: a Money In when the balance goes up, a Money Out when it goes down. Editing MB investment directly still records a **Balance update**. Existing data is converted once and safely to the new rules, with a raw backup saved first.

Spec: `.scratch/finance-only-revamp/spec.md`. This ticket covers user stories 1–14, 57, 60–62 and 64–67.

**Blocked by:** None (can start immediately)

**Status:** resolved: fully completed, no further work needed.

## Scope

1. **Prefactor:** FinanceProvider exposes a `ready` future that completes when loading is done (conversion included). It also accepts an optional injected clock (`DateTime Function() now`, defaulting to `DateTime.now`). Existing finance tests switch from fixed delays to `await provider.ready`.
2. **Finance-only app:** delete the journal provider, model, storage, screens and widgets, the journal half of the CSV service, the main shell's tab bar, and the journal tests. Theme mode moves to a small settings holder: the app root reads it, and the Dark mode switch in the Settings & Data section of the Accounts & Balances screen toggles it. Journal keys in SharedPreferences stay on the device, unread. The one exception is the theme key `gtj_is_dark_mode`: the settings holder reuses it, so the saved theme carries over. The app name and home-screen widget stay as they are.
3. **MB investment rename and versioned conversion:** the balances model replaces `mbFund` with `mbInvestment`, and the account name becomes "MB investment" in the accounts list, history, filters and CSV. The conversion runs during load and is gated by a stored data version: data with no version counts as v1, and the target is v2. It copies the raw balances and transactions strings to backup keys first, then renames the field in balances and the account in transactions, writes everything, and only then sets the version. Any exception means the original in-memory data is kept, nothing is written, the version is not bumped, and the error is logged. Ticket 02 adds its own conversion steps for the Backup Fund to this same pipeline. Leave `backupFund` in the model for now.
4. **Balance adjustments:** a direct edit to a Liquid account records a Money In or Money Out of `|new − old|`, with the note "Balance adjustment" (or the custom note if one is given) and the previous and new values. An edit that leaves the balance unchanged records nothing. A direct edit to MB investment records a Balance update. A Balance adjustment can be edited and deleted like any other Money In or Money Out. The conversion turns old `fieldUpdate` records on Liquid accounts into `moneyIn` or `moneyOut` by direction, with amount `|new − previous|`, keeping the note, date, id and previous/new values. Records that don't have both values keep their stored amount and stay `fieldUpdate`. The history type filter's "Updates" option shows only MB investment Balance updates.

## Acceptance criteria

- [x] FinanceProvider has a `ready` future and an injectable clock, and no test uses fixed delays to wait for loading
- [x] The app opens straight to Finance with no tab bar, and the journal code and journal tests are gone
- [x] Light/dark theme can be toggled from the Accounts & Balances screen (Settings & Data → Dark mode)
- [x] Journal keys are left in SharedPreferences untouched (except `gtj_is_dark_mode`, which the settings holder reuses for the theme)
- [x] "MB fund" appears nowhere in the UI or CSV, MB investment is shown in its place, and it counts toward Total Money
- [x] Editing a Liquid account up records a Money In for the difference, with note "Balance adjustment" and previous/new values
- [x] Editing a Liquid account down records a Money Out for the difference
- [x] An edit with no change records nothing
- [x] Editing MB investment records a Balance update with previous/new values
- [x] The history "Updates" filter shows only MB investment Balance updates
- [x] Conversion tests seed v1 JSON and cover:
  - increases become Money In and decreases become Money Out, with correct amounts, and notes, dates, ids and previous/new values are kept
  - every balance is identical before and after
  - replay check: summing each account's signed transaction effects from zero equals its current balance, for every account where that held before conversion
  - MB fund becomes MB investment in balances and records, and its records stay Balance updates
  - a converted record can be edited and deleted like a native one
  - loading twice, or loading a fresh provider on converted data, changes nothing
  - partial records (missing previous/new values, or an unknown account) don't crash and are left as they are, and the conversion still completes and sets the version
  - malformed data (bad JSON, or entries that aren't records) doesn't crash, writes nothing, and doesn't bump the version
  - backup keys hold the original raw strings
- [x] Analyzer is clean and the full test suite passes

## Comments

**2026-10-03 — implemented (uncommitted, awaiting developer review).**
- Conversion lives in `lib/services/finance_migration.dart` as an ordered list of steps keyed by target version; ticket 02 adds its Backup Fund steps there.
- Extra fixes found during the work: editing an MB investment Balance update no longer moves it onto Cash; unreadable stored data is copied to `<key>_unreadable` before the next save overwrites it.
- Left for later: `updateAccountField` / `TransactionType.fieldUpdate` names and the repeated account-name switches (a typed account fits ticket 02's account-icon work). The account-name switches have since been replaced by `AccountBalances.of` / `adjusted` (see 03); the naming was left as is.

**2026-10-03 — closed as complete.** Some of this work was built differently from what this ticket first described, and some was done outside any ticket. The developer has confirmed that's fine: the ticket now describes the app as it is, every acceptance criterion is met, and nothing further is needed.
- The theme toggle moved from the Finance top bar to the Accounts & Balances screen (done outside this ticket, see 03).
