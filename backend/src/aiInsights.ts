export interface TripInsights {
  text: string;
  efficiencyScore: number;
  moneySavedEstimate: string;
  comparisonToAverage: string;
  nextTripRecommendation: string;
}

// Average driver benchmarks
const AVG_CARBON_PER_KM = 0.27; // kg CO₂/km for diesel truck at 10 km/L
const DIESEL_PRICE_PER_LITRE = 90; // INR

export async function generateInsights(tripData: {
  distance: number;
  fuelType: string;
  idleTime: number;
  loadWeight: number;
  engineEfficiency: number;
  carbonKg: number;
  ignitionTimeMinutes?: number;
  language?: string;
}): Promise<TripInsights> {
  const apiKey = process.env.OPENROUTER_API_KEY;
  const isHindi = tripData.language === 'hi';

  // Calculate efficiency score (0-100) based on multiple factors:
  // - Engine efficiency vs reference (10 km/L)
  // - Idle time ratio vs total ignition time
  // - Fuel type penalty
  const engineScore = Math.min(100, (tripData.engineEfficiency / 10) * 60); // 60% weight
  const ignitionMins = tripData.ignitionTimeMinutes ?? 1;
  const idleRatio = ignitionMins > 0 ? tripData.idleTime / Math.max(ignitionMins, 1) : 0;
  const idleScore = Math.max(0, 40 - idleRatio * 40); // 40% weight, penalise idle
  const efficiencyScore = Math.max(0, Math.min(100, Math.round(engineScore + idleScore)));

  // Money savings estimate
  const fuelUsed = tripData.distance / tripData.engineEfficiency;
  const potentialSavingLitres = fuelUsed * 0.15; // 15% saving potential
  const moneySaved = Math.round(potentialSavingLitres * DIESEL_PRICE_PER_LITRE);
  const moneySavedEstimate = isHindi
    ? `₹${moneySaved} बचाए जा सकते हैं`
    : `Save up to ₹${moneySaved}`;

  // Comparison to average
  // Comparison to average — based on carbon per km vs benchmark
  const avgCarbon = Math.max(tripData.distance * AVG_CARBON_PER_KM, 0.1);
  const diffPercent = Math.round(((tripData.carbonKg - avgCarbon) / avgCarbon) * 100);
  const comparisonToAverage = isHindi
    ? diffPercent > 0
      ? `औसत ड्राइवर से ${diffPercent}% अधिक उत्सर्जन`
      : `औसत ड्राइवर से ${Math.abs(diffPercent)}% कम उत्सर्जन`
    : diffPercent > 0
      ? `${diffPercent}% more than average driver`
      : `${Math.abs(diffPercent)}% better than average driver`;

  if (!apiKey) {
    return {
      text: isHindi ? "AI अंतर्दृष्टि अनुपलब्ध।" : "AI insights unavailable.",
      efficiencyScore,
      moneySavedEstimate,
      comparisonToAverage,
      nextTripRecommendation: isHindi ? "इंजन दक्षता सुधारें।" : "Improve engine efficiency.",
    };
  }

  const prompt = isHindi
    ? `आप एक फ्लीट सस्टेनेबिलिटी विश्लेषक हैं। इस डिलीवरी यात्रा का विश्लेषण करें।

यात्रा डेटा:
- दूरी: ${tripData.distance.toFixed(2)} km
- ईंधन: ${tripData.fuelType}
- निष्क्रिय समय: ${tripData.idleTime} मिनट
- भार: ${tripData.loadWeight} kg
- इंजन दक्षता: ${tripData.engineEfficiency} km/L
- कुल CO₂: ${tripData.carbonKg.toFixed(2)} kg
- दक्षता स्कोर: ${efficiencyScore}/100

3 संक्षिप्त बुलेट पॉइंट दें। प्रत्येक में एक विशिष्ट सिफारिश और अनुमानित CO₂ बचत हो। कुल 100 शब्दों से कम।`
    : `You are a fleet sustainability analyst. Analyze this delivery trip.

Trip data:
- Distance: ${tripData.distance.toFixed(2)} km
- Fuel: ${tripData.fuelType}
- Idle time: ${tripData.idleTime} min
- Load: ${tripData.loadWeight} kg
- Engine efficiency: ${tripData.engineEfficiency} km/L
- Total CO₂: ${tripData.carbonKg.toFixed(2)} kg
- Efficiency score: ${efficiencyScore}/100
- Ignition time: ${tripData.ignitionTimeMinutes ?? 0} min

Give exactly 3 bullet points. Each: one sentence with specific recommendation + estimated CO₂/money saving. Under 120 words total.`;

  try {
    const response = await fetch("https://openrouter.ai/api/v1/chat/completions", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${apiKey}`,
        "Content-Type": "application/json",
        "HTTP-Referer": "https://carbonchain.app",
        "X-Title": "CarbonChain",
      },
      body: JSON.stringify({
        model: "openai/gpt-4o-mini",
        messages: [{ role: "user", content: prompt }],
        max_tokens: 250,
        temperature: 0.7,
      }),
    });

    if (!response.ok) {
      console.error("OpenRouter error:", response.status);
      return { text: "AI insights temporarily unavailable.", efficiencyScore, moneySavedEstimate, comparisonToAverage, nextTripRecommendation: "" };
    }

    const data = await response.json() as any;
    const text = data.choices?.[0]?.message?.content ?? "";

    // Extract next trip recommendation (last bullet point)
    const lines = text.split('\n').filter((l: string) => l.trim().startsWith('-') || l.trim().startsWith('•'));
    const nextTripRecommendation = lines[lines.length - 1]?.replace(/^[-•]\s*/, '') ?? "";

    return { text, efficiencyScore, moneySavedEstimate, comparisonToAverage, nextTripRecommendation };
  } catch (err) {
    console.error("AI insights error:", err);
    return { text: "AI insights temporarily unavailable.", efficiencyScore, moneySavedEstimate, comparisonToAverage, nextTripRecommendation: "" };
  }
}

// Real-time coaching tip during trip
export async function generateCoachingTip(data: {
  idleMinutes: number;
  speedKmh: number;
  distanceKm: number;
  language?: string;
}): Promise<string> {
  const apiKey = process.env.OPENROUTER_API_KEY;
  if (!apiKey) return "";

  const isHindi = data.language === 'hi';
  const prompt = isHindi
    ? `एक वाक्य में ड्राइवर को सुझाव दें। निष्क्रिय: ${data.idleMinutes} मिनट, गति: ${data.speedKmh.toFixed(0)} km/h, दूरी: ${data.distanceKm.toFixed(1)} km। सरल हिंदी में।`
    : `Give one short driving tip (max 15 words). Idle: ${data.idleMinutes} min, speed: ${data.speedKmh.toFixed(0)} km/h, distance: ${data.distanceKm.toFixed(1)} km.`;

  try {
    const response = await fetch("https://openrouter.ai/api/v1/chat/completions", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${apiKey}`,
        "Content-Type": "application/json",
        "HTTP-Referer": "https://carbonchain.app",
        "X-Title": "CarbonChain",
      },
      body: JSON.stringify({
        model: "openai/gpt-4o-mini",
        messages: [{ role: "user", content: prompt }],
        max_tokens: 40,
        temperature: 0.8,
      }),
    });
    const data2 = await response.json() as any;
    return data2.choices?.[0]?.message?.content?.trim() ?? "";
  } catch {
    return "";
  }
}

