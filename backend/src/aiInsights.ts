/**
 * Generates AI-powered trip insights using OpenRouter (GPT-4o-mini).
 */
export async function generateInsights(tripData: {
  distance: number;
  fuelType: string;
  idleTime: number;
  loadWeight: number;
  engineEfficiency: number;
  carbonKg: number;
}): Promise<string> {
  const apiKey = process.env.OPENROUTER_API_KEY;
  if (!apiKey) {
    return "AI insights unavailable — API key not configured.";
  }

  const idlePercent = tripData.distance > 0
    ? ((tripData.idleTime / (tripData.idleTime + tripData.distance * 2)) * 100).toFixed(1)
    : "0";

  const prompt = `You are a fleet sustainability analyst. Analyze this delivery trip and provide 3 concise, actionable insights to reduce carbon emissions. Be specific with numbers.

Trip data:
- Distance: ${tripData.distance.toFixed(2)} km
- Fuel type: ${tripData.fuelType}
- Idle time: ${tripData.idleTime} minutes
- Load weight: ${tripData.loadWeight} kg
- Engine efficiency: ${tripData.engineEfficiency} km/L
- Total CO₂ emitted: ${tripData.carbonKg.toFixed(2)} kg

Provide exactly 3 bullet points. Each should be one sentence with a specific recommendation and estimated CO₂ saving. Keep it under 120 words total.`;

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
        max_tokens: 200,
        temperature: 0.7,
      }),
    });

    if (!response.ok) {
      console.error("OpenRouter error:", response.status);
      return "AI insights temporarily unavailable.";
    }

    const data = await response.json() as any;
    return data.choices?.[0]?.message?.content ?? "No insights generated.";
  } catch (err) {
    console.error("AI insights error:", err);
    return "AI insights temporarily unavailable.";
  }
}
