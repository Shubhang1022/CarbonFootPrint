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

  // Calculate efficiency score (0-100)
  const avgCarbon = tripData.distance * AVG_CARBON_PER_KM;
  const efficiencyScore = Math.max(0, Math.min(100,
    Math.round(100 - ((tripData.carbonKg - avgCarbon) / avgCarbon) * 50)
  ));

  // Money savings estimate
  const fuelUsed = tripData.distance / tripData.engineEfficiency;
  const potentialSavingLitres = fuelUsed * 0.15; // 15% saving potential
  const moneySaved = Math.round(potentialSavingLitres * DIESEL_PRICE_PER_LITRE);
  const moneySavedEstimate = isHindi
    ? `₹${moneySaved} बचाए जा सकते हैं`
    : `Save up to ₹${moneySaved}`;

  // Comparison to average
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
