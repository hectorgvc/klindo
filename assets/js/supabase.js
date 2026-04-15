// Cliente Supabase configurado para Klindo
(function() {
  const SUPABASE_URL = 'https://vyfbmqgizgaigxejgrgs.supabase.co';
  const SUPABASE_KEY = 'sb_publishable_IYL-X9TiZFRKHky9N_6qwQ_KJnOxWSc';

  // Verificar que el CDN de Supabase esté cargado
  if (typeof window.supabase === 'undefined') {
    console.error('Error: El CDN de Supabase no está cargado.');
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

  console.log('✅ Klindo — Supabase client inicializado correctamente (v2)');
})();
