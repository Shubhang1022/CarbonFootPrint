import { Router, Request, Response } from "express";
import { validateTripRequest } from "../middleware/validate";
import { calculateCarbon } from "../emissionCalculator";
import { insertTrip } from "../tripStore";
import { generateInsights } from "../aiInsights";

const router = Router();

router.post("/add-trip", validateTripRequest, async (req: Request, res: Response): Promise<void> => {
  const { distance, fuel_type, idle_time, load_weight, engine_efficiency } = req.body;
  const engineEff: number = engine_efficiency ?? 10;

  const carbon = calculateCarbon(distance, fuel_type as "diesel" | "petrol", idle_time, engineEff);

  // Persist and generate AI insights in parallel
  const [insights] = await Promise.all([
    generateInsights({
      distance,
      fuelType: fuel_type,
      idleTime: idle_time,
      loadWeight: load_weight,
      engineEfficiency: engineEff,
      carbonKg: carbon,
    }),
    insertTrip({ distance, idle_time, fuel_type, carbon_kg: carbon, engine_efficiency: engineEff })
      .catch((err) => console.error("Failed to persist trip record:", err)),
  ]);

  res.status(200).json({ carbon, insights });
});

export default router;
