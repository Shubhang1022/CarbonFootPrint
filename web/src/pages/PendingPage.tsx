import { useEffect, useState } from 'react';
import { supabase } from '../lib/supabase';
import { getDriverRequestStatus, signOut } from '../lib/auth';

export default function PendingPage({ onApproved }: { onApproved: () => void }) {
  const [status, setStatus] = useState('pending');

  useEffect(() => {
    const interval = setInterval(async () => {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return;
      const s = await getDriverRequestStatus(user.id);
      if (s === 'accepted') { clearInterval(interval); onApproved(); }
      else if (s === 'rejected') setStatus('rejected');
    }, 5000);
    return () => clearInterval(interval);
  }, []);

  return (
    <div className="page" style={{ display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
      <div className="page-inner" style={{ textAlign: 'center' }}>
        {status === 'pending' ? (
          <>
            <div style={{ fontSize: 64, marginBottom: 20 }}>⏳</div>
            <h2 style={{ fontSize: 22, fontWeight: 700, marginBottom: 12 }}>Waiting for Approval</h2>
            <p style={{ color: 'rgba(255,255,255,0.5)', marginBottom: 32, lineHeight: 1.6 }}>Your join request has been sent to the fleet owner. You'll be notified once approved.</p>
            <div style={{ display: 'flex', justifyContent: 'center' }}><div className="spinner" /></div>
          </>
        ) : (
          <>
            <div style={{ fontSize: 64, marginBottom: 20 }}>❌</div>
            <h2 style={{ fontSize: 22, fontWeight: 700, marginBottom: 12 }}>Request Rejected</h2>
            <p style={{ color: 'rgba(255,255,255,0.5)', marginBottom: 32 }}>The fleet owner rejected your request. Contact them directly or try another company.</p>
            <button className="btn btn-green" onClick={() => signOut()}>Go Back to Login</button>
          </>
        )}
      </div>
    </div>
  );
}
