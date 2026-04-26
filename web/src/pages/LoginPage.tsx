import { useState } from 'react';
import { sendEmailOtp } from '../lib/auth';

export default function LoginPage({ onOtpSent }: { onOtpSent: (email: string, role: 'driver' | 'admin') => void }) {
  const [role, setRole] = useState<'driver' | 'admin' | null>(null);
  const [email, setEmail] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [cooldown, setCooldown] = useState(0);

  const startCooldown = () => {
    setCooldown(60);
    const t = setInterval(() => setCooldown(c => { if (c <= 1) { clearInterval(t); return 0; } return c - 1; }), 1000);
  };

  const send = async () => {
    if (!email.includes('@')) { setError('Enter a valid email address'); return; }
    setLoading(true); setError('');
    try {
      await sendEmailOtp(email);
      startCooldown();
      onOtpSent(email, role!);
    } catch (e: any) {
      setError(e.message?.includes('rate') ? 'Too many attempts. Wait a minute.' : 'Failed to send OTP. Try again.');
    } finally { setLoading(false); }
  };

  if (!role) return (
    <div className="page" style={{ display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
      <div className="page-inner" style={{ textAlign: 'center' }}>
        <div style={{ fontSize: 48, marginBottom: 16 }}>🚛</div>
        <h1 style={{ fontSize: 28, fontWeight: 800, marginBottom: 8 }}>CarbonChain</h1>
        <p style={{ color: 'rgba(255,255,255,0.5)', marginBottom: 48 }}>Fleet Emissions Tracker</p>
        <p style={{ color: 'rgba(255,255,255,0.6)', marginBottom: 20, fontSize: 15 }}>I am a...</p>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
          <button className="card" style={{ textAlign: 'left', cursor: 'pointer', border: '1px solid rgba(29,185,84,0.3)', padding: 20 }} onClick={() => setRole('driver')}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
              <div style={{ width: 48, height: 48, background: 'rgba(29,185,84,0.12)', borderRadius: 12, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 24 }}>🚛</div>
              <div>
                <div style={{ fontWeight: 700, fontSize: 16 }}>Driver</div>
                <div style={{ color: 'rgba(255,255,255,0.5)', fontSize: 13 }}>Track trips and monitor emissions</div>
              </div>
              <div style={{ marginLeft: 'auto', color: '#1DB954' }}>›</div>
            </div>
          </button>
          <button className="card" style={{ textAlign: 'left', cursor: 'pointer', border: '1px solid rgba(59,130,246,0.3)', padding: 20 }} onClick={() => setRole('admin')}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
              <div style={{ width: 48, height: 48, background: 'rgba(59,130,246,0.12)', borderRadius: 12, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 24 }}>🏢</div>
              <div>
                <div style={{ fontWeight: 700, fontSize: 16 }}>Fleet Owner</div>
                <div style={{ color: 'rgba(255,255,255,0.5)', fontSize: 13 }}>Manage fleet and view dashboard</div>
              </div>
              <div style={{ marginLeft: 'auto', color: '#3b82f6' }}>›</div>
            </div>
          </button>
        </div>
      </div>
    </div>
  );

  const color = role === 'admin' ? '#3b82f6' : '#1DB954';
  return (
    <div className="page" style={{ display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
      <div className="page-inner">
        <button onClick={() => setRole(null)} style={{ background: 'none', border: 'none', color: 'rgba(255,255,255,0.5)', fontSize: 14, marginBottom: 24, cursor: 'pointer' }}>← Back</button>
        <div style={{ textAlign: 'center', marginBottom: 32 }}>
          <span className="badge" style={{ background: `${color}22`, color, border: `1px solid ${color}44`, marginBottom: 16, display: 'inline-block' }}>{role === 'admin' ? 'Fleet Owner' : 'Driver'}</span>
          <h2 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Enter your email</h2>
          <p style={{ color: 'rgba(255,255,255,0.5)', fontSize: 14 }}>We'll send you a one-time code</p>
        </div>
        <label className="label">Email Address</label>
        <input className="input" type="email" placeholder="you@example.com" value={email} onChange={e => setEmail(e.target.value)} onKeyDown={e => e.key === 'Enter' && send()} />
        {error && <p className="error">{error}</p>}
        <button className="btn btn-green" style={{ width: '100%', marginTop: 20, background: color, color: role === 'admin' ? '#fff' : '#000' }} disabled={loading || cooldown > 0} onClick={send}>
          {loading ? 'Sending...' : cooldown > 0 ? `Resend in ${cooldown}s` : 'Send OTP to Email'}
        </button>
        <p style={{ textAlign: 'center', color: 'rgba(255,255,255,0.3)', fontSize: 12, marginTop: 12 }}>Works for both new and existing accounts</p>
      </div>
    </div>
  );
}
