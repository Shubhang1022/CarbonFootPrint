import { createClient } from "@supabase/supabase-js";

const supabase = createClient(
  process.env.SUPABASE_URL ?? "",
  process.env.SUPABASE_KEY ?? ""
);

export async function insertTrip(record: {
  distance: number;
  idle_time: number;
  fuel_type: string;
  carbon_kg: number;
  engine_efficiency: number;
}): Promise<void> {
  const { error } = await supabase.from("emissions").insert({
    id: crypto.randomUUID(),
    distance: record.distance,
    idle_time: record.idle_time,
    fuel_type: record.fuel_type,
    carbon_kg: record.carbon_kg,
    engine_efficiency: record.engine_efficiency,
    created_at: new Date().toISOString(),
  });

  if (error) {
    console.error("Failed to insert trip record:", error);
  }
}
