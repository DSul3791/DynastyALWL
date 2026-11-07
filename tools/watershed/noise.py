"""Deterministic smooth noise as a function of WORLD position (metres), the same at any grid spacing and in any frame.

A sum of plane waves: for each octave, `waves` cosines with seeded random directions and phases at the octave's wavelength,
normalised so the octave spans about -1..1. Used for the uplift variation at hill scale (stage A2): erosion turns it into
ridges and spurs with drainage between them, never into closed bumps laid on finished ground."""
import numpy as np


def plane_waves(x_m, z_m, wavelengths_m, amplitudes, seed, waves=12):
    """x_m, z_m: arrays of world coordinates (broadcastable). Returns sum over octaves of amplitude * octave in -1..1."""
    rng = np.random.RandomState(seed)
    out = np.zeros(np.broadcast(x_m, z_m).shape)
    for wavelength, amplitude in zip(wavelengths_m, amplitudes):
        k = 2.0 * np.pi / float(wavelength)
        octave = np.zeros_like(out)
        for _ in range(waves):
            theta = rng.uniform(0.0, 2.0 * np.pi)
            phase = rng.uniform(0.0, 2.0 * np.pi)
            octave += np.cos(k * (np.cos(theta) * x_m + np.sin(theta) * z_m) + phase)
        out += amplitude * octave * np.sqrt(2.0 / waves)   # a sum of n unit cosines has standard deviation sqrt(n/2)
    return out
