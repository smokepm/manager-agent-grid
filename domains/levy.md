# Levy rolls
Use when: the folder computes a parcel-level special tax or assessment roll (a community facilities district, an assessment district, a lighting and landscaping district, and the like).

For a levy folder, build the checks with levy-check, which knows levy rolls, in place of steps 1 to 3 of the general setup. Then do steps 4 and 5 as usual, and add the summary items at the end.

1. Find the roll this folder produces: the parcel-level levy output (.csv or .xlsx) and its columns for the APN and the levy amount, plus max tax, units, rate, and the rate class (zone, land use) if present. Look at existing outputs, any workflows in .agent-grid/workflows/, and config files. If no roll exists yet, choose output/levy_roll.csv with columns APN and Levy, and say so; the analyst's workflow will be required to write it there.
2. Find last year's certified roll, the final roll that went to the county. Look in prior fiscal-year folders and the levy software's exports. Then find last year's version of every input the levy reads (county export, rates, budget, config).
3. Run levy-check init (not agent-check init) if .agent-grid/checks.toml doesn't exist, then fill it in. Turn on a rule only if you can confirm it from the RMA or the data: max_tax only if there is a max tax column, max_tax_is_units_x_rate only if the RMA defines it that way, total only if you find this year's levy requirement in the budget, and parcels_file only if the county export lists every parcel that should be on the roll. Also fill in, where the documents support it:
   - [max_rates]: each rate class's maximum rate per unit, from the RMA (base rate, base year, escalator, and rounding) or from a district document that states this year's max. levy-check then works out the max itself instead of trusting the roll's own columns. Note the document, page, and section next to each.
   - unique_by, if a parcel can rightly appear more than once (for example one line per assessment or funding): the columns that together identify one line.
   - [totals]: expected totals by district or zone, if the budget gives them.
   You can still add protect and [[check]] entries (see the general steps) for any tests the user wrote.
4. Copy last year's certified roll and last year's inputs into .agent-grid/backtest/, and fill in [backtest] and [backtest.inputs]. Leave backtest.workflow blank unless the folder has more than one workflow. Don't change or add to last year's input files. If last year's levy depended on a decision someone made by hand (a credit, a status typed into a working file), ask the user how next year's run will get that decision. If some parcels can't be reproduced for a real reason, list each one under [backtest.known_differences] with the reason. Never excuse a whole district or zone.
5. Run levy-check on the most recent accepted roll in the folder. If a rule fails on a roll that was actually certified, don't quietly turn the rule off: either the rule doesn't fit this district or that roll had a real problem. Report it and ask. Never set up a check that requires repeating an amount over the RMA maximum: list those parcels as known differences and tell the user. Then run levy-check selftest, which plants errors in copies of the rolls (nothing on disk changes) and reports which checks catch each one. levy-check exits 0 when everything passes, 1 when a check fails, and 2 when checks.toml or a file it names can't be used.

Add to the summary:
- each known difference with its reason;
- the errors levy-check selftest reported as MISSED, in plain words: those are what these checks can't catch;
- a suggestion to hand-calculate a few parcels, one per rate class, with spawn --spot. Those stay outside the folder, where analysts can't see them.
