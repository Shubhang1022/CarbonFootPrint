import { supabase } from './supabase';

export async function sendEmailOtp(email: string) {
  const { error } = await supabase.auth.signInWithOtp({ email });
  if (error) throw error;
}

export async function verifyEmailOtp(email: string, token: string) {
  const { data, error } = await supabase.auth.verifyOtp({ email, token, type: 'email' });
  if (error) throw error;
  return data.user;
}

export async function getProfile() {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return null;
  const { data } = await supabase.from('profiles').select('*').eq('id', user.id).maybeSingle();
  return data;
}

export async function createDriverProfile(p: { name: string; dob: string; location: string; truckNumber: string; companyId: string; phone?: string }) {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error('Not logged in');
  await supabase.from('profiles').upsert({
    id: user.id, name: p.name, phone: p.phone ?? user.phone ?? null,
    role: 'driver', dob: p.dob, location: p.location,
    truck_number: p.truckNumber, company_id: p.companyId, status: 'pending',
  });
  await supabase.from('driver_requests').upsert({ driver_id: user.id, company_id: p.companyId, status: 'pending' });
}

export async function createOwnerProfile(p: { name: string; dob: string; location: string; companyName: string; phone?: string }) {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error('Not logged in');
  await supabase.from('profiles').upsert({
    id: user.id, name: p.name, phone: p.phone ?? null,
    role: 'admin', dob: p.dob, location: p.location, status: 'accepted',
  });
  let companyId: string;
  try {
    const { data } = await supabase.from('companies').insert({ name: p.companyName, owner_id: user.id, owner_email: user.email }).select().single();
    companyId = data.id;
  } catch {
    const { data } = await supabase.from('companies').select('id').eq('name', p.companyName).maybeSingle();
    if (!data) throw new Error('Company creation failed');
    companyId = data.id;
    await supabase.from('companies').update({ owner_id: user.id }).eq('id', companyId);
  }
  await supabase.from('profiles').update({ company_id: companyId }).eq('id', user.id);
}

export async function searchCompanies(query: string) {
  if (!query.trim()) return [];
  const { data } = await supabase.from('companies').select('id, name').ilike('name', `${query}%`).limit(10);
  return data ?? [];
}

export async function getDriverRequestStatus(userId: string) {
  const { data } = await supabase.from('driver_requests').select('status').eq('driver_id', userId).maybeSingle();
  return data?.status ?? null;
}

export async function signOut() {
  await supabase.auth.signOut();
  window.location.href = window.location.origin + window.location.pathname;
}
