// Cliente Supabase configurado para Fast Orden
(function() {
  const SUPABASE_URL = 'https://yetdmvlisxavxdwdxyyb.supabase.co';
  const SUPABASE_KEY = 'sb_publishable_ysSwpu3wAKcKR4OQzynpTg_Dvk8NznP';

  // Verificar que el CDN de Supabase esté cargado
  if (typeof window.supabase === 'undefined') {
    console.error('Error: El CDN de Supabase no está cargado. Asegúrate de cargar el script de Supabase antes de supabase.js');
    throw new Error('Supabase CDN no encontrado');
  }

  // Inicializar cliente Supabase usando el patrón correcto del CDN v2
  const { createClient } = window.supabase;
  window.supabaseClient = createClient(SUPABASE_URL, SUPABASE_KEY, {
    auth: {
      autoRefreshToken: true,
      persistSession: true,
      detectSessionInUrl: true
    }
  });

  // Log de confirmación (solo en desarrollo)
  console.log('✅ Supabase client inicializado correctamente (v2)');
})();
