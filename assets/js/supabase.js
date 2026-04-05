// Cliente Supabase configurado para Fast Orden
const SUPABASE_URL = 'https://yetdmvlisxavxdwdxyyb.supabase.co';
const SUPABASE_KEY = 'sb_publishable_ysSwpu3wAKcKR4OQzynpTg_Dvk8NznP';

// Inicializar cliente Supabase
const supabase = window.supabase.createClient(SUPABASE_URL, SUPABASE_KEY, {
  auth: {
    autoRefreshToken: true,
    persistSession: true,
    detectSessionInUrl: true
  }
});

// Exportar para uso en otros módulos
window.supabaseClient = supabase;
