// tenant-theme.js - Aplicar tema visual del tenant dinámicamente

const supabase = window.supabaseClient;

/**
 * Cargar tenant por slug
 */
async function loadTenantBySlug(slug) {
  try {
    const { data: tenant, error } = await supabase
      .from('tenants')
      .select('*')
      .eq('slug', slug)
      .eq('activo', true)
      .single();

    if (error) throw error;
    if (!tenant) throw new Error('Tenant no encontrado');

    return tenant;
  } catch (error) {
    console.error('Error al cargar tenant:', error);
    return null;
  }
}

/**
 * Cargar tenant por ID
 */
async function loadTenantById(tenantId) {
  try {
    const { data: tenant, error } = await supabase
      .from('tenants')
      .select('*')
      .eq('id', tenantId)
      .single();

    if (error) throw error;
    return tenant;
  } catch (error) {
    console.error('Error al cargar tenant:', error);
    return null;
  }
}

/**
 * Aplicar tema del tenant a la página
 */
function applyTenantTheme(tenant) {
  if (!tenant) return;

  // Guardar en sessionStorage para uso rápido
  sessionStorage.setItem('current_tenant', JSON.stringify(tenant));

  // Aplicar colores CSS variables
  const root = document.documentElement;
  root.style.setProperty('--color-primary', tenant.color_primary || '#e85d04');
  root.style.setProperty('--color-accent', tenant.color_accent || '#ffd60a');

  // Aplicar título de página
  document.title = `${tenant.nombre} | Menú Digital`;

  // Actualizar elementos con data-tenant
  updateTenantElements(tenant);
}

/**
 * Actualizar elementos del DOM con datos del tenant
 */
function updateTenantElements(tenant) {
  // Logo
  const logoElements = document.querySelectorAll('[data-tenant="logo"]');
  logoElements.forEach(el => {
    if (tenant.logo_url) {
      el.src = tenant.logo_url;
      el.style.display = 'block';
    } else {
      el.style.display = 'none';
    }
  });

  // Nombre
  const nombreElements = document.querySelectorAll('[data-tenant="nombre"]');
  nombreElements.forEach(el => {
    el.textContent = tenant.nombre;
  });

  // Slogan
  const sloganElements = document.querySelectorAll('[data-tenant="slogan"]');
  sloganElements.forEach(el => {
    el.textContent = tenant.slogan || '';
  });

  // WhatsApp
  const whatsappElements = document.querySelectorAll('[data-tenant="whatsapp"]');
  whatsappElements.forEach(el => {
    el.textContent = tenant.whatsapp;
    if (el.tagName === 'A') {
      el.href = `https://wa.me/${tenant.whatsapp.replace(/\D/g, '')}`;
    }
  });

  // Moneda
  const monedaElements = document.querySelectorAll('[data-tenant="moneda"]');
  monedaElements.forEach(el => {
    el.textContent = tenant.moneda || 'RD$';
  });

  // Costo delivery
  const deliveryElements = document.querySelectorAll('[data-tenant="costo-delivery"]');
  deliveryElements.forEach(el => {
    el.textContent = tenant.costo_delivery || 50;
  });
}

/**
 * Obtener tenant guardado en sessionStorage
 */
function getStoredTenant() {
  const tenantStr = sessionStorage.getItem('current_tenant');
  return tenantStr ? JSON.parse(tenantStr) : null;
}

/**
 * Obtener tenant_id del admin logueado
 */
function getAdminTenantId() {
  return sessionStorage.getItem('tenant_id');
}

/**
 * Inicializar tema en menú público (desde URL)
 */
async function initPublicMenuTheme() {
  const urlParams = new URLSearchParams(window.location.search);
  const slug = urlParams.get('tenant');

  if (!slug) {
    console.error('No se especificó slug del tenant en la URL');
    return null;
  }

  const tenant = await loadTenantBySlug(slug);
  if (tenant) {
    applyTenantTheme(tenant);
    return tenant;
  }
  return null;
}

/**
 * Inicializar tema en portal admin
 */
async function initAdminTheme() {
  const tenantId = getAdminTenantId();
  if (!tenantId) {
    console.error('No hay tenant_id en sessionStorage');
    return null;
  }

  const tenant = await loadTenantById(tenantId);
  if (tenant) {
    applyTenantTheme(tenant);
    return tenant;
  }
  return null;
}

// Exponer funciones globalmente
window.tenantTheme = {
  loadTenantBySlug,
  loadTenantById,
  applyTenantTheme,
  updateTenantElements,
  getStoredTenant,
  getAdminTenantId,
  initPublicMenuTheme,
  initAdminTheme
};
