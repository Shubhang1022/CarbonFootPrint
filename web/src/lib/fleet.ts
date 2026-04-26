import { supabase, BACKEND } from './supabase';

export async function getFleetStats(companyId: string) {
  const now = new Date();
  const dayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate()).toISOString();
  const weekStart = new Date(now.getTime() - 7 * 86400000).toISOString();
  const monthStart = new Date(now.getFullYear(), now.getMonth(), 1).toISOString();
  const yearStart = new Date(now.getFullYear(), 0, 1).toISOString();

  const sum = async (since: string) => {
    const { data } = await supabase.from('emissions').select('carbon_kg').eq('company_id', companyId).gte('created_at', since);
    return (data ?? []).reduce((s, r) => s + (r.carbon_kg ?? 0), 0);
  };
  const [day, week, month, annual] = await Promise.all([sum(dayStart), sum(weekStart), sum(monthStart), sum(yearStart)]);
  return { day, week, month, annual };
}

export async function getCompanyDrivers(companyId: string) {
  const { data } = await supabase.from('profiles').select('*').eq('company_id', companyId).eq('role', 'driver').eq('status', 'accepted').order('name');
  return data ?? [];
}

export async function getDriverStats(companyId: string) {
  const now = new Date();
  const dayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate()).toISOString();
  const weekStart = new Date(now.getTime() - 7 * 86400000).toISOString();
  const monthStart = new Date(now.getFullYear(), now.getMonth(), 1).toISOString();
  const yearStart = new Date(now.getFullYear(), 0, 1).toISOString();
  const drivers = await getCompanyDrivers(companyId);

  const dc = async (uid: string, since: string) => {
    const { data } = await supabase.from('emissions').select('carbon_kg').eq('user_id', uid).gte('created_at', since);
    return (data ?? []).reduce((s, r) => s + (r.carbon_kg ?? 0), 0);
  };

  return Promise.all(drivers.map(async d => {
    const [day, week, month, annual] = await Promise.all([dc(d.id, dayStart), dc(d.id, weekStart), dc(d.id, monthStart), dc(d.id, yearStart)]);
    return { ...d, day, week, month, annual };
  }));
}

export async function getPendingRequests(companyId: string) {
  const { data } = await supabase.from('driver_requests').select('*, profiles(name, phone, truck_number)').eq('company_id', companyId).eq('status', 'pending').order('created_at', { ascending: false });
  return data ?? [];
}

export async function respondToRequest(requestId: string, driverId: string, accept: boolean) {
  const status = accept ? 'accepted' : 'rejected';
  await supabase.from('driver_requests').update({ status }).eq('id', requestId);
  await supabase.from('profiles').update({ status }).eq('id', driverId);
}

export async function getFleetAnalytics(companyId: string, period: string) {
  const res = await fetch(`${BACKEND}/fleet-analytics?company_id=${companyId}&period=${period}`);
  return res.ok ? res.json() : { totalCarbon: 0, overspeedingEvents: [], aiInsights: '', tripCount: 0 };
}

export async function chatWithAssistant(messages: { role: string; content: string }[], fleetContext: string) {
  const res = await fetch(`${BACKEND}/ai-assistant`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ messages, fleet_context: fleetContext }),
  });
  const d = await res.json();
  return d.reply ?? 'Unable to connect.';
}

export async function getMyTrips(userId: string) {
  const { data } = await supabase.from('emissions').select('*').eq('user_id', userId).order('created_at', { ascending: false }).limit(50);
  return data ?? [];
}

export async function getMyStats(userId: string) {
  const now = new Date();
  const dayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate()).toISOString();
  const weekStart = new Date(now.getTime() - 7 * 86400000).toISOString();
  const monthStart = new Date(now.getFullYear(), now.getMonth(), 1).toISOString();

  const s = async (since: string) => {
    const { data } = await supabase.from('emissions').select('carbon_kg, distance, idle_time').eq('user_id', userId).gte('created_at', since);
    const list = data ?? [];
    return { carbon: list.reduce((a, r) => a + (r.carbon_kg ?? 0), 0), distance: list.reduce((a, r) => a + (r.distance ?? 0), 0), idle: list.reduce((a, r) => a + (r.idle_time ?? 0), 0), trips: list.length };
  };
  const [day, week, month] = await Promise.all([s(dayStart), s(weekStart), s(monthStart)]);
  return { day, week, month };
}

export async function submitDemoTrip(userId: string, companyId: string | null) {
  const res = await fetch(`${BACKEND}/add-trip`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ distance: 10.6, fuel_type: 'diesel', idle_time: 2, load_weight: 500, engine_efficiency: 8, user_id: userId, company_id: companyId }),
  });
  return res.ok ? res.json() : null;
}
