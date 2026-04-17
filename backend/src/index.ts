import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import { createClient } from '@supabase/supabase-js';
import addTripRouter from './routes/addTrip';

const app = express();
app.use(cors());
app.use(express.json());

app.use(addTripRouter);

app.get('/health', (_, res) => res.json({ status: 'ok' }));

export default app;

// Only start the server when this file is run directly, not when imported by tests
if (require.main === module) {
  const PORT = process.env.PORT ?? 3000;
  app.listen(PORT, () => {
    console.log(`CarbonChain backend listening on port ${PORT}`);
  });

  // Keep Supabase alive — ping every 12 hours so the free project never pauses
  const supabase = createClient(
    process.env.SUPABASE_URL ?? '',
    process.env.SUPABASE_KEY ?? ''
  );

  const keepAlive = async () => {
    try {
      await supabase.from('emissions').select('id').limit(1);
      console.log('[keep-alive] Supabase pinged successfully');
    } catch (err) {
      console.error('[keep-alive] Supabase ping failed:', err);
    }
  };

  // Ping immediately on startup, then every 12 hours
  keepAlive();
  setInterval(keepAlive, 12 * 60 * 60 * 1000);

  // Keep Render alive — self-ping every 14 minutes to prevent sleep
  const selfUrl = process.env.RENDER_EXTERNAL_URL ?? `http://localhost:${PORT}`;
  setInterval(async () => {
    try {
      await fetch(`${selfUrl}/health`);
      console.log('[keep-alive] Render self-ping ok');
    } catch (_) {}
  }, 14 * 60 * 1000);
}
