import { useState, useRef } from 'react';
import { verifyEmailOtp } from '../lib/auth';

export default function OtpPage({ email, role, onVerified }: { email: string; role: string; onVerified: () => void }) {
  const [digits, setDigits] = useState(['', '', '', '', '', '']);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const refs = useRef<(HTMLInputElement | null)[]>([]);
  const color = role === 'admin' ? '#3b82f6' : '#1DB954';

  const onChange = (i: number, v: string) => {
    if (!/^\d*$/.test(v)) return;
    const d = [...digits]; d[i] = v.slice(-1); setDigits(d);
    if (v && i < 5) refs.current[i + 1]?.focus();
    if (d.every(x => x) && v) verify(d.join(''));
  };

  const onKeyDown = (i: number, e: React.KeyboardEvent) => {
    if (e.key === 'Backspace' && !digits[i] && i > 0) refs.current[i - 1]?.focus();
  };

  const verify = async (otp: string) => {
    setLoading(true); setError('');
    try {
      await verifyEmailOtp(email, otp);
      onVerified();
    } catch {
      setError('Invalid OTP. Please try again.');
      setDigits(['', '', '', '', '', '']);
      refs.current[0]?.focus();
    } finally { setLoading(false); }
  };

  return (
    <div className="page" style={{ display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
      <div className="page-inner" style={{ textAlign: 'center' }}>
        <div style={{ fontSize: 48, marginBottom: 16 }}>📧</div>
        <h2 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Enter OTP</h2>
        <p style={{ color: 'rgba(255,255,255,0.5)', fontSize: 14, marginBottom: 8 }}>Sent to {email}</p>
        <p style={{ color: '#fbbf24', fontSize: 12, marginBottom: 32 }}>Check your email inbox for the 6-digit code</p>
        <div style={{ display: 'flex', gap: 10, justifyContent: 'center', marginBottom: 24 }}>
          {digits.map((d, i) => (
            <input key={i} ref={(el) => { refs.current[i] = el; }} value={d}
              onChange={e => onChange(i, e.target.value)}
              onKeyDown={e => onKeyDown(i, e)}
              style={{ width: 48, height: 56, textAlign: 'center', fontSize: 22, fontWeight: 700, background: '#1A1F2E', border: `1.5px solid ${d ? color : 'rgba(255,255,255,0.1)'}`, borderRadius: 12, color: color, outline: 'none' }}
              maxLength={1} inputMode="numeric" autoFocus={i === 0} />
          ))}
        </div>
        {error && <p className="error" style={{ marginBottom: 16 }}>{error}</p>}
        {loading && <div style={{ display: 'flex', justifyContent: 'center' }}><div className="spinner" /></div>}
      </div>
    </div>
  );
}
