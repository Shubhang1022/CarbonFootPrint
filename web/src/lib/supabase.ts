import { createClient } from '@supabase/supabase-js';

export const supabase = createClient(
  'https://djpppmpbapdydgluirjk.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRqcHBwbXBiYXBkeWRnbHVpcmprIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU0OTkxODQsImV4cCI6MjA5MTA3NTE4NH0.1nCCck14CwihvoSJ25fa0SIDv5L9W7UZOdnpsO8tiBk'
);

export const BACKEND = 'https://carbonfootprint-squc.onrender.com';