// Weekly analysis from trip history
export async function generateWeeklyAnalysis(trips: any[], language?: string): Promise<string> {
  const apiKey = process.env.OPENROUTER_API_KEY;
  if (!apiKey || trips.length === 0) return "";

  const isHindi = language === 'hi';
  const summary = trips.map((t, i) =>
    `Trip ${i + 1}: ${t.distance?.toFixed(1)}km, ${t.idle_time}min idle, ${t.carbon_kg?.toFixed(1)}kg CO₂`
  ).join('\n');

  const prompt = isHindi
    ? `इन ${trips.length} यात्राओं का विश्लेषण करें और 2 पैटर्न बताएं:\n${summary}\nसरल हिंदी में, 60 शब्दों से कम।`
    : `Analyze these ${trips.length} trips and identify 2 key patterns:\n${summary}\nUnder 80 words, actionable.`;

  try {
    const response = await fetch("https://openrouter.ai/api/v1/chat/completions", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${apiKey}`,
        "Content-Type": "application/json",
        "HTTP-Referer": "https://carbonchain.app",
        "X-Title": "CarbonChain",
      },
      body: JSON.stringify({
        model: "openai/gpt-4o-mini",
        messages: [{ role: "user", content: prompt }],
        max_tokens: 150,
        temperature: 0.7,
      }),
    });
    const data = await response.json() as any;
    return data.choices?.[0]?.message?.content?.trim() ?? "";
  } catch {
    return "";
  }
}

// Fleet analytics AI insights for owner dashboard
export async function generateFleetInsights(data: {
  totalCarbonKg: number;
  driverCount: number;
  overspeedingEvents: { driverName: string; date: string; maxSpeed: number }[];
  topEmitter: string;
  avgCarbonPerTrip: number;
}): Promise<string> {
  const apiKey = process.env.OPENROUTER_API_KEY;
  if (!apiKey) return "AI insights unavailable.";

  const overspeedSummary = data.overspeedingEvents.length > 0
    ? data.overspeedingEvents.map(e => `${e.driverName} on ${e.date} at ${e.maxSpeed} km/h`).join(', ')
    : 'None';

  const prompt = `You are a fleet sustainability manager. Analyze this fleet data and give 3 actionable insights.

Fleet data:
- Total CO₂ this period: ${data.totalCarbonKg.toFixed(1)} kg
- Active drivers: ${data.driverCount}
- Overspeeding events: ${overspeedSummary}
- Top emitter: ${data.topEmitter}
- Avg CO₂ per trip: ${data.avgCarbonPerTrip.toFixed(1)} kg

Give 3 bullet points. Each: specific recommendation with estimated impact. Under 100 words.`;

  try {
    const response = await fetch("https://openrouter.ai/api/v1/chat/completions", {
      method: "POST",
      headers: { "Authorization": `Bearer ${apiKey}`, "Content-Type": "application/json", "HTTP-Referer": "https://carbonchain.app", "X-Title": "CarbonChain" },
      body: JSON.stringify({ model: "openai/gpt-4o-mini", messages: [{ role: "user", content: prompt }], max_tokens: 200, temperature: 0.7 }),
    });
    const d = await response.json() as any;
    return d.choices?.[0]?.message?.content?.trim() ?? "";
  } catch { return "AI insights temporarily unavailable."; }
}

// AI assistant chat for owner
export async function chatWithAssistant(messages: { role: string; content: string }[], fleetContext: string): Promise<string> {
  const apiKey = process.env.OPENROUTER_API_KEY;
  if (!apiKey) return "AI assistant unavailable.";

  const systemPrompt = `You are CarbonChain AI, a fleet sustainability assistant. You help fleet owners understand their CO₂ emissions, driver performance, and ways to reduce environmental impact.

Current fleet context:
${fleetContext}

Be concise, helpful, and data-driven. Answer in 2-3 sentences max.`;

  try {
    const response = await fetch("https://openrouter.ai/api/v1/chat/completions", {
      method: "POST",
      headers: { "Authorization": `Bearer ${apiKey}`, "Content-Type": "application/json", "HTTP-Referer": "https://carbonchain.app", "X-Title": "CarbonChain" },
      body: JSON.stringify({
        model: "openai/gpt-4o-mini",
        messages: [{ role: "system", content: systemPrompt }, ...messages],
        max_tokens: 150,
        temperature: 0.7,
      }),
    });
    const d = await response.json() as any;
    return d.choices?.[0]?.message?.content?.trim() ?? "I couldn't process that. Try again.";
  } catch { return "AI assistant temporarily unavailable."; }
}
