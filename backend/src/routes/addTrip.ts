import { Router, Request, Response } from "express";
import { validateTripRequest } from "../middleware/validate";
import { calculateCarbon } from "../emissionCalculator";
import { insertTrip } from "../tripStore";
import { generateInsights, generateCoachingTip, generateWeeklyAnalysis } from "../aiInsights";
import { createClient } from "@supabase/supabase-js";

const router = Router();

// POST /add-trip — main trip submission
router.post("/add-trip", validateTripRequest, async (req: Request, res: Response): Promise<void> => {
  const { distance, fuel_type, idle_time, load_weight, engine_efficiency, ignition_time, language, user_id, company_id } = req.body;
  const engineEff: number = engine_efficiency ?? 10;

  const carbon = calculateCarbon(distance, fuel_type as "diesel" | "petrol", idle_time, engineEff);

  const [insights] = await Promise.all([
    generateInsights({
      distance, fuelType: fuel_type, idleTime: idle_time,
      loadWeight: load_weight, engineEfficiency: engineEff,
      carbonKg: carbon, ignitionTimeMinutes: ignition_time ?? 0,
      language: language ?? 'en',
    }),
    insertTrip({ distance, idle_time, fuel_type, carbon_kg: carbon, engine_efficiency: engineEff, user_id, company_id })
      .catch((err) => console.error("Failed to persist trip record:", err)),
  ]);

  res.status(200).json({
    carbon,
    insights: insights.text,
    efficiencyScore: insights.efficiencyScore,
    moneySavedEstimate: insights.moneySavedEstimate,
    comparisonToAverage: insights.comparisonToAverage,
    nextTripRecommendation: insights.nextTripRecommendation,
  });
});

// POST /coaching-tip — real-time AI tip during trip
router.post("/coaching-tip", async (req: Request, res: Response): Promise<void> => {
  const { idle_minutes, speed_kmh, distance_km, language } = req.body;
  const tip = await generateCoachingTip({
    idleMinutes: idle_minutes ?? 0,
    speedKmh: speed_kmh ?? 0,
    distanceKm: distance_km ?? 0,
    language: language ?? 'en',
  });
  res.json({ tip });
});

// GET /trip-history — fetch last 10 trips + AI weekly analysis
router.get("/trip-history", async (req: Request, res: Response): Promise<void> => {
  const language = req.query.language as string ?? 'en';
  const supabase = createClient(
    process.env.SUPABASE_URL ?? "",
    process.env.SUPABASE_KEY ?? ""
  );

  const { data: trips, error } = await supabase
    .from("emissions")
    .select("*")
    .order("created_at", { ascending: false })
    .limit(10);

  if (error) {
    res.status(500).json({ error: "Failed to fetch history" });
    return;
  }

  const weeklyAnalysis = trips && trips.length > 0
    ? await generateWeeklyAnalysis(trips, language)
    : "";

  res.json({ trips: trips ?? [], weeklyAnalysis });
});

export default router;
