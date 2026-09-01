---
name: masked-error-landmine
description: When a broken function is fixed by CREATE OR REPLACE from its live definition, an error raised early can mask a second bug later in the body; find_slots' `cur := timestamptz at time zone 'UTC'` (42703) was hidden behind the 42P01 for months
metadata:
  type: feedback
---

When repairing a broken function by copying its **live** definition and changing
only the identified fault, the rest of the body has never been proven to run.
An exception raised early masks every defect after it.

**Why:** KAN-63/KAN-74 reconciliation, 2026-08-31. `public.find_slots` raised
`42P01 relation "public.venue_opening_hours" does not exist` at roughly line 22.
Ten lines further on sat:

```sql
cur := timestamptz at time zone 'UTC';
```

`timestamptz` there is a bare identifier, not a value — `42703: column
"timestamptz" does not exist`. It had never fired because the 42P01 preceded it.
Two agents independently fixed the `opening_hours` reference; one carried the
stray line forward verbatim ("rest of the function body is unchanged from the
current live definition") and would have shipped a fix that swapped one error for
another. The surviving KAN-74 file happened to drop it. Neither author noticed;
I found it only by diffing the two candidates line by line.

**How to apply:**
- Reviewing any `CREATE OR REPLACE FUNCTION` that repairs a broken function:
  read the *whole* body, not the diff region. "Unchanged from live" is a claim
  that the unchanged part works — for a function that has been erroring, it is
  an untested claim.
- Position matters more than presence. Ask whether the suspect statement sits
  before or after the early-`return` guards; a landmine after a guard fires for
  the majority of inputs, one after an unconditional `return` is dead code.
- Cheap live proof without touching prod: an anonymous `DO $$ ... $$` block
  reproduces plpgsql runtime behaviour with no DDL and nothing written. Use it
  instead of reasoning about whether an expression parses.
- When two agents hand you competing migrations, diff the *bodies*, never trust
  either author's summary of how they differ. Both summaries here said
  "identical".

Related: [[verification-lessons]], [[create-or-replace-view-resets-invoker]],
[[cto-own-ruling-corrections]].
