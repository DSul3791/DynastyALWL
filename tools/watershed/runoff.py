"""Stage A5 of the watershed rebuild (docs/water/watershed_rebuild_design.md): ONE water budget for every later stage.

The erosion that shapes the valleys (stage B, evolve.py) and the rivers, lakes and groundwater that later run in them (stage C)
must use the same water, or the ground and the water disagree (principle 7; the watershed document's last never-see item).
Per cell, from the yearly rain (stage A4) and the rock at the surface (stage A3):

  evaporation  ET = P * (1 + phi - (1 + phi^w)^(1/w)),  phi = PET / P      (Fu's form of the Budyko curve)
  runoff       R  = P - ET
  quick        R * (1 - BFI(rock))   runs off over and just under the ground in storms: it cuts the valleys
  recharge     R * BFI(rock)         sinks to the groundwater and returns as baseflow and springs (stage C3)

BFI is the base flow index: the share of a river's flow that comes slowly, from storage. It is a rock property in the UK Low
Flow Studies (Institute of Hydrology 1980, report 3, table 3.3) and Bloomfield, Bricker and Newell (2011). Using it for the quick
share is an approximation: it measures streamflow at a gauge, and karst conduits can carry quick flow underground, which stage
C (sinks, losing reaches, cave springs) handles. Parameters and their sources are in params.json, section water_budget."""
import numpy as np


def bfi_by_rock_id(names, table):
    """names: {rock id: rock name} (rock.load). table: {rock name: BFI}. Returns an array indexed by rock id.
    Every rock of the geology must be in the table: an unknown rock stops the run rather than getting a made-up value."""
    top = max(names) + 1
    out = np.full(top, np.nan)
    missing = []
    for k, name in names.items():
        if name == 'air':                      # not a rock: never at the ground surface
            continue
        if name in table:
            out[k] = float(table[name])
        else:
            missing.append(name)
    if missing:
        raise SystemExit(f'runoff: no base flow index in params.json water_budget.bfi_by_rock for {sorted(set(missing))}')
    return out


def evaporation(rain_mm, pet_mm, omega):
    p = np.maximum(np.asarray(rain_mm, np.float64), 1e-6)
    phi = pet_mm / p
    return p * (1.0 + phi - (1.0 + phi ** omega) ** (1.0 / omega))


def budget(rain_mm, rock_id, bfi_table, W):
    """rain_mm: yearly rain per cell. rock_id: rock id per cell (same shape). bfi_table: bfi_by_rock_id result. W: water_budget
    parameters. Returns dict of mm/yr fields: et, runoff, quick, recharge."""
    et = evaporation(rain_mm, W['pet_mm_yr'], W['fu_omega'])
    runoff = np.maximum(rain_mm - et, 0.0)
    bfi = bfi_table[np.asarray(rock_id, np.int64)]
    return dict(et=et, runoff=runoff, quick=runoff * (1.0 - bfi), recharge=runoff * bfi)


def reference_quick_mm(background_mm, W):
    """Quick runoff of the background rain on the reference rock (an impermeable one): the unit of the erosion's discharge, so
    K keeps the meaning it had in the earlier runs, where discharge was area times the rain share."""
    et = evaporation(background_mm, W['pet_mm_yr'], W['fu_omega'])
    return float((background_mm - et) * (1.0 - W['reference_bfi']))
