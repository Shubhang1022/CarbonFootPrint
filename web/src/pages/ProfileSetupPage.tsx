import { useState } from 'react';
import { createDriverProfile, createOwnerProfile, searchCompanies } from '../lib/auth';

export default function ProfileSetupPage({ role, onDone }: { role: 'driver' | 'admin'; onDone: () => void }) {
  const [name, setName] = useState('');
  const [dob, setDob] = useState('');
  const [location, setLocation] = useState('');
  const [phone, setPhone] = useState('');
  const [truckNumber, setTruckNumber] = useState('');
  const [companyQuery, setCompanyQuery] = useState('');
  const [companySuggestions, setCompanySuggestions] = useState<any[]>([]);
  const [selectedCompany, setSelectedCompany] = useState<any>(null);
  const [companyName, setCompanyName] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const isDriver = role === 'driver';
  const color = isDriver ? '#1DB954' : '#3b82f6';

  const onCompanySearch = async (q: string) => {
    setCompanyQuery(q); setSelectedCompany(null);
    if (q.trim()) { const r = await searchCompanies(q); setCompanySuggestions(r); }
    else setCompanySuggestions([]);
  };

  const save = async () => {
    if (!name.trim()) { setError('Enter your name'); return; }
    if (!dob) { setError('Select your date of birth'); return; }
    if (!location.trim()) { setError('Enter your location'); return; }
    if (isDriver && !truckNumber.trim()) { setError('Enter your truck number'); return; }
    if (isDriver && !selectedCompany) { setError('Select your company from the list'); return; }
    if (!isDriver && !companyName.trim()) { setError('Enter your company name'); return; }
    setLoading(true); setError('');
    try {
      if (isDriver) await createDriverProfile({ name, dob, location, truckNumber, companyId: selectedCompany.id, phone: phone || undefined });
      else await createOwnerProfile({ name, dob, location, companyName, phone: phone || undefined });
      onDone();
    } catch (e: any) { setError(e.message ?? 'Failed to save. Try again.'); }
    finally { setLoading(false); }
  };

  const field = (label: string, value: string, onChange: (v: string) => void, type = 'text', placeholder = '') => (
    <div style={{ marginBottom: 14 }}>
      <label className="label">{label}</label>
      <input className="input" type={type} value={value} onChange={e => onChange(e.target.value)} placeholder={placeholder} />
    </div>
  );

  return (
    <div className="page" style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '40px 0' }}>
      <div className="page-inner">
        <div style={{ textAlign: 'center', marginBottom: 28 }}>
          <div style={{ fontSize: 40, marginBottom: 12 }}>{isDriver ? '🚛' : '🏢'}</div>
          <h2 style={{ fontSize: 22, fontWeight: 700, marginBottom: 6 }}>{isDriver ? 'Driver Profile' : 'Owner Profile'}</h2>
          <p style={{ color: 'rgba(255,255,255,0.5)', fontSize: 13 }}>Fill in your details to continue</p>
        </div>
        {field('Full Name', name, setName, 'text', 'Your full name')}
        <div style={{ marginBottom: 14 }}>
          <label className="label">Date of Birth</label>
          <input className="input" type="date" value={dob} onChange={e => setDob(e.target.value)} max={new Date(Date.now() - 18 * 365.25 * 86400000).toISOString().split('T')[0]} />
        </div>
        {field('City / Location', location, setLocation, 'text', 'Your city')}
        {field('Phone Number (optional)', phone, setPhone, 'tel', '+91XXXXXXXXXX')}
        {isDriver && field('Truck Number', truckNumber, setTruckNumber, 'text', 'e.g. MH12AB1234')}
        {isDriver ? (
          <div style={{ marginBottom: 14 }}>
            <label className="label">Search Company</label>
            <input className="input" value={selectedCompany ? `✓ ${selectedCompany.name}` : companyQuery}
              onChange={e => onCompanySearch(e.target.value)}
              placeholder="Type company name..."
              style={{ borderColor: selectedCompany ? '#1DB954' : undefined }} />
            {companySuggestions.length > 0 && !selectedCompany && (
              <div style={{ background: '#1A1F2E', border: '1px solid rgba(255,255,255,0.1)', borderRadius: 12, marginTop: 4, overflow: 'hidden' }}>
                {companySuggestions.map(c => (
                  <div key={c.id} onClick={() => { setSelectedCompany(c); setCompanyQuery(c.name); setCompanySuggestions([]); }}
                    style={{ padding: '12px 16px', cursor: 'pointer', fontSize: 14, borderBottom: '1px solid rgba(255,255,255,0.05)' }}
                    onMouseEnter={e => (e.currentTarget.style.background = 'rgba(29,185,84,0.08)')}
                    onMouseLeave={e => (e.currentTarget.style.background = 'transparent')}>
                    🏢 {c.name}
                  </div>
                ))}
              </div>
            )}
          </div>
        ) : field('Company Name', companyName, setCompanyName, 'text', 'Your company name')}
        {error && <p className="error" style={{ marginBottom: 12 }}>{error}</p>}
        <button className="btn" style={{ width: '100%', background: color, color: isDriver ? '#000' : '#fff', marginTop: 8 }} disabled={loading} onClick={save}>
          {loading ? 'Saving...' : isDriver ? 'Send Join Request' : 'Create Company'}
        </button>
      </div>
    </div>
  );
}
