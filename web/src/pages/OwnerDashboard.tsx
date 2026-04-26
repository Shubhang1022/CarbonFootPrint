import { useState, useEffect, useRef } from 'react';
import { signOut } from '../lib/auth';
import { getFleetStats, getDriverStats, getPendingRequests, respondToRequest, getFleetAnalytics, chatWithAssistant } from '../lib/fleet';

const PERIODS = ['Day', 'Week', 'Month', 'Annual'];
const PERIOD_KEYS = ['day', 'week', 'month', 'annual'];
const PERIOD_API = ['day', 'week', 'month', 'annual'];

export default function OwnerDashboard({ profile }: { profile: any; onRoleSwitch: () => void }) {
  const [tab, setTab] = useState<'analytics' | 'speed' | 'drivers' | 'requests' | 'profile'>('analytics');
  const [period, setPeriod] = useState(1);
  const [fleetStats, setFleetStats] = useState<any>({ day: 0, week: 0, month: 0, annual: 0 });
  const [driverStats, setDriverStats] = useState<any[]>([]);
  const [pendingRequests, setPendingRequests] = useState<any[]>([]);
  const [analytics, setAnalytics] = useState<any>({});
  const [loading, setLoading] = useState(true);
  const [showChat, setShowChat] = useState(false);
  const [chatMessages, setChatMessages] = useState<{ role: string; content: string }[]>([]);
  const [chatInput, setChatInput] = useState('');
  const [chatLoading, setChatLoading] = useState(false);
  const chatEndRef = useRef<HTMLDivElement>(null);

  useEffect(() => { load(); }, [period]);
  useEffect(() => { chatEndRef.current?.scrollIntoView({ behavior: 'smooth' }); }, [chatMessages]);

  const load = async () => {
    setLoading(true);
    const cid = profile.company_id;
    if (!cid) { setLoading(false); return; }
    const [fs, ds, pr, an] = await Promise.all([
      getFleetStats(cid), getDriverStats(cid), getPendingRequests(cid),
      getFleetAnalytics(cid, PERIOD_API[period]),
    ]);
    setFleetStats(fs); setDriverStats(ds); setPendingRequests(pr); setAnalytics(an);
    setLoading(false);
  };

  const sendChat = async () => {
    if (!chatInput.trim()) return;
    const msg = chatInput.trim(); setChatInput('');
    const newMessages = [...chatMessages, { role: 'user', content: msg }];
    setChatMessages(newMessages); setChatLoading(true);
    const key = PERIOD_KEYS[period];
    const ctx = `Fleet: ${profile.name ?? 'Unknown'}. Period: ${PERIODS[period]}. Total CO₂: ${fleetStats[key]?.toFixed(1)} kg. Drivers: ${driverStats.length}. Pending: ${pendingRequests.length}.\nDrivers:\n${driverStats.map(d => `  ${d.name} | Truck: ${d.truck_number} | CO₂: ${d[key]?.toFixed(1)} kg`).join('\n')}\nOverspeeding: ${(analytics.overspeedingEvents ?? []).map((e: any) => `${e.driverName} on ${e.date} at ${e.maxSpeed} km/h`).join(', ') || 'None'}`;
    const reply = await chatWithAssistant(newMessages, ctx);
    setChatMessages([...newMessages, { role: 'assistant', content: reply }]);
    setChatLoading(false);
  };

  const co2Color = (kg: number) => kg < 50 ? '#1DB954' : kg < 200 ? '#fb923c' : '#ef4444';
  const totalCo2 = fleetStats[PERIOD_KEYS[period]] ?? 0;
  const overspeed = analytics.overspeedingEvents ?? [];

  return (
    <div className="page">
      <div style={{ maxWidth: 900, margin: '0 auto', padding: '0 0 80px' }}>
        {/* Header */}
        <div style={{ padding: '20px 20px 0', display: 'flex', alignItems: 'center', gap: 12, marginBottom: 16 }}>
          <div style={{ width: 40, height: 40, background: 'rgba(59,130,246,0.15)', borderRadius: 10, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 20 }}>🏢</div>
          <div style={{ flex: 1 }}>
            <div style={{ fontWeight: 700, fontSize: 18 }}>Fleet Dashboard</div>
            <div style={{ color: 'rgba(255,255,255,0.4)', fontSize: 12 }}>{profile.name}</div>
          </div>
          {pendingRequests.length > 0 && <span style={{ background: '#fb923c', color: '#000', borderRadius: 12, padding: '2px 10px', fontSize: 12, fontWeight: 700 }}>{pendingRequests.length}</span>}
        </div>

        {/* Period selector */}
        <div style={{ padding: '0 20px', marginBottom: 12 }}>
          <div className="tabs period-tabs">
            {PERIODS.map((p, i) => <button key={p} className={`tab ${period === i ? 'active' : ''}`} onClick={() => setPeriod(i)}>{p}</button>)}
          </div>
        </div>

        {/* Tabs */}
        <div style={{ padding: '0 20px', marginBottom: 20, overflowX: 'auto' }}>
          <div style={{ display: 'flex', gap: 4, background: '#1A1F2E', borderRadius: 12, padding: 4, minWidth: 'max-content' }}>
            {[['analytics', '📊 Analytics'], ['speed', `⚡ Speed${overspeed.length > 0 ? ` (${overspeed.length})` : ''}`], ['drivers', '👥 Drivers'], ['requests', `📋 Requests${pendingRequests.length > 0 ? ` (${pendingRequests.length})` : ''}`], ['profile', '👤 Profile']].map(([t, label]) => (
              <button key={t} className={`tab ${tab === t ? 'active' : ''}`} style={{ whiteSpace: 'nowrap', flex: 'none', padding: '9px 14px' }} onClick={() => setTab(t as any)}>{label}</button>
            ))}
          </div>
        </div>

        <div style={{ padding: '0 20px' }}>
          {/* Analytics */}
          {tab === 'analytics' && (
            <>
              <div style={{ background: `${co2Color(totalCo2)}22`, border: `1px solid ${co2Color(totalCo2)}44`, borderRadius: 20, padding: 28, textAlign: 'center', marginBottom: 16 }}>
                <div style={{ fontSize: 24 }}>🏭</div>
                <div style={{ color: 'rgba(255,255,255,0.6)', fontSize: 13, marginTop: 8 }}>Total Fleet CO₂</div>
                <div style={{ fontSize: 52, fontWeight: 800, color: co2Color(totalCo2), lineHeight: 1.1 }}>{totalCo2 >= 1000 ? `${(totalCo2 / 1000).toFixed(2)} t` : `${totalCo2.toFixed(1)} kg`}</div>
                <div style={{ color: co2Color(totalCo2), opacity: 0.7, fontSize: 13 }}>CO₂ — {PERIODS[period]}</div>
              </div>
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 12, marginBottom: 16 }}>
                <div className="metric-card"><div className="metric-label">Drivers</div><div className="metric-value" style={{ color: '#60a5fa' }}>{driverStats.length}</div></div>
                <div className="metric-card"><div className="metric-label">Trips</div><div className="metric-value" style={{ color: '#34d399' }}>{analytics.tripCount ?? 0}</div></div>
                <div className="metric-card"><div className="metric-label">Overspeed</div><div className="metric-value" style={{ color: overspeed.length > 0 ? '#ef4444' : '#6b7280' }}>{overspeed.length}</div></div>
              </div>
              {analytics.aiInsights && (
                <div style={{ background: 'rgba(29,185,84,0.07)', border: '1px solid rgba(29,185,84,0.2)', borderRadius: 14, padding: 18 }}>
                  <div style={{ color: '#1DB954', fontWeight: 700, fontSize: 13, marginBottom: 10, display: 'flex', alignItems: 'center', gap: 8 }}>✨ AI Fleet Insights</div>
                  <div style={{ color: 'rgba(255,255,255,0.75)', fontSize: 13, lineHeight: 1.7 }}>{analytics.aiInsights}</div>
                </div>
              )}
            </>
          )}

          {/* Speed */}
          {tab === 'speed' && (
            overspeed.length === 0
              ? <div style={{ textAlign: 'center', padding: 48 }}><div style={{ fontSize: 48, marginBottom: 12 }}>✅</div><p style={{ color: '#1DB954', fontWeight: 600 }}>No overspeeding events</p><p style={{ color: 'rgba(255,255,255,0.4)', fontSize: 13, marginTop: 4 }}>All drivers within speed limits</p></div>
              : overspeed.map((e: any, i: number) => (
                <div key={i} className="card" style={{ marginBottom: 10, borderColor: 'rgba(239,68,68,0.3)', display: 'flex', alignItems: 'center', gap: 14 }}>
                  <div style={{ width: 44, height: 44, background: 'rgba(239,68,68,0.12)', borderRadius: 10, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 20 }}>🚨</div>
                  <div style={{ flex: 1 }}>
                    <div style={{ fontWeight: 600 }}>{e.driverName}</div>
                    <div style={{ fontSize: 12, color: 'rgba(255,255,255,0.4)' }}>{e.date} at {e.time} • Truck: {e.truckNumber}</div>
                  </div>
                  <div style={{ textAlign: 'right' }}>
                    <div style={{ fontSize: 22, fontWeight: 800, color: '#ef4444' }}>{e.maxSpeed?.toFixed(0)}</div>
                    <div style={{ fontSize: 10, color: '#ef4444' }}>km/h</div>
                  </div>
                </div>
              ))
          )}

          {/* Drivers */}
          {tab === 'drivers' && (
            loading ? <div style={{ display: 'flex', justifyContent: 'center', padding: 40 }}><div className="spinner" /></div>
            : driverStats.length === 0 ? <p style={{ color: 'rgba(255,255,255,0.3)', textAlign: 'center', padding: 32 }}>No drivers yet</p>
            : (
              <>
                <div className="table-header" style={{ gridTemplateColumns: '3fr 2fr 2fr' }}>
                  <span>Driver</span><span>Truck</span><span style={{ textAlign: 'right' }}>CO₂</span>
                </div>
                {driverStats.map(d => {
                  const co2 = d[PERIOD_KEYS[period]] ?? 0;
                  return (
                    <div key={d.id} className="table-row" style={{ gridTemplateColumns: '3fr 2fr 2fr' }}>
                      <div>
                        <div style={{ fontWeight: 600, fontSize: 14 }}>{d.name}</div>
                        <div style={{ fontSize: 11, color: 'rgba(255,255,255,0.4)' }}>{d.location}</div>
                      </div>
                      <div style={{ fontSize: 13, color: 'rgba(255,255,255,0.7)' }}>{d.truck_number ?? '—'}</div>
                      <div style={{ textAlign: 'right', fontWeight: 700, color: co2Color(co2), fontSize: 15 }}>{co2 >= 1000 ? `${(co2 / 1000).toFixed(1)}t` : `${co2.toFixed(1)}kg`}</div>
                    </div>
                  );
                })}
              </>
            )
          )}

          {/* Requests */}
          {tab === 'requests' && (
            pendingRequests.length === 0
              ? <p style={{ color: 'rgba(255,255,255,0.3)', textAlign: 'center', padding: 32 }}>No pending requests</p>
              : pendingRequests.map(req => {
                const d = req.profiles ?? {};
                return (
                  <div key={req.id} className="card" style={{ marginBottom: 14, borderColor: 'rgba(251,146,60,0.2)' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 8 }}>
                      <span style={{ fontSize: 18 }}>👤</span>
                      <span style={{ fontWeight: 700, fontSize: 15 }}>{d.name ?? 'Driver'}</span>
                    </div>
                    <div style={{ fontSize: 12, color: 'rgba(255,255,255,0.5)', marginBottom: 4 }}>Phone: {d.phone ?? '—'}</div>
                    <div style={{ fontSize: 12, color: 'rgba(255,255,255,0.5)', marginBottom: 14 }}>Truck: {d.truck_number ?? '—'}</div>
                    <div style={{ display: 'flex', gap: 10 }}>
                      <button className="btn btn-outline" style={{ flex: 1, color: '#ef4444', borderColor: 'rgba(239,68,68,0.4)' }} onClick={async () => { await respondToRequest(req.id, req.driver_id, false); load(); }}>Reject</button>
                      <button className="btn btn-green" style={{ flex: 1 }} onClick={async () => { await respondToRequest(req.id, req.driver_id, true); load(); }}>Accept</button>
                    </div>
                  </div>
                );
              })
          )}

          {/* Profile */}
          {tab === 'profile' && (
            <div>
              <div style={{ textAlign: 'center', marginBottom: 24 }}>
                <div style={{ width: 72, height: 72, background: 'rgba(59,130,246,0.15)', borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 32, margin: '0 auto 12px' }}>🏢</div>
                <div style={{ fontWeight: 700, fontSize: 20 }}>{profile.name}</div>
                <div style={{ color: '#3b82f6', fontSize: 13 }}>Fleet Owner</div>
              </div>
              {[['Phone', profile.phone], ['Location', profile.location], ['Date of Birth', profile.dob]].map(([l, v]) => v && (
                <div key={l} className="card" style={{ marginBottom: 10 }}>
                  <div style={{ fontSize: 11, color: 'rgba(255,255,255,0.4)' }}>{l}</div>
                  <div style={{ fontSize: 14 }}>{v}</div>
                </div>
              ))}
              <button className="btn btn-outline" style={{ width: '100%', marginTop: 16, color: '#ef4444', borderColor: 'rgba(239,68,68,0.4)' }} onClick={() => signOut()}>Logout</button>
            </div>
          )}
        </div>
      </div>

      {/* AI Assistant */}
      <button onClick={() => setShowChat(c => !c)} style={{ position: 'fixed', bottom: 24, right: 24, width: 56, height: 56, borderRadius: '50%', background: '#3b82f6', border: 'none', fontSize: 24, cursor: 'pointer', boxShadow: '0 4px 20px rgba(59,130,246,0.4)', zIndex: 100 }}>
        {showChat ? '✕' : '🤖'}
      </button>

      {showChat && (
        <div style={{ position: 'fixed', bottom: 90, right: 16, left: 16, maxWidth: 420, margin: '0 auto', background: '#1A1F2E', border: '1px solid rgba(59,130,246,0.3)', borderRadius: 20, boxShadow: '0 8px 40px rgba(0,0,0,0.5)', zIndex: 99, display: 'flex', flexDirection: 'column', height: 380 }}>
          <div style={{ padding: '14px 16px', borderBottom: '1px solid rgba(255,255,255,0.07)', display: 'flex', alignItems: 'center', gap: 8 }}>
            <span style={{ fontSize: 16 }}>🤖</span>
            <span style={{ fontWeight: 700, fontSize: 14 }}>AI Fleet Assistant</span>
            <button onClick={() => setShowChat(false)} style={{ marginLeft: 'auto', background: 'none', border: 'none', color: 'rgba(255,255,255,0.4)', cursor: 'pointer', fontSize: 16 }}>✕</button>
          </div>
          <div style={{ flex: 1, overflowY: 'auto', padding: 12 }}>
            {chatMessages.length === 0 && (
              <div style={{ textAlign: 'center', padding: 24, color: 'rgba(255,255,255,0.3)', fontSize: 13 }}>
                <div style={{ fontSize: 32, marginBottom: 8 }}>💬</div>
                Ask me about your fleet emissions, drivers, or sustainability tips.
              </div>
            )}
            {chatMessages.map((m, i) => (
              <div key={i} style={{ display: 'flex', justifyContent: m.role === 'user' ? 'flex-end' : 'flex-start', marginBottom: 8 }}>
                <div className={`chat-bubble ${m.role === 'user' ? 'chat-user' : 'chat-ai'}`}>{m.content}</div>
              </div>
            ))}
            {chatLoading && <div style={{ display: 'flex', justifyContent: 'flex-start', marginBottom: 8 }}><div className="chat-bubble chat-ai" style={{ display: 'flex', gap: 4 }}><span>●</span><span style={{ opacity: 0.5 }}>●</span><span style={{ opacity: 0.25 }}>●</span></div></div>}
            <div ref={chatEndRef} />
          </div>
          <div style={{ padding: 12, borderTop: '1px solid rgba(255,255,255,0.07)', display: 'flex', gap: 8 }}>
            <input className="input" style={{ flex: 1, fontSize: 13, padding: '10px 12px' }} placeholder="Ask about your fleet..." value={chatInput} onChange={e => setChatInput(e.target.value)} onKeyDown={e => e.key === 'Enter' && sendChat()} />
            <button onClick={sendChat} style={{ width: 40, height: 40, background: '#3b82f6', border: 'none', borderRadius: 10, cursor: 'pointer', fontSize: 16 }}>➤</button>
          </div>
        </div>
      )}
    </div>
  );
}
