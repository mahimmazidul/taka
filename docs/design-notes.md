# Design notes — where money lives

Two questions asked, two answers chosen, both built and neither pushed yet.
This file keeps the reasoning; the code keeps the behaviour. `v1.10.0` in the
working tree.

## The money model as it stands

| Thing | Is it a transaction? | Counts in In/Out? | In "money on hand"? |
|---|---|---|---|
| Expense | yes | Out | − |
| Income | yes | In | + |
| Udhar lent (open) | no — pending ledger | no | − |
| Udhar borrowed (open) | no — pending ledger | no | + |
| Carried over from last month | no — derived | no | + (it is the same money) |
| Savings set aside (pot) | no | no | − |

The rule that keeps this honest: **a transaction describes money earned or
consumed; everything else is a correction to the pocket.** Udhar follows it, and
so does savings — which is exactly why the pot is not a category.

## Decisions taken

| Question | Answer |
|---|---|
| Where does tomato sauce go? | **B** — a single top-row item `মুদি · Groceries`, `food: false`, no new group |
| Where does savings live? | **A** — a pot, never an expense category; corrected into money on hand |
| How is it reached? | A compact **Home row** (under Patterns, above Udhar) behind a **Settings toggle**, opening its own screen. No new tab. |

The rest of this file is the reasoning that produced those answers, kept in the
order it was worked out.

## 1. Buying tomato sauce — where does it go?

It is a **pantry purchase**, not a dish and not a snack. Today's groups do not
have a home for it:

- মেইন কোর্স holds dishes (ভাত, মাছ, ভর্তা…). A bottle of sauce is not a dish.
- নাস্তা holds things you eat now (চিপস, বিস্কুট, চা). Sauce is not eaten now.
- হল খরচ holds bills and rent.

Two ways to place it.

**A. New group `মুদি · Groceries` — recommended if staples are a habit.**

| Item | Bangla |
|---|---|
| Sauce & ketchup | সস |
| Oil | তেল |
| Salt & spices | লবণ-মসলা |
| Sugar | চিনি |
| Noodles packet | নুডলস প্যাকেট |
| Bread | ব্রেড |

- `isFood: false`, because buying a bottle is not breakfast. It stays out of the
  meals strip and out of Patterns → Meals, which is what you want: a purchase for
  the room is not a meal you ate.
- It still appears in *Where it went*, so the month says what the room cost.
- One extra chip on the first row, six items inside it. Nothing else changes.
- Schema v8: insert the group and the items; additive seeding already handles the
  rest.

**B. One top-row item `মুদি · Groceries` — if this is rare.**

One tap, no sub-list, no new group. Cheaper for the user, coarser for the data:
"৳ 120 groceries" is all you would ever know.

Not recommended: putting sauce under মেইন কোর্স. It would sit in the dish list
next to ভাত and pollute every "most on X" answer for the month.

## 2. Savings — a pot, not an expense

The question is not "which category" but "is saved money spent?" It is not. It is
still yours, in a different pocket. So savings should behave like udhar: a
correction to money on hand, never a line in In/Out.

**Model A — pot (recommended).**

```
savings(id, direction, amount_minor, note, occurred_at, created_at, updated_at)
direction: 'in' (set aside) | 'out' (taken back)
```

- `money on hand = earned − spent + borrowed − lent − savings balance`
- A Savings screen: balance, optional target with a thin progress line, and the
  history. Two actions: *Set aside*, *Take back*.
- Nothing in Expenses, nothing in Patterns: saving ৳ 2,000 must not look like
  spending ৳ 2,000.
- It carries across months for free — a pot has no month boundary.
- One-tap "set aside what is left" on the 1st could come later; it is the same
  decision as the carry-over nudge, and two nudges on one screen is one too many.

**Model B — a "Savings" expense category.** Cheap (it is just a category, zero new
code) and wrong in the same breath: every month would claim you spent your savings,
the per-day nudge would drop, and "where did the money go" would answer "savings"
instead of the canteen.

**Model C — target only, no money movement.** A wish with a progress bar. Honest,
tiny, and no accounting — but it cannot answer "how much do I actually have", which
is the only reason to keep savings in the same app as your wallet.

### Where it would live in the app

There is already a place for a new function — the shape udhar established:

1. one table + repository — `savings`, `db/savings_repository.dart`,
2. one derived number in `AppState` — `savingsMinor`, subtracted inside `moneyOnHand`,
3. one **Home row** that opens a full screen — `screens/savings_screen.dart`,
4. one toggle in Settings — `savingsEnabled`, default **off**,
5. tests for the maths and goldens for the screen.

All five exist now, and the sequence is the answer to "does the app have a place
to put a completely new function": yes — table, one number, one row, one switch.

Home would gain a compact row under Patterns and above Udhar:

```
SAVINGS                        Open
৳ 2,000  ·  of ৳ 5,000 for the laptop
```

No new tab. The bottom bar is already five items, and an unbounded app is the one
thing this project has refused from the start.

### One trap to decide before building

If savings have been logged as an expense category until now, turning on the pot
would count that money twice — once as spending, once as a correction. On first
run the app would have to either leave old entries as they are (and say so) or
offer to convert them. Best: leave history alone, and start the pot from zero with
a note on the screen: "older entries logged under a savings category stay as
spending".

### What building it settled

- **The pot starts at zero and says so.** No migration guesses at old savings;
  `savings` is created empty in v8. The screen reads "Nothing in the pot yet"
  rather than inventing a balance.
- **Off by default** means an existing install sees exactly the app it had
  yesterday until it asks for more. The rows live in the database either way, so
  turning the switch back on restores them.
- **Turning the pot off hands the money back to the pocket.** `savingsMinor` reads
  zero when the setting is off, so the hero number goes back up: the pot is a
  correction you can switch off, not a fact about the ledger.
- **The per-day nudge follows money on hand**, as it already did for udhar. Money
  you have set aside is not available for today's lunch, so leaving it in the
  nudge would tell you to spend money you had deliberately put away. In/Out,
  budgets and Patterns are untouched — saving never looks like spending.
- **Two half-width buttons did not fit**: `Set aside` + `Take back` side by side
  overflowed their own label at 390 dp. One full-width primary, and a quiet text
  button under it — fewer pixels, clearer order of importance.
- **Groceries is a leaf, not a group**, so the picker shows it on the first row
  next to লন্ড্রি and অন্যান্য: one tap, and the item still has an id of its own, so
  *Where it went* can name it.
