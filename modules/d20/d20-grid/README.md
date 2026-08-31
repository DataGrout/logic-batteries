# Module: d20-grid v1.0.0

Square-grid combat geometry: Chebyshev distance and range, Bresenham line of
sight, cover derivation with AC bonuses, forced-movement (push) resolution,
and burst areas. Standalone — no other battery required. Pairs naturally with
`d20-combat`: feed `grid_cover/3` into AC handling and `grid_los/2` into
targeting. Pure ISO — runs on SWI and Scryer alike, including ISO-pinned cells.

All mechanics are from the **SRD 5.1**, published under **CC BY 4.0** by Wizards of the Coast LLC.

## Install

```python
client.perform("data-grout@1/batteries.install_many@1", {
    "ids": ["d20-grid"],
    "namespace": "my-campaign"
})
```

## Exported Predicates

| Predicate | Description |
|---|---|
| `grid_distance(A, B, D)` | Chebyshev distance in squares (SRD basic rule: diagonals count as one) |
| `grid_adjacent(A, B)` | The two entities occupy neighbouring squares (melee reach 1) |
| `grid_in_range(A, B, Range)` | B is within Range squares of A |
| `grid_los(A, B)` | No blocking square lies strictly between the two entities |
| `grid_los_xy(X0, Y0, X1, Y1)` | Line of sight between raw squares (tile-targeted effects) |
| `grid_cover(Attacker, Target, Cover)` | `none` \| `half` \| `total` |
| `cover_ac_bonus(Cover, Bonus)` | SRD cover AC bonuses: none 0, half +2, three_quarters +5; fails on total |
| `grid_push_dest(Attacker, Target, X, Y)` | The square one step directly away; fails if blocked or occupied |
| `grid_in_burst(CX, CY, Radius, E)` | Entity E stands within Radius squares of the burst centre |
| `grid_occupied(X, Y)` | Some entity stands on the square |

## The grid model

Two fact families, both asserted by the application (retract and re-assert to
move, exactly like hp mutation elsewhere in the d20 suite):

```prolog
% entity positions — one per entity; squares are integers, no bounds imposed
grid_pos(fighter, 3, 7).
grid_pos(orc, 5, 7).

% blocking terrain (pillars, walls) — blocks movement AND sight
grid_blocked(5, 5).
```

## Usage

```python
# Can the archer see the orc?
client.perform("data-grout@1/logic.query@1", {
    "namespace": "my-campaign",
    "prolog": "grid_los(archer, orc)"
})

# What cover does the orc get, and what does that do to AC?
client.perform("data-grout@1/logic.query@1", {
    "namespace": "my-campaign",
    "prolog": "grid_cover(archer, orc, Cover), cover_ac_bonus(Cover, Bonus)"
})
# total cover makes cover_ac_bonus fail — the target cannot be attacked at all

# Where does a shove send the zombie? (fails if the square behind is taken)
client.perform("data-grout@1/logic.query@1", {
    "namespace": "my-campaign",
    "prolog": "grid_push_dest(fighter, zombie, X, Y)"
})

# Who is caught in a radius-2 burst centred on (5,5)?
client.perform("data-grout@1/logic.query@1", {
    "namespace": "my-campaign",
    "prolog": "grid_in_burst(5, 5, 2, E)"
})
```

## Rulings & scope

- **Distance is Chebyshev** — the SRD's basic "each square is 5 feet, diagonals
  count as one" rule. The optional 5-10-5 variant is not modelled.
- **Endpoints never block sight** — standing in a doorway does not blind you,
  and a creature is never behind its own square.
- **Cover** is a simplified SRD reading: `total` when the sight line is blocked
  outright; `half` when sight is clear but a blocking square adjacent to the
  target stands nearer the attacker (an obstacle the target is tucked behind).
  Three-quarters cover is accepted by `cover_ac_bonus/2` for completeness but
  is not derived in v1 — arrow slits are the application's call.
- **Pushes are one square directly away** along each axis (a diagonal shove
  pushes diagonally); blocked or occupied squares stop the push and the
  predicate fails, so the target holds its ground.
