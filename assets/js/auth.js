// Auth.js - Lógica de autenticación y redirección para Klindo
// Usar window.supabaseClient directamente para evitar redeclaración
// FIX: Consultas separadas + maybeSingle() para evitar "Cannot coerce to single JSON object"

/**
 * Iniciar sesión con email y contraseña
 */
async function login(email, password) {
  try {
    const { data, error } = await window.supabaseClient.auth.signInWithPassword({
      email,
      password
    });

    if (error) throw error;

    // Paso 1: Obtener perfil (SIN join para evitar coerce error)
    const { data: profile, error: profileError } = await window.supabaseClient
      .from('profiles')
      .select('*')
      .eq('id', data.user.id)
      .maybeSingle();

    if (profileError) throw profileError;

    if (!profile) {
      await window.supabaseClient.auth.signOut();
      throw new Error('Perfil de usuario no encontrado. Contacta al soporte.');
    }

    // Verificar si el usuario está activo
    if (!profile.activo) {
      await window.supabaseClient.auth.signOut();
      throw new Error('Usuario inactivo. Contacta al soporte.');
    }

    // Paso 2: Obtener tenant por separado (si aplica)
    let tenant = null;
    if (profile.tenant_id) {
      const { data: tenantData } = await window.supabaseClient
        .from('tenants')
        .select('*')
        .eq('id', profile.tenant_id)
        .maybeSingle();
      tenant = tenantData;
    }

    // Guardar en sessionStorage
    if (profile.tenant_id) {
      sessionStorage.setItem('tenant_id', profile.tenant_id);
    }
    sessionStorage.setItem('user_role', profile.rol);
    sessionStorage.setItem('user_name', profile.nombre);

    // Guardar slug del tenant en localStorage para mostrar logo en login
    if (tenant && tenant.slug) {
      localStorage.setItem('last_tenant_slug', tenant.slug);
    }

    // Redirigir según el rol
    if (profile.rol === 'superadmin') {
      window.location.href = 'superadmin/index.html';
    } else if (profile.rol === 'admin' || profile.rol === 'operador') {
      // Verificar si el tenant está activo
      if (tenant && !tenant.activo) {
        await window.supabaseClient.auth.signOut();
        throw new Error('El negocio está inactivo. Contacta al soporte.');
      }

      // Verificar plan vencido
      const planVencido = tenant?.plan_expira_at && new Date(tenant.plan_expira_at) < new Date();
      if (planVencido) {
        sessionStorage.setItem('plan_vencido', 'true');
      }

      window.location.href = 'recepcion.html';
    } else if (profile.rol === 'repartidor') {
      window.location.href = 'delivery.html';
    } else {
      throw new Error('Rol no válido');
    }

    return { success: true, user: data.user, profile, tenant };
  } catch (error) {
    console.error('Error de login:', error);
    return { success: false, error: error.message };
  }
}

/**
 * Cerrar sesión
 */
async function logout() {
  try {
    await window.supabaseClient.auth.signOut();
    sessionStorage.clear();
    window.location.href = 'login.html';
  } catch (error) {
    console.error('Error al cerrar sesión:', error);
    window.location.href = 'login.html';
  }
}

/**
 * Obtener sesión actual
 */
async function getSession() {
  const { data: { session }, error } = await window.supabaseClient.auth.getSession();
  return { session, error };
}

/**
 * Obtener perfil del usuario actual (consultas separadas, sin join)
 */
async function getCurrentProfile() {
  const { data: { session } } = await window.supabaseClient.auth.getSession();
  if (!session) return null;

  // Paso 1: perfil
  const { data: profile, error: profileErr } = await window.supabaseClient
    .from('profiles')
    .select('*')
    .eq('id', session.user.id)
    .maybeSingle();

  if (profileErr || !profile) {
    console.error('Error al obtener perfil:', profileErr);
    return null;
  }

  // Paso 2: tenant
  if (profile.tenant_id) {
    const { data: tenant } = await window.supabaseClient
      .from('tenants')
      .select('*')
      .eq('id', profile.tenant_id)
      .maybeSingle();

    profile.tenants = tenant;
  }

  return profile;
}

/**
 * Proteger rutas admin — llamar al inicio de cada página /admin/* y recepcion.html
 */
async function protectAdminRoute() {
  const { data: { session } } = await window.supabaseClient.auth.getSession();

  if (!session) {
    window.location.href = 'login.html';
    return null;
  }

  const profile = await getCurrentProfile();

  if (!profile) {
    await logout();
    return null;
  }

  // Verificar rol
  if (profile.rol !== 'admin' && profile.rol !== 'superadmin' && profile.rol !== 'operador') {
    window.location.href = 'login.html?error=unauthorized';
    return null;
  }

  // Si es admin/operador, verificar tenant activo
  if (profile.rol === 'admin' || profile.rol === 'operador') {
    if (!profile.tenants || !profile.tenants.activo) {
      await logout();
      return null;
    }

    // Guardar tenant_id en sessionStorage
    sessionStorage.setItem('tenant_id', profile.tenant_id);

    // Verificar plan vencido
    const planVencido = profile.tenants?.plan_expira_at && new Date(profile.tenants.plan_expira_at) < new Date();
    if (planVencido && !window.location.href.includes('renovar')) {
      window.location.href = 'admin/renovar.html';
      return null;
    }
  }

  return profile;
}

/**
 * Proteger rutas superadmin
 */
async function protectSuperadminRoute() {
  const { data: { session } } = await window.supabaseClient.auth.getSession();

  if (!session) {
    window.location.href = 'login.html';
    return null;
  }

  const profile = await getCurrentProfile();

  if (!profile || profile.rol !== 'superadmin') {
    window.location.href = 'recepcion.html';
    return null;
  }

  return profile;
}

/**
 * Verificar si el plan está próximo a vencer (menos de 15 días)
 */
function planProximoAVencer(planExpiraAt) {
  if (!planExpiraAt) return false;
  const diasRestantes = Math.ceil((new Date(planExpiraAt) - new Date()) / (1000 * 60 * 60 * 24));
  return diasRestantes <= 15 && diasRestantes > 0;
}

/**
 * Verificar si el plan está vencido
 */
function planVencido(planExpiraAt) {
  if (!planExpiraAt) return false;
  return new Date(planExpiraAt) < new Date();
}

// Exponer funciones globalmente
window.auth = {
  login,
  logout,
  getSession,
  getCurrentProfile,
  protectAdminRoute,
  protectSuperadminRoute,
  planProximoAVencer,
  planVencido
};
