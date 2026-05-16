# Phase 3 - Pricing Engine Implementation

## Scope

Phase 3 implements the pricing layer required before DSM scheduling. It converts tariff definitions in `config/default_config.json` into time-indexed price vectors and per-household bills.

## Implemented functions

| File | Purpose |
|---|---|
| `src/pricing/build_pricing_context.m` | Builds timestamp, hour, month, season, weekend, holiday, and Ramadan features for tariffs. |
| `src/pricing/select_pricing.m` | Explicit dispatcher for all seven tariff methods. |
| `src/pricing/pricing_flat.m` | Constant EGP/kWh tariff. |
| `src/pricing/pricing_block.m` | Egyptian inclining marginal block tariff with prorated slab boundaries. |
| `src/pricing/pricing_tou.m` | 24-hour time-of-use tariff lookup. |
| `src/pricing/pricing_rtp.m` | Deterministic real-time price signal with daily, seasonal, and seeded stochastic components. |
| `src/pricing/pricing_seasonal.m` | TOU tariff multiplied by summer/winter seasonal factors. |
| `src/pricing/pricing_cpp.m` | TOU plus critical peak adder during summer evening stress periods. |
| `src/pricing/pricing_rgdp.m` | Renewable-generation-based dynamic energy price. |
| `src/pricing/compute_costs.m` | Computes household bills for all seven pricing methods. |

## Block tariff behavior

The block tariff uses marginal inclining billing:

- 0-50 kWh: 0.25 EGP/kWh
- 51-100 kWh: 0.45 EGP/kWh
- 101-200 kWh: 0.65 EGP/kWh
- 201-350 kWh: 0.95 EGP/kWh
- 351-650 kWh: 1.25 EGP/kWh
- >650 kWh: 1.65 EGP/kWh

Examples validated in `tests/test_pricing.m`:

```text
0 kWh   -> 0 EGP
50 kWh  -> 12.5 EGP
110 kWh -> 41.5 EGP
```

## Outputs from `compute_costs`

`compute_costs` returns:

```text
costs.methods
costs.bill_total.<method>
costs.bill_monthly.<method>
costs.price_series.<method>
costs.energy_monthly_kwh
costs.tariff_slab_reached
costs.ev_cost_increment
costs.month_labels
costs.metadata
```

`ev_cost_increment` is intentionally set to `NaN` at this layer because EV increment requires comparison between a no-EV baseline scenario and an EV scenario. That comparison belongs to Phase 5 scenario wrappers.

## Testing

Run:

```matlab
main([], 'validate')
```

or directly:

```matlab
test_pricing()
test_phase3_pricing()
```
