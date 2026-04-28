export interface TripInsights {
  text: string;
  efficiencyScore: number;
  moneySavedEstimate: string;
  comparisonToAverage: string;
  nextTripRecommendation: string;
}

const AVG_CARBON_PER_KM = 0.27;
const DIESEL_PRICE_PER_LITRE = 90;
const MODEL = "openai/gpt-4o-mini";

async function callAI(prompt: string, maxTokens = 250, temperature = 0.7): Promise<string> {
  const apiKey = process.env.OPENROUTER_API_KEY;
  if (!apiKey) throw new Error("OPENROUTER_API_KEY not set");

  const response = await fetch("https://openrouter.ai/api/v1/chat/completions", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${apiKey}`,
      "Content-Type": "application/json",
      "HTTP-Referer": "https://carbonchain.app",
      "X-Title": "CarbonChain",
    },
    body: JSON.stringify({
      model: MODEL,
      messages: [{ role: "user", content: prompt }],
      max_tokens: maxTokens,
      temperature,
    }),
  });

  if (!response.ok) throw new Error(`OpenRouter error ${response.status}`);
  const data = await response.json() as any;
  return data.choices?.[0]?.message?.content?.trim() ?? "";
}

async function callAIChat(systemPrompt: string, messages: { role: string; content: string }[], maxTokens = 300): Promise<string> {
  const apiKey = process.env.OPENROUTER_API_KEY;
  if (!apiKey) throw new Error("OPENROUTER_API_KEY not set");

  const response = await fetch("https://openrouter.ai/api/v1/chat/completions", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${apiKey}`,
      "Content-Type": "application/json",
      "HTTP-Referer": "https://carbonchain.app",
      "X-Title": "CarbonChain",
    },
    body: JSON.stringify({
      model: MODEL,
      messages: [{ role: "system", content: systemPrompt }, ...messages],
      max_tokens: maxTokens,
      temperature: 0.5,
    }),
  });

  if (!response.ok) throw new Error(`OpenRouter error ${response.status}`);
  const data = await response.json() as any;
  return data.choices?.[0]?.message?.content?.trim() ?? "";
}

export async function generateInsights(tripData: {
  distance: number; fuelType: string; idleTime: number; loadWeight: number;
  engineEfficiency: number; carbonKg: number; ignitionTimeMinutes?: number; language?: string;
}): Promise<TripInsights> {
  const isHindi = tripData.language === 'hi';

  const engineScore = Math.min(100, (tripData.engineEfficiency / 10) * 60);
  const ignitionMins = tripData.ignitionTimeMinutes ?? 1;
  const idleRatio = ignitionMins > 0 ? tripData.idleTime / Math.max(ignitionMins, 1) : 0;
  const idleScore = Math.max(0, 40 - idleRatio * 40);
  const efficiencyScore = Math.max(0, Math.min(100, Math.round(engineScore + idleScore)));

  const fuelUsed = tripData.distance / tripData.engineEfficiency;
  const moneySaved = Math.round(fuelUsed * 0.15 * DIESEL_PRICE_PER_LITRE);
  const moneySavedEstimate = isHindi ? `₹${moneySaved} बचाए जा सकते हैं` : `Save up to ₹${moneySaved}`;

  const avgCarbon = Math.max(tripData.distance * AVG_CARBON_PER_KM, 0.1);
  const diffPercent = Math.round(((tripData.carbonKg - avgCarbon) / avgCarbon) * 100);
  const comparisonToAverage = isHindi
    ? diffPercent > 0 ? `औसत ड्राइवर से ${diffPercent}% अधिक उत्सर्जन` : `औसत ड्राइवर से ${Math.abs(diffPercent)}% कम उत्सर्जन`
    : diffPercent > 0 ? `${diffPercent}% more than average driver` : `${Math.abs(diffPercent)}% better than average driver`;

  const prompt = isHindi
    ? `फ्लीट विश्लेषक: यात्रा विश्लेषण करें। दूरी: ${tripData.distance.toFixed(2)} km, ईंधन: ${tripData.fuelType}, निष्क्रिय: ${tripData.idleTime} मिनट, भार: ${tripData.loadWeight} kg, इंजन: ${tripData.engineEfficiency} km/L, CO₂: ${tripData.carbonKg.toFixed(2)} kg, स्कोर: ${efficiencyScore}/100. 3 बुलेट पॉइंट दें, 100 शब्दों से कम।`
    : `Fleet analyst. Trip: Distance ${tripData.distance.toFixed(2)} km, Fuel ${tripData.fuelType}, Idle ${tripData.idleTime} min, Load ${tripData.loadWeight} kg, Engine ${tripData.engineEfficiency} km/L, CO₂ ${tripData.carbonKg.toFixed(2)} kg, Score ${efficiencyScore}/100, Ignition ${tripData.ignitionTimeMinutes ?? 0} min. Give 3 bullet points with specific recommendations + savings. Under 120 words.`;

  try {
    const text = await callAI(prompt, 250);
    const lines = text.split('\n').filter(l => l.trim().startsWith('-') || l.trim().startsWith('•'));
    const nextTripRecommendation = lines[lines.length - 1]?.replace(/^[-•]\s*/, '') ?? "";
    return { text, efficiencyScore, moneySavedEstimate, comparisonToAverage, nextTripRecommendation };
  } catch (err) {
    console.error("generateInsights error:", err);
    return { text: "AI insights temporarily unavailable.", efficiencyScore, moneySavedEstimate, comparisonToAverage, nextTripRecommendation: "" };
  }
}

