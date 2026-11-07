"""Orographic precipitation by the linear theory of Smith and Barstad (2004), as implemented in PISM's
OrographicPrecipitationSerial and the LinearTheoryOrographicPrecip R package (checked 7 Nov 2026):

  P_hat(k, l) = Cw * i*sigma * h_hat / ((1 - i*m*Hw) (1 + i*sigma*tau_c) (1 + i*sigma*tau_f))
  sigma = u*k + v*l (intrinsic frequency, k and l angular wavenumbers)
  m^2 = (Nm^2 - sigma^2) (k^2 + l^2) / sigma^2 (no Coriolis), m = sign(sigma) sqrt(m^2) when m^2 >= 0, else the complex root
  Hw = -Rv T^2 / (L gamma), Cw = rho_s_ref * Gamma_m / gamma
  P = max(P_background + P_oro, 0)

Units: h in m, wind in m/s, times in s; P_oro comes out in kg m^-2 s^-1 = mm/s. Windward slopes get more rain, lee slopes
less (rain shadow). Stage A4 of docs/water/watershed_rebuild_design.md."""
import numpy as np

T_REF = 280.15          # K (7 C at the ground)
GAMMA = -6.5e-3         # K/m environmental lapse rate
GAMMA_M = -5.0e-3       # K/m moist adiabatic lapse rate
L_HEAT = 2.5e6          # J/kg
R_V = 461.0             # J/(kg K)
G = 9.81
RHO_S_REF = 7.4e-3      # kg/m3 saturation vapour density at T_REF


def precipitation_mm_per_year(h, dx, wind_u, wind_v, background_mm_yr, tau_c=1000.0, tau_f=1000.0, pad=0.5, clip=True):
    """h: 2-D heights (m, sea <= 0 is set to 0), dx: cell size (m), wind (m/s), background_mm_yr: rain far from relief.
    Returns the rate the linear theory gives WHILE moist air is lifted (a storm-time rate), expressed in mm per year, on the
    same grid; never below 0 when clip is True. It is not an annual total: over a year, multiply the orographic part by the
    share of the year with such flow (inputs.py storm_share). Treating it as an annual total gave rain about three times too
    heavy on the first R1 run (13,300 mm/yr peak)."""
    hz = np.maximum(np.asarray(h, np.float64), 0.0)
    nz, nx = hz.shape
    pz, px = int(nz * pad), int(nx * pad)
    hp = np.pad(hz, ((pz, pz), (px, px)), mode='constant')
    Hw = -R_V * T_REF ** 2 / (L_HEAT * GAMMA)
    Cw = RHO_S_REF * GAMMA_M / GAMMA
    Nm = np.sqrt(abs(G / T_REF * (GAMMA - GAMMA_M)))
    k = 2.0 * np.pi * np.fft.fftfreq(hp.shape[1], dx)
    l = 2.0 * np.pi * np.fft.fftfreq(hp.shape[0], dx)
    K, Lw = np.meshgrid(k, l)
    sigma = wind_u * K + wind_v * Lw
    eps = 1e-18
    s2 = np.where(np.abs(sigma ** 2) < eps, eps, sigma ** 2)
    m2 = (Nm ** 2 - sigma ** 2) * (K ** 2 + Lw ** 2) / s2
    m = np.sqrt(m2.astype(np.complex128))
    m = np.where((m2 >= 0) & (sigma != 0), np.sign(sigma) * m, m)
    denom = (1.0 - 1j * m * Hw) * (1.0 + 1j * sigma * tau_c) * (1.0 + 1j * sigma * tau_f)
    denom = np.where(np.abs(denom) < eps, eps, denom)
    p_hat = Cw * 1j * sigma * np.fft.fft2(hp) / denom
    p = np.real(np.fft.ifft2(p_hat))[pz:pz + nz, px:px + nx]    # mm/s
    out = background_mm_yr + p * 3600.0 * 24.0 * 365.25
    return np.maximum(out, 0.0) if clip else out
