import { Router, Request, Response } from "express";
import { validateTripRequest } from "../middleware/validate";
import { calculateCarbon } from "../emissionCalculator";
import { insertTrip } from "../tripStore";
import { generateInsights, generateCoachingTip, generateWeeklyAnalysis, generateFleetInsights, chatWithAssistant } from "../aiInsights";
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

// GET /fleet-analytics — fleet CO₂ + overspeeding + AI insights for owner
router.get("/fleet-analytics", async (req: Request, res: Response): Promise<void> => {
  const { company_id, period = 'week' } = req.query;
  if (!company_id) { res.status(400).json({ error: "company_id required" }); return; }

  const supabase = createClient(process.env.SUPABASE_URL ?? "", process.env.SUPABASE_KEY ?? "");
  const now = new Date();
  const periodMap: Record<string, Date> = {
    day: new Date(now.getFullYear(), now.getMonth(), now.getDate()),
    week: new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000),
    month: new Date(now.getFullYear(), now.getMonth(), 1),
    annual: new Date(now.getFullYear(), 0, 1),
  };
  const since = (periodMap[period as string] ?? periodMap.week).toISOString();

  const { data: trips } = await supabase
    .from("emissions")
    .select("*, profiles(name)")
    .eq("company_id", company_id as string)
    .gte("created_at", since)
    .order("created_at", { ascending: false });

  const safeTrips = trips ?? [];
  const totalCarbon = safeTrips.reduce((s: number, t: any) => s + (t.carbon_kg ?? 0), 0);
  const avgCarbon = safeTrips.length > 0 ? totalCarbon / safeTrips.length : 0;

  // Overspeeding: trips where max_speed > 120 (stored in emissions if available)
  const overspeedingEvents = safeTrips
    .filter((t: any) => (t.max_speed ?? 0) > 120)
    .map((t: any) => ({
      driverName: (t.profiles as any)?.name ?? 'Unknown',
      date: t.created_at?.substring(0, 10) ?? '',
      time: t.created_at?.substring(11, 16) ?? '',
      maxSpeed: t.max_speed ?? 0,
      truckNumber: t.truck_number ?? '—',
    }));

  // Top emitter
  const driverTotals: Record<string, { name: string; carbon: number }> = {};
  for (const t of safeTrips) {
    const id = t.user_id ?? 'unknown';
    const name = (t.profiles as any)?.name ?? 'Unknown';
    if (!driverTotals[id]) driverTotals[id] = { name, carbon: 0 };
    driverTotals[id].carbon += t.carbon_kg ?? 0;
  }
  const topEmitter = Object.values(driverTotals).sort((a, b) => b.carbon - a.carbon)[0]?.name ?? 'N/A';

  const aiInsights = await generateFleetInsights({
    totalCarbonKg: totalCarbon,
    driverCount: Object.keys(driverTotals).length,
    overspeedingEvents,
    topEmitter,
    avgCarbonPerTrip: avgCarbon,
  });

  res.json({ totalCarbon, avgCarbon, overspeedingEvents, topEmitter, aiInsights, tripCount: safeTrips.length });
});

// POST /ai-assistant — AI chat for owner
router.post("/ai-assistant", async (req: Request, res: Response): Promise<void> => {
  const { messages, fleet_context } = req.body;
  if (!messages || !Array.isArray(messages)) { res.status(400).json({ error: "messages array required" }); return; }
  const reply = await chatWithAssistant(messages, fleet_context ?? "No fleet context provided.");
  res.json({ reply });
});