export async function generateCoachingTip(data: { idleMinutes: number; speedKmh: number; distanceKm: number; language?: string }): Promise<string> {
  const isHindi = data.language === 'hi';
  const prompt = isHindi
    ? `एक वाक्य में ड्राइवर को सुझाव दें। निष्क्रिय: ${data.idleMinutes} मिनट, गति: ${data.speedKmh.toFixed(0)} km/h, दूरी: ${data.distanceKm.toFixed(1)} km।`
    : `One driving tip (max 15 words). Idle: ${data.idleMinutes} min, speed: ${data.speedKmh.toFixed(0)} km/h, distance: ${data.distanceKm.toFixed(1)} km.`;
  try { return await callAI(prompt, 40, 0.8); } catch { return ""; }
}

export async function generateWeeklyAnalysis(trips: any[], language?: string): Promise<string> {
  if (trips.length === 0) return "";
  const isHindi = language === 'hi';
  const summary = trips.map((t, i) => `Trip ${i + 1}: ${t.distance?.toFixed(1)}km, ${t.idle_time}min idle, ${t.carbon_kg?.toFixed(1)}kg CO₂`).join('\n');
  const prompt = isHindi
    ? `${trips.length} यात्राओं का विश्लेषण, 2 पैटर्न बताएं:\n${summary}\n60 शब्दों से कम।`
    : `Analyze ${trips.length} trips, 2 key patterns:\n${summary}\nUnder 80 words.`;
  try { return await callAI(prompt, 150); } catch { return ""; }
}

export async function generateFleetInsights(data: {
  totalCarbonKg: number; driverCount: number;
  overspeedingEvents: { driverName: string; date: string; maxSpeed: number }[];
  topEmitter: string; avgCarbonPerTrip: number;
}): Promise<string> {
  const overspeedSummary = data.overspeedingEvents.length > 0
    ? data.overspeedingEvents.map(e => `${e.driverName} on ${e.date} at ${e.maxSpeed} km/h`).join(', ')
    : 'None';
  const prompt = `Fleet manager. 3 actionable insights:\nTotal CO₂: ${data.totalCarbonKg.toFixed(1)} kg, Drivers: ${data.driverCount}, Overspeeding: ${overspeedSummary}, Top emitter: ${data.topEmitter}, Avg CO₂/trip: ${data.avgCarbonPerTrip.toFixed(1)} kg\n3 bullets, specific + estimated impact. Under 100 words.`;
  try { return await callAI(prompt, 200); } catch { return "AI insights temporarily unavailable."; }
}

export async function chatWithAssistant(messages: { role: string; content: string }[], fleetContext: string): Promise<string> {
  const systemPrompt = `You are CarbonChain AI, an intelligent fleet sustainability assistant with full access to fleet data.\n\nFLEET DATA:\n${fleetContext}\n\nRules: Reference specific data. Be concise (2-4 sentences). Use actual numbers. Say so if data unavailable.`;
  try { return await callAIChat(systemPrompt, messages, 300); }
  catch (err) { console.error("chatWithAssistant error:", err); return "AI assistant temporarily unavailable."; }
}
