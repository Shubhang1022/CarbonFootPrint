import { useState, useEffect, useRef } from 'react';
import { signOut } from '../lib/auth';
import { getMyTrips, getMyStats, submitDemoTrip } from '../lib/fleet';
import { BACKEND } from '../lib/supabase';

const DEMO_STEPS = [800, 1200, 950, 0, 0, 1100, 1400, 1300, 900, 0, 0, 1750, 1200];
const DEMO_IDLE = [false, false, false, true, true, false, false, false, false, true, true, false, false];

export default function DriverHome({ profile }: { profile: any; onRoleSwitch: () => void }) {
  const [tab, setTab] = useState<'trip' | 'history' | 'profile'>('trip');
  const [fuelType, setFuelType] = useState('diesel');
  const [loadWeight, setLoadWeight] = useState('500');
  const [engineEff, setEngineEff] = useState('10');
  const [isActive, setIsActive] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [distanceM, setDistanceM] = useState(0);
  const [idleSeconds, setIdleSeconds] = useState(0);
  const [ignitionSeconds, setIgnitionSeconds] = useState(0);
  const [speedKmh, setSpeedKmh] = useState(0);
  const [result, setResult] = useState<any>(null);
  const [isDemoRunning, setIsDemoRunning] = useState(false);
  const [demoStatus, setDemoStatus] = useState('');
  const [trips, setTrips] = useState<any[]>([]);
  const [stats, setStats] = useState<any>({});
  const [statPeriod, setStatPeriod] = useState(2);
  const ignitionRef = useRef<any>(null);
  const demoRef = useRef<any>(null);
  const demoStep = useRef(0);

  useEffect(() => {
    if (tab === 'history') loadHistory();
  }, [tab]);

  const loadHistory = async () => {
    const [t, s] = await Promise.all([getMyTrips(profile.id), getMyStats(profile.id)]);
    setTrips(t); setStats(s);
  };

  const startTrip = () => {
    setIsActive(true); setDistanceM(0); setIdleSeconds(0); setIgnitionSeconds(0); setSpeedKmh(0); setResult(null);
    ignitionRef.current = setInterval(() => setIgnitionSeconds(s => s + 1), 1000);
  };

  const stopTrip = async () => {
    clearInterval(ignitionRef.current);
    setIsSubmitting(true);
    try {
      const res = await fetch(`${BACKEND}/add-trip`, {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ distance: distanceM / 1000, fuel_type: fuelType, idle_time: Math.floor(idleSeconds / 60), load_weight: parseFloat(loadWeight), engine_efficiency: parseFloat(engineEff), user_id: profile.id, company_id: profile.company_id }),
      });
      const data = await res.json();
      setResult(data); setIsActive(false);
    } catch { alert('Submission failed. Try again.'); }
    finally { setIsSubmitting(false); }
  };

  const runDemo = () => {
    setIsActive(true); setDistanceM(0); setIdleSeconds(0); setIgnitionSeconds(0); setSpeedKmh(0); setResult(null);
    setIsDemoRunning(true); demoStep.current = 0; setDemoStatus('🚛 Demo: Starting trip...');
    ignitionRef.current = setInterval(() => setIgnitionSeconds(s => s + 1), 1000);
    demoRef.current = setInterval(() => {
      if (demoStep.current >= DEMO_STEPS.length) {
        clearInterval(demoRef.current); clearInterval(ignitionRef.current);
        setIsDemoRunning(false); setDemoStatus('');
        finishDemo();
        return;
      }
      const dist = DEMO_STEPS[demoStep.current];
      const idle = DEMO_IDLE[demoStep.current];
      if (idle) { setIdleSeconds(s => s + 5); setSpeedKmh(0); setDemoStatus('⏸ Demo: Vehicle idling...'); }
      else if (dist > 0) { setDistanceM(d => d + dist); setSpeedKmh(35 + dist / 100); setDemoStatus(`🚛 Demo: Driving...`); }
      demoStep.current++;
    }, 700);
  };

  const finishDemo = async () => {
    setIsSubmitting(true); setDemoStatus('📡 Submitting to backend...');
    const data = await submitDemoTrip(profile.id, profile.company_id);
    setResult(data); setIsActive(false); setIsSubmitting(false); setDemoStatus('');
  };

  const fmt = (s: number) => `${Math.floor(s / 60)}m ${s % 60}s`;
  const co2Color = (kg: number) => kg < 10 ? '#1DB954' : kg < 30 ? '#fb923c' : '#ef4444';
  const periods = ['Today', 'Week', 'Month'];
  const periodKeys = ['day', 'week', 'month'];

  return (
    <div className="page">
      <div style={{ maxWidth: 480, margin: '0 auto', padding: '0 0 80px' }}>
        {/* Header */}
        <div style={{ padding: '20px 20px 0', display: 'flex', alignItems: 'center', gap: 12, marginBottom: 20 }}>
          <div style={{ width: 40, height: 40, background: 'rgba(29,185,84,0.15)', borderRadius: 10, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 20 }}>🚛</div>
          <div style={{ flex: 1 }}>
            <div style={{ fontWeight: 700, fontSize: 18 }}>CarbonChain</div>
            <div style={{ color: 'rgba(255,255,255,0.4)', fontSize: 12 }}>Fleet Emissions Tracker</div>
          </div>
        </div>

        {/* Tabs */}
        <div style={{ padding: '0 20px', marginBottom: 20 }}>
          <div className="tabs">
            {(['trip', 'history', 'profile'] as const).map(t => (
              <button key={t} className={`tab ${tab === t ? 'active' : ''}`} onClick={() => setTab(t)} style={{ textTransform: 'capitalize' }}>{t === 'trip' ? '🚛 Trip' : t === 'history' ? '📊 History' : '👤 Profile'}</button>
            ))}
          </div>
        </div>

        {/* Trip Tab */}
        {tab === 'trip' && (
          <div style={{ padding: '0 20px' }}>
            {/* Status */}
            <div className="card" style={{ marginBottom: 16, borderColor: isActive ? '#1DB954' : undefined, background: isActive ? 'rgba(29,185,84,0.05)' : undefined }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                <div style={{ width: 10, height: 10, borderRadius: '50%', background: isActive ? '#1DB954' : '#6b7280', boxShadow: isActive ? '0 0 8px #1DB954' : 'none' }} />
                <span style={{ fontWeight: 600, color: isActive ? '#1DB954' : 'rgba(255,255,255,0.6)' }}>{isActive ? 'Trip Running' : 'Ready to Start'}</span>
              </div>
            </div>

            {/* Live metrics */}
            {isActive && (
              <>
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, marginBottom: 12 }}>
                  <div className="metric-card" style={{ borderColor: speedKmh > 80 ? '#ef4444' : speedKmh > 40 ? '#fb923c' : 'rgba(29,185,84,0.3)' }}>
                    <div className="metric-label">Speed</div>
                    <div className="metric-value" style={{ color: speedKmh > 80 ? '#ef4444' : speedKmh > 40 ? '#fb923c' : '#1DB954' }}>{speedKmh.toFixed(0)} <span style={{ fontSize: 12 }}>km/h</span></div>
                    <div style={{ height: 4, background: 'rgba(255,255,255,0.1)', borderRadius: 2, marginTop: 8 }}>
                      <div style={{ height: '100%', width: `${Math.min(speedKmh / 120 * 100, 100)}%`, background: speedKmh > 80 ? '#ef4444' : speedKmh > 40 ? '#fb923c' : '#1DB954', borderRadius: 2, transition: 'width .3s' }} />
                    </div>
                  </div>
                  <div className="metric-card">
                    <div className="metric-label">Distance</div>
                    <div className="metric-value" style={{ color: '#1DB954' }}>{(distanceM / 1000).toFixed(2)} <span style={{ fontSize: 12 }}>km</span></div>
                  </div>
                </div>
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, marginBottom: 16 }}>
                  <div className="metric-card">
                    <div className="metric-label">Idle Time</div>
                    <div className="metric-value" style={{ color: idleSeconds > 300 ? '#fb923c' : '#1DB954', fontSize: 18 }}>{fmt(idleSeconds)}</div>
                  </div>
                  <div className="metric-card">
                    <div className="metric-label">Ignition Time</div>
                    <div className="metric-value" style={{ color: '#60a5fa', fontSize: 18 }}>{fmt(ignitionSeconds)}</div>
                  </div>
                </div>
                {demoStatus && (
                  <div style={{ background: 'rgba(59,130,246,0.1)', border: '1px solid rgba(59,130,246,0.3)', borderRadius: 12, padding: '10px 14px', marginBottom: 16, display: 'flex', alignItems: 'center', gap: 10 }}>
                    <div className="spinner" style={{ width: 16, height: 16, borderWidth: 2 }} />
                    <span style={{ color: '#60a5fa', fontSize: 13 }}>{demoStatus}</span>
                  </div>
                )}
              </>
            )}

            {/* Result */}
            {result && !isActive && (
              <div style={{ background: `${co2Color(result.carbon)}22`, border: `1px solid ${co2Color(result.carbon)}44`, borderRadius: 20, padding: 24, marginBottom: 16, textAlign: 'center' }}>
                <div style={{ fontSize: 28 }}>🌿</div>
                <div style={{ fontSize: 48, fontWeight: 800, color: co2Color(result.carbon), lineHeight: 1.1 }}>{result.carbon?.toFixed(2)}</div>
                <div style={{ color: co2Color(result.carbon), opacity: 0.8 }}>kg CO₂</div>
                {result.efficiencyScore !== undefined && (
                  <div style={{ marginTop: 12 }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 4 }}>
                      <span style={{ fontSize: 12, color: 'rgba(255,255,255,0.5)' }}>Efficiency Score</span>
                      <span style={{ fontSize: 12, color: '#1DB954', fontWeight: 700 }}>{result.efficiencyScore}/100</span>
                    </div>
                    <div style={{ height: 8, background: 'rgba(255,255,255,0.1)', borderRadius: 4 }}>
                      <div style={{ height: '100%', width: `${result.efficiencyScore}%`, background: '#1DB954', borderRadius: 4 }} />
                    </div>
                  </div>
                )}
                {result.insights && (
                  <div style={{ marginTop: 16, background: 'rgba(29,185,84,0.08)', border: '1px solid rgba(29,185,84,0.2)', borderRadius: 12, padding: 14, textAlign: 'left' }}>
                    <div style={{ color: '#1DB954', fontWeight: 700, fontSize: 13, marginBottom: 8 }}>✨ AI Insights</div>
                    <div style={{ color: 'rgba(255,255,255,0.75)', fontSize: 13, lineHeight: 1.6 }}>{result.insights}</div>
                  </div>
                )}
                <button className="btn btn-green" style={{ marginTop: 16, width: '100%' }} onClick={() => setResult(null)}>+ New Trip</button>
              </div>
            )}

            {/* Config */}
            {!isActive && !result && (
              <>
                <div style={{ marginBottom: 12 }}>
                  <label className="label">Fuel Type</label>
                  <select className="input" value={fuelType} onChange={e => setFuelType(e.target.value)}>
                    <option value="diesel">Diesel</option>
                    <option value="petrol">Petrol</option>
                  </select>
                </div>
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, marginBottom: 20 }}>
                  <div>
                    <label className="label">Load Weight (kg)</label>
                    <input className="input" type="number" value={loadWeight} onChange={e => setLoadWeight(e.target.value)} />
                  </div>
                  <div>
                    <label className="label">Engine Eff. (km/L)</label>
                    <input className="input" type="number" value={engineEff} onChange={e => setEngineEff(e.target.value)} />
                  </div>
                </div>
                <button className="btn btn-green" style={{ width: '100%', marginBottom: 12, fontSize: 16 }} onClick={startTrip}>▶ Start Trip</button>
                <button className="btn btn-outline" style={{ width: '100%', color: '#60a5fa', borderColor: 'rgba(96,165,250,0.4)' }} disabled={isDemoRunning} onClick={runDemo}>🧪 Run Demo Trip</button>
              </>
            )}

            {isActive && (
              <button className="btn btn-red" style={{ width: '100%', fontSize: 16 }} disabled={isSubmitting} onClick={stopTrip}>
                {isSubmitting ? <span style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 10 }}><div className="spinner" style={{ width: 18, height: 18, borderWidth: 2 }} />Calculating...</span> : '⏹ Stop Trip'}
              </button>
            )}
          </div>
        )}

        {/* History Tab */}
        {tab === 'history' && (
          <div style={{ padding: '0 20px' }}>
            <div className="tabs period-tabs" style={{ marginBottom: 16 }}>
              {periods.map((p, i) => <button key={p} className={`tab ${statPeriod === i ? 'active' : ''}`} onClick={() => setStatPeriod(i)}>{p}</button>)}
            </div>
            {stats[periodKeys[statPeriod]] && (
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, marginBottom: 20 }}>
                <div className="metric-card"><div className="metric-label">CO₂ Emitted</div><div className="metric-value" style={{ color: '#1DB954', fontSize: 20 }}>{stats[periodKeys[statPeriod]].carbon.toFixed(1)} kg</div></div>
                <div className="metric-card"><div className="metric-label">Distance</div><div className="metric-value" style={{ color: '#60a5fa', fontSize: 20 }}>{stats[periodKeys[statPeriod]].distance.toFixed(1)} km</div></div>
                <div className="metric-card"><div className="metric-label">Idle Time</div><div className="metric-value" style={{ color: '#fb923c', fontSize: 20 }}>{stats[periodKeys[statPeriod]].idle.toFixed(0)} min</div></div>
                <div className="metric-card"><div className="metric-label">Trips</div><div className="metric-value" style={{ color: '#a78bfa', fontSize: 20 }}>{stats[periodKeys[statPeriod]].trips}</div></div>
              </div>
            )}
            <h3 style={{ fontWeight: 700, marginBottom: 12 }}>Trip History</h3>
            {trips.length === 0 ? <p style={{ color: 'rgba(255,255,255,0.3)', textAlign: 'center', padding: 32 }}>No trips yet</p> : trips.map(t => (
              <div key={t.id} className="card" style={{ marginBottom: 10, display: 'flex', alignItems: 'center', gap: 12 }}>
                <div style={{ flex: 1 }}>
                  <div style={{ fontSize: 11, color: 'rgba(255,255,255,0.3)', marginBottom: 4 }}>{t.created_at?.substring(0, 10)}</div>
                  <div style={{ fontSize: 13 }}>{t.distance?.toFixed(1)} km • {t.idle_time} min idle</div>
                </div>
                <div style={{ textAlign: 'right' }}>
                  <div style={{ fontSize: 18, fontWeight: 700, color: co2Color(t.carbon_kg) }}>{t.carbon_kg?.toFixed(1)}</div>
                  <div style={{ fontSize: 10, color: 'rgba(255,255,255,0.4)' }}>kg CO₂</div>
                </div>
              </div>
            ))}
          </div>
        )}

        {/* Profile Tab */}
        {tab === 'profile' && (
          <div style={{ padding: '0 20px' }}>
            <div style={{ textAlign: 'center', marginBottom: 24 }}>
              <div style={{ width: 72, height: 72, background: 'rgba(29,185,84,0.15)', borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 32, margin: '0 auto 12px' }}>🚛</div>
              <div style={{ fontWeight: 700, fontSize: 20 }}>{profile.name}</div>
              <div style={{ color: '#1DB954', fontSize: 13 }}>Driver</div>
            </div>
            {[['Phone', profile.phone], ['Truck Number', profile.truck_number], ['Location', profile.location], ['Date of Birth', profile.dob]].map(([l, v]) => v && (
              <div key={l} className="card" style={{ marginBottom: 10, display: 'flex', gap: 12, alignItems: 'center' }}>
                <div style={{ flex: 1 }}>
                  <div style={{ fontSize: 11, color: 'rgba(255,255,255,0.4)' }}>{l}</div>
                  <div style={{ fontSize: 14 }}>{v}</div>
                </div>
              </div>
            ))}
            <button className="btn btn-outline" style={{ width: '100%', marginTop: 16, color: '#ef4444', borderColor: 'rgba(239,68,68,0.4)' }} onClick={() => signOut()}>Logout</button>
          </div>
        )}
      </div>
    </div>
  );
}
