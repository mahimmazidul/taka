# The flag, in real days

One concern, stated plainly: **money set aside and money borrowed look the same
to the nudge, and only one of them is really yours.**

The nudge is that quiet line on Home: *"৳ 990 this week · ৳ 250 a day left"*.
It is `money on hand ÷ days left in the month`. It is also the only place the app
tells you what you may spend today. So whatever goes into "money on hand" decides
what the app tells you to do tomorrow.

That is fine. It is the whole point of money on hand. The issue is narrower than
that, and it shows up in four ordinary days.

---

## Day 1 — the pot is right

Friday. Allowance ৳8,500 came on the 30th; ৳990 spent so far; nothing lent.
You set ৳2,000 aside for a laptop on the 28th.

```
money on hand = 8,500 − 990 − 2,000 = 5,510
days left = 1 (the 31st)
nudge      = ৳5,510 for today
```

Honest. The ৳2,000 is in the pot, not in your pocket. If the nudge said ৳7,510
you would spend ৳2,000 that you had decided not to touch. **This case is why the
change is right,** and it is why I did not make the pot invisible to the nudge.

## Day 2 — the same treatment given to borrowed money

The 1st. November's allowance has not arrived. Yesterday you borrowed ৳500 from
Rahim for a bike repair, and you set ৳3,000 aside last week.

```
money on hand = 0 − 0 + 500 borrowed − 0 − 3,000 pot = −2,500
nudge      = "nothing left for this month"
```

The app is technically right (you owe ৳500 and have ৳3,000 locked away), but it
is describing two different kinds of "not in my pocket" in one number:

- the ৳3,000 is **yours, by choice** — you can take it back in two taps;
- the ৳500 is **not yours at all** — it is Rahim's, and taking it "back" is not a
  thing.

A negative nudge reads as *"you are broke"* when the true sentence is *"you have
৳3,000 saved and owe ৳500 — you are neither broke nor free."* The number collapses
that distinction, and the only lever the user has to fix the scary line is to
raid the pot, which is exactly the habit the pot exists to break.

## Day 3 — the pot stops being a pot

Mid-month. Allowance ৳8,500, spent ৳6,000, nothing lent or borrowed. Days left: 9.

```
without a pot: 2,500 ÷ 9 = ৳277 a day
with ৳2,000 set aside: 500 ÷ 9 = ৳55 a day
```

৳55 a day in a hall is one plate of rice and nothing else. So on day three you
take the ৳2,000 back — not because you needed it, but because the app made the
day look unsurvivable. The pot survived exactly as long as the first tight week.

Both numbers are arithmetically correct. The problem is tone: the pot is a
*commitment*, and the nudge spends commitments like cash. If savings is to mean
anything, the line that governs today should not be able to eat it.

## Day 4 — the pot swallows a real problem

Worst case, and it takes one bad month to reach. Spent ৳9,200 against ৳8,500 in,
৳1,500 set aside:

```
money on hand = 8,500 − 9,200 − 1,500 = −2,200
```

You are ৳700 over budget and ৳1,500 into your savings, so the app says you are
৳2,200 short. True — but only one of those two numbers is a thing to fix this
week. The overspend is a warning; the pot is a decision you are allowed to
reverse. Added together they become an alarm with no instruction attached.
Conclusion: **the pot should not be able to hide a genuine overspend behind a
bigger negative number**, and it should not be able to scare you out of a
decision you made on purpose.

---

## What I would actually do about it

Not "ignore the pot" — Day 1 shows that is wrong. Two smaller fixes:

**A. Keep the pot out of the nudge, but not out of Home.** The hero stays
*money on hand* with the pot already deducted (it is the honest pocket number),
and the nudge divides **only what is spendable without touching the pot**. Then
Day 3 reads `৳ 277 a day, and ৳ 2,000 set aside` instead of ৳55, and Day 2 reads
`nothing left to spend · ৳ 3,000 saved · ৳ 500 owed` instead of a flat negative.
Same maths, two sentences instead of one collapsed one. This is the change I'd
make first — it is the smallest and it fixes Days 2, 3 and 4 together.

**B. If the pot stays in the nudge, give it a floor.** Never let the nudge go
negative because of savings alone: show `৳ 0 a day` and a separate line saying
the pot is what is keeping it there. It keeps Day 1's honesty and removes Day 2's
false alarm, but Day 3 — the raiding — remains. So A is better than B.

**Neither is a bug today.** Under the pot as built, the app is telling the truth;
it is telling it in one number where the situation has two. That is a wording and
division problem, not an arithmetic one, which is why I shipped the arithmetic
and flagged the sentence.
