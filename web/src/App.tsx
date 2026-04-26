import { useEffect, useState } from 'react';
import { supabase } from './lib/supabase';
import { getProfile } from './lib/auth';
import LoginPage from './pages/LoginPage';
import OtpPage from './pages/OtpPage';
import ProfileSetupPage from './pages/ProfileSetupPage';
import PendingPage from './pages/PendingPage';
import DriverHome from './pages/DriverHome';
import OwnerDashboard from './pages/OwnerDashboard';

type Screen = 'loading' | 'login' | 'otp' | 'profile-setup' | 'pending' | 'driver' | 'owner';

export default function App() {
  const [screen, setScreen] = useState<Screen>('loading');
  const [role, setRole] = useState<'driver' | 'admin'>('driver');
  const [email, setEmail] = useState('');
  const [profile, setProfile] = useState<any>(null);

  useEffect(() => {
    checkAuth();
    const { data: { subscription } } = supabase.auth.onAuthStateChange(() => checkAuth());
    return () => subscription.unsubscribe();
  }, []);

  async function checkAuth() {
    try {
      const timeout = new Promise<never>((_, reject) => setTimeout(() => reject(new Error('timeout')), 5000));
      const authCheck = async () => {
        const { data: { user } } = await supabase.auth.getUser();
        if (!user) { setScreen('login'); return; }
        const p = await getProfile();
        if (!p) { setScreen('profile-setup'); return; }
        setProfile(p);
        if (p.role === 'admin') { setScreen('owner'); return; }
        if (p.status === 'pending') { setScreen('pending'); return; }
        setScreen('driver');
      };
      await Promise.race([authCheck(), timeout]);
    } catch (e) {
      console.error('Auth check failed:', e);
      setScreen('login');
    }
  }

  if (screen === 'loading') return <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', height: '100vh', background: '#0F1923' }}><div className="spinner" /></div>;
  if (screen === 'login') return <LoginPage onOtpSent={(e, r) => { setEmail(e); setRole(r); setScreen('otp'); }} />;
  if (screen === 'otp') return <OtpPage email={email} role={role} onVerified={checkAuth} />;
  if (screen === 'profile-setup') return <ProfileSetupPage role={role} onDone={checkAuth} />;
  if (screen === 'pending') return <PendingPage onApproved={checkAuth} />;
  if (screen === 'driver') return <DriverHome profile={profile} onRoleSwitch={checkAuth} />;
  if (screen === 'owner') return <OwnerDashboard profile={profile} onRoleSwitch={checkAuth} />;
  return null;
}
