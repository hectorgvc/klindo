// Auth.js - Lógica de autenticación y redirección para Fast Orden

const supabase = window.supabaseClient;

/**
 * Iniciar sesión con email y contraseña
 */
async function login(email, password) {
  try {
    const { data, error } = await supabase.auth.signInWithPassword({
      email,
      password
    });

    if (error) throw error;

    // Obtener perfil del usuario para determinar rol
    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select('*, tenants(*)')
      .eq('id', data.user.id)
      .single();

    if (profileError) throw profileError;

    if (!profile) {
      throw new Error('Perfil no encontrado');
    }

    // Verificar si el usuario está activo
    if (!profile.activo) {
      await supabase.auth.signOut();
      throw new Error('Usuario inactivo. Contacta al soporte.');
    }

    // Guardar tenant_id en sessionStorage para uso rápido
    if (profile.tenant_id) {
      sessionStorage.setItem('tenant_id', profile.tenant_id);
    }

    // Guardar rol
    sessionStorage.setItem('user_role', profile.rol);
    sessionStorage.setItem('user_name', profile.nombre);

    // Redirigir según el rol
    if (profile.rol === 'superadmin') {
      window.location.href = '/superadmin/index.html';
    } else if (profile.rol === 'admin') {
      // Verificar si el tenant está activo
      if (profile.tenants && !profile.tenants.activo) {
        await supabase.auth.signOut();
        throw new Error('El negocio está inactivo. Contacta al soporte.');
      }

      // Verificar plan
      const planVencido = profile.tenants?.plan_expira_at && new Date(profile.tenants.plan_expira_at) < new Date();
      if (planVencido) {
        // Permitir login pero redirigir a renovación
        sessionStorage.setItem('plan_vencido', 'true');
      }

      window.location.href = '/admin/index.html';
    } else {
      throw new Error('Rol no válido');
    }

    return { success: true, user: data.user, profile };
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
    await supabase.auth.signOut();
    sessionStorage.clear();
    window.location.href = '/login.html';
  } catch (error) {
    console.error('Error al cerrar sesión:', error);
  }
}

/**
 * Obtener sesión actual
 */
async function getSession() {
  const { data: { session }, error } = await supabase.auth.getSession();
  return { session, error };
}

/**
 * Obtener perfil del usuario actual
 */
async function getCurrentProfile() {
  const { data: { session } } = await supabase.auth.getSession();
  if (!session) return null;

  const { data: profile, error } = await supabase
    .from('profiles')
    .select('*, tenants(*)')
    .eq('id', session.user.id)
    .single();

  if (error) {
    console.error('Error al obtener perfil:', error);
    return null;
  }

  return profile;
}

/**
 * Proteger rutas admin - debe llamarse al inicio de cada página /admin/*
 */
async function protectAdminRoute() {
  const { data: { session } } = await supabase.auth.getSession();

  if (!session) {
    window.location.href = '/login.html';
    return null;
  }

  const profile = await getCurrentProfile();

  if (!profile) {
    await logout();
    return null;
  }

  // Verificar rol admin o superadmin
  if (profile.rol !== 'admin' && profile.rol !== 'superadmin') {
    window.location.href = '/login.html?error=unauthorized';
    return null;
  }

  // Si es admin (no superadmin), verificar tenant activo
  if (profile.rol === 'admin') {
    if (!profile.tenants || !profile.tenants.activo) {
      await logout();
      return null;
    }

    // Guardar tenant_id en sessionStorage
    sessionStorage.setItem('tenant_id', profile.tenant_id);

    // Verificar plan
    const planVencido = profile.tenants?.plan_expira_at && new Date(profile.tenants.plan_expira_at) < new Date();
    if (planVencido) {
      // Redirigir a página de renovación si no está ya ahí
      if (!window.location.href.includes('renovar')) {
        window.location.href = '/admin/renovar.html';
        return null;
      }
    }
  }

  return profile;
}

/**
 * Proteger rutas superadmin - debe llamarse al inicio de cada página /superadmin/*
 */
async function protectSuperadminRoute() {
  const { data: { session } } = await supabase.auth.getSession();

  if (!session) {
    window.location.href = '/login.html';
    return null;
  }

  const profile = await getCurrentProfile();

  if (!profile || profile.rol !== 'superadmin') {
    window.location.href = '/admin/index.html';
    return null;
  }

  return profile;
}

/**
 * Verificar si el admin puede agregar productos según su plan
 */
async function puedeAgregarProducto(tenantId, plan) {
  if (plan === 'pro') return { canAdd: true };

  const { count, error } = await supabase
    .from('productos')
    .select('*', { count: 'exact', head: true })
    .eq('tenant_id', tenantId);

  if (error) {
    console.error('Error al contar productos:', error);
    return { canAdd: false, error: error.message };
  }

  return { canAdd: count < 30, currentCount: count, limit: 30 };
}

/**
 * Verificar si el plan está próximo a vencer (menos de 15 días)
 */
function planProximoAVencer(planExpiraAt) {
  if (!planExpiraAt) return false;
  const fechaVencimiento = new Date(planExpiraAt);
  const hoy = new Date();
  const diasRestantes = Math.ceil((fechaVencimiento - hoy) / (1000 * 60 * 60 * 24));
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
  puedeAgregarProducto,
  planProximoAVencer,
  planVencido
};
