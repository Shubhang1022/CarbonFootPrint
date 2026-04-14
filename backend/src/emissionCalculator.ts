const EMISSION_FACTORS: Record<"diesel" | "petrol", number> = {
  diesel: 2.6,
  petrol: 2.3,
};

// Base fuel consumption at reference efficiency (10 km/L)
const REFERENCE_EFFICIENCY = 10;

/**
 * Calculates carbon emissions for a trip.
 * Engine efficiency (km/L) adjusts the driving emission factor:
 * a less efficient engine burns more fuel per km → more CO₂.
 *
 * Formula:
 *   efficiency_multiplier = REFERENCE_EFFICIENCY / engine_efficiency_kmpl
 *   carbon_kg = distance * emissionFactor * efficiency_multiplier + idleTime * 0.5
 */
export function calculateCarbon(
  distance: number,
  fuelType: "diesel" | "petrol",
  idleTime: number,
  engineEfficiencyKmpl: number = REFERENCE_EFFICIENCY
): number {
  const emissionFactor = EMISSION_FACTORS[fuelType];
  const efficiencyMultiplier = REFERENCE_EFFICIENCY / engineEfficiencyKmpl;
  return distance * emissionFactor * efficiencyMultiplier + idleTime * 0.5;
}
