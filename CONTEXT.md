# Personal Finance

A single-user app for tracking money in Vietnamese đồng across a few bank accounts, cash, and an investment, plus money set aside for specific purposes.

## Language

### Money holders

**Liquid account**:
One of Cash, VCB, MB, or Techcombank: money that can be spent directly. The only places Money In and Money Out can happen.
_Avoid_: Wallet, bank, field

**MB investment**:
The investment held at MB. It counts toward Total Money, but its balance is only ever updated directly, never through Money In or Money Out.
_Avoid_: MB fund

**Fund**:
A named amount the user sets aside for a purpose (e.g. "Backup"). It is not money held anywhere; it is a claim on Total Money.
_Avoid_: Backup Fund (the single Backup Fund became the first Fund), reserve

### Totals

**Total Money**:
The sum of all Liquid accounts plus MB investment.

**Money Left**:
Total Money minus the sum of all Funds: what is free to spend.
_Avoid_: Available balance

### Records

**Money In**:
A transaction that increases one Liquid account's balance.
_Avoid_: Income, deposit

**Money Out**:
A transaction that decreases one Liquid account's balance.
_Avoid_: Expense, withdrawal

**Balance adjustment**:
A Money In or Money Out created when the user edits a Liquid account's balance directly; its amount is the difference.
_Avoid_: Field update (for Liquid accounts)

**Balance update**:
A record of a direct edit to MB investment's balance, keeping the previous and new values.
_Avoid_: Field update

**Trash**:
Where deleted transactions and Funds stay for 30 days before being removed for good; restoring one puts its effect back.
_Avoid_: Recycle bin, archive

### Units

**k**:
Amounts are entered and stored in thousands of đồng; `50` means 50,000 đ.
