# Phase 3 - Pricing Engine

This folder implements the seven pricing methods required by the thesis implementation plan.

Implemented files:

```text
select_pricing.m
build_pricing_context.m
pricing_flat.m
pricing_block.m
pricing_tou.m
pricing_rtp.m
pricing_seasonal.m
pricing_cpp.m
pricing_rgdp.m
compute_costs.m
```

## Design notes

- `select_pricing` uses explicit `switch` dispatch. It does not use `eval` or `feval`.
- `pricing_block` implements the Egyptian inclining marginal slab tariff.
- `compute_costs` groups energy by billing month/period and computes per-household bills.
- Dynamic price models are deterministic and seeded from `cfg.seed` so thesis simulations are reproducible.
- RGDP demand charge is added in `compute_costs` because it depends on each household's daily peak demand.

## Validation

Run:

```matlab
main([], 'validate')
```

The Phase 3-specific tests are:

```text
tests/test_pricing.m
tests/test_phase3_pricing.m
```
