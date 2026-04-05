# SPEC.md — Fast Orden
## SaaS Multi-Tenant de Menú Digital con Pedidos por WhatsApp

---

## 1. Resumen del Proyecto

**Fast Orden** es un SaaS multi-tenant que permite a negocios de comida (restaurantes, food trucks, puestos) tener su propio portal de menú digital con pedidos por WhatsApp, panel de administración y personalización de marca.

### Portales:
- **`fast-orden.com/[slug]`** — Menú público del tenant (accesible por cualquier cliente final)
- **`fast-orden.com/admin`** — Portal admin del tenant (gestión de su negocio)
- **`fast-orden.com/superadmin`** — Portal superadmin (solo el dueño de Fast Orden)
- **`fast-orden.com/`** — Landing page de Fast Orden (v2, por ahora redirige a /login)
- **`fast-orden.com/login`** — Login unificado para todos los admins

**Stack:** HTML + CSS + Vanilla JS | Supabase (DB + Auth + Storage) | GitHub Pages

---

## 2. Stack Tecnológico

| Capa | Tecnología |
|---|---|
| Frontend | HTML5, CSS3, Vanilla JavaScript (ES Modules) |
| Estilos | Tailwind CSS via CDN |
| Iconos | Lucide Icons via CDN |
| Base de datos | Supabase (PostgreSQL) |
| Autenticación | Supabase Auth |
| Storage | Supabase Storage (logos de tenants, fotos de productos) |
| Hosting | GitHub Pages |
| Idioma UI | Español |
| Pedidos | WhatsApp API (wa.me link) |

---

## 3. Planes y Precios

| Plan | Precio mensual | Precio anual | Límite productos |
|---|---|---|---|
| Básico | RD$800/mes | RD$8,160/año (-15%) | 30 productos |
| Pro | RD$1,500/mes | RD$15,300/año (-15%) | Ilimitado |

- Ciclo: mensual o anual (el tenant elige al momento de ser registrado)
- Descuento anual: 15%
- Control de plan gestionado por superadmin (v1) — self-service en v2
- Al vencer el plan: tenant queda en modo lectura (menú visible, admin bloqueado)

---

## 4. Estructura de Archivos

```
/
├── index.html                     → Redirect a /login (landing en v2)
├── login.html                     → Login unificado todos los admins
├── menu.html                      → Menú público del tenant (lee slug de URL)
├── cuentas.html                   → Cuentas bancarias del tenant (desde URL)
├── admin/
│   ├── index.html                 → Dashboard del tenant
│   ├── productos.html             → CRUD productos
│   ├── categorias.html            → CRUD categorías
│   ├── cuentas.html               → CRUD cuentas bancarias
│   └── configuracion.html         → Personalización del sitio
├── superadmin/
│   ├── index.html                 → Dashboard superadmin
│   ├── tenants.html               → Gestión de tenants
│   └── crear-tenant.html          → Crear nuevo tenant
└── assets/
    ├── css/main.css
    ├── js/
    │   ├── supabase.js            → Cliente Supabase
    │   ├── auth.js                → Lógica de autenticación y redirección
    │   ├── menu.js                → Carga menú público del tenant
    │   ├── carrito.js             → Lógica del carrito
    │   ├── pedido.js              → Flujo de pedido + WhatsApp
    │   ├── cuentas.js             → Cuentas bancarias + copiar
    │   ├── admin.js               → Lógica portal admin
    │   ├── superadmin.js          → Lógica portal superadmin
    │   └── tenant-theme.js        → Aplicar tema visual del tenant
    └── img/
        └── fast-orden-logo.png    → Logo de Fast Orden
```

---

## 5. Base de Datos — Supabase

### Tabla: `tenants`
```sql
create table public.tenants (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null,             -- ej: 'castillosabor'
  nombre text not null,                  -- ej: 'Mi Castillo Sabor'
  slogan text,
  logo_url text,                         -- URL de Supabase Storage
  whatsapp text not null,                -- ej: '+18098309706'
  costo_delivery numeric(10,2) default 50,
  moneda text default 'RD$',             -- 'RD$' | 'USD'
  color_primary text default '#e85d04',
  color_accent text default '#ffd60a',
  plan text default 'basico',            -- 'basico' | 'pro'
  ciclo text default 'mensual',          -- 'mensual' | 'anual'
  plan_expira_at timestamptz,
  activo boolean default true,
  created_at timestamptz default now()
);
```

### Tabla: `profiles`
```sql
create table public.profiles (
  id uuid references auth.users(id) on delete cascade primary key,
  tenant_id uuid references public.tenants(id) on delete cascade,
  nombre text not null,
  email text not null,
  rol text not null default 'admin',     -- 'superadmin' | 'admin'
  activo boolean default true,
  created_at timestamptz default now()
);
```

### Tabla: `categorias`
```sql
create table public.categorias (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid references public.tenants(id) on delete cascade not null,
  nombre text not null,
  emoji text,
  orden int default 0,
  activa boolean default true,
  created_at timestamptz default now()
);
```

### Tabla: `productos`
```sql
create table public.productos (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid references public.tenants(id) on delete cascade not null,
  categoria_id uuid references public.categorias(id) on delete set null,
  nombre text not null,
  descripcion text,
  precio numeric(10,2) not null,
  disponible boolean default true,
  imagen_url text,
  orden int default 0,
  created_at timestamptz default now()
);
```

### Tabla: `cuentas_bancarias`
```sql
create table public.cuentas_bancarias (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid references public.tenants(id) on delete cascade not null,
  banco text not null,
  numero text not null,
  titular text not null,
  tipo_cuenta text,
  activa boolean default true,
  orden int default 0,
  created_at timestamptz default now()
);
```

---

## 6. RLS — Row Level Security

```sql
-- TENANTS
alter table public.tenants enable row level security;

-- Lectura pública (para cargar el menú)
create policy "Lectura publica tenants"
  on public.tenants for select using (true);

-- Solo superadmin puede crear/editar tenants
create policy "Superadmin gestiona tenants"
  on public.tenants for all
  using (
    exists (
      select 1 from public.profiles
      where id = auth.uid() and rol = 'superadmin'
    )
  );

-- PROFILES
alter table public.profiles enable row level security;

create policy "Usuario ve su perfil"
  on public.profiles for select
  using (auth.uid() = id);

create policy "Superadmin ve todos los perfiles"
  on public.profiles for select
  using (
    exists (
      select 1 from public.profiles
      where id = auth.uid() and rol = 'superadmin'
    )
  );

-- CATEGORIAS
alter table public.categorias enable row level security;

-- Lectura pública (para el menú)
create policy "Lectura publica categorias"
  on public.categorias for select using (true);

-- Admin solo gestiona categorias de su tenant
create policy "Admin gestiona sus categorias"
  on public.categorias for all
  using (
    exists (
      select 1 from public.profiles
      where id = auth.uid()
        and tenant_id = categorias.tenant_id
        and activo = true
    )
  );

-- Superadmin gestiona todas
create policy "Superadmin gestiona todas las categorias"
  on public.categorias for all
  using (
    exists (
      select 1 from public.profiles
      where id = auth.uid() and rol = 'superadmin'
    )
  );

-- Restriccion de plan: maximo 30 productos en plan basico
-- (validar en frontend antes de insertar)

-- PRODUCTOS
alter table public.productos enable row level security;

create policy "Lectura publica productos"
  on public.productos for select using (true);

create policy "Admin gestiona sus productos"
  on public.productos for all
  using (
    exists (
      select 1 from public.profiles
      where id = auth.uid()
        and tenant_id = productos.tenant_id
        and activo = true
    )
  );

create policy "Superadmin gestiona todos los productos"
  on public.productos for all
  using (
    exists (
      select 1 from public.profiles
      where id = auth.uid() and rol = 'superadmin'
    )
  );

-- CUENTAS BANCARIAS
alter table public.cuentas_bancarias enable row level security;

create policy "Lectura publica cuentas"
  on public.cuentas_bancarias for select using (true);

create policy "Admin gestiona sus cuentas"
  on public.cuentas_bancarias for all
  using (
    exists (
      select 1 from public.profiles
      where id = auth.uid()
        and tenant_id = cuentas_bancarias.tenant_id
        and activo = true
    )
  );

create policy "Superadmin gestiona todas las cuentas"
  on public.cuentas_bancarias for all
  using (
    exists (
      select 1 from public.profiles
      where id = auth.uid() and rol = 'superadmin'
    )
  );
```

---

## 7. Storage — Buckets

```sql
-- Bucket público: logos de tenants y fotos de productos
insert into storage.buckets (id, name, public)
values ('tenant-assets', 'tenant-assets', true);

-- Política: lectura pública
create policy "Lectura publica tenant-assets"
  on storage.objects for select
  using (bucket_id = 'tenant-assets');

-- Política: admin sube assets de su tenant
-- (path del archivo: {tenant_id}/{filename})
create policy "Admin sube sus assets"
  on storage.objects for insert
  with check (
    bucket_id = 'tenant-assets' and
    auth.uid() is not null
  );

create policy "Admin borra sus assets"
  on storage.objects for delete
  using (
    bucket_id = 'tenant-assets' and
    auth.uid() is not null
  );
```

---

## 8. Flujo de Autenticación y Redirección

### login.html
1. Admin ingresa email + contraseña
2. Supabase Auth valida
3. Se consulta `profiles` para obtener `rol` y `tenant_id`
4. Si `rol == 'superadmin'` → redirigir a `/superadmin/index.html`
5. Si `rol == 'admin'` → redirigir a `/admin/index.html`
6. El `tenant_id` se guarda en `sessionStorage` para uso en todo el admin

### Protección de rutas admin
```javascript
// Al cargar cualquier página /admin/*
const { data: { session } } = await supabase.auth.getSession();
if (!session) window.location.href = '/login.html';

const { data: profile } = await supabase
  .from('profiles')
  .select('*, tenants(*)')
  .eq('id', session.user.id)
  .single();

if (!profile.activo || !profile.tenants.activo) {
  // Plan vencido o tenant inactivo
  window.location.href = '/login.html?error=plan_vencido';
}
```

### Protección de rutas superadmin
```javascript
if (profile.rol !== 'superadmin') window.location.href = '/admin/index.html';
```

---

## 9. Menú Público — menu.html

### Carga del tenant
```javascript
// URL: fast-orden.com/menu.html?tenant=castillosabor
// O con path: fast-orden.com/castillosabor (requiere rewrite, no disponible en GitHub Pages)
// Usar query param para GitHub Pages: ?tenant=slug

const slug = new URLSearchParams(window.location.search).get('tenant');
const { data: tenant } = await supabase
  .from('tenants')
  .select('*')
  .eq('slug', slug)
  .eq('activo', true)
  .single();
```

### Aplicar tema del tenant (tenant-theme.js)
```javascript
document.documentElement.style.setProperty('--color-primary', tenant.color_primary);
document.documentElement.style.setProperty('--color-accent', tenant.color_accent);
document.title = tenant.nombre;
// Aplicar logo, nombre, slogan dinámicamente
```

### Funcionalidades
- Navbar: logo del tenant, nombre, icono carrito con badge
- Hero: nombre y slogan del tenant
- Buscador en tiempo real por nombre/descripcion
- Tabs por categorias activas del tenant
- Cards de productos con precio en moneda del tenant
- Carrito lateral con flujo de pedido completo
- Aviso de ubicacion si elige Delivery
- Costo delivery desde `tenant.costo_delivery`

### Flujo de pedido
Igual que Mi Castillo Sabor pero con datos dinamicos del tenant:
- WhatsApp: `tenant.whatsapp`
- Moneda: `tenant.moneda`
- Costo delivery: `tenant.costo_delivery`

---

## 10. Portal Admin — /admin

### admin/index.html — Dashboard
- Nombre del negocio y plan activo (con fecha de vencimiento)
- Alerta si el plan vence en menos de 15 días
- Contadores: productos activos, categorias, plan y límite
- Barra de progreso de productos usados (plan básico: X/30)
- Accesos rápidos a cada sección
- Botón "Ver mi menú" → abre fast-orden.com/menu.html?tenant=[slug]

### admin/productos.html
- Tabla: nombre, categoria, precio, disponible (toggle), acciones
- Contador de productos vs límite del plan
- Si plan básico y tiene 30 productos: botón "Agregar" deshabilitado con mensaje
  "Alcanzaste el límite de tu plan. Actualiza a Pro para agregar más productos."
- Formulario agregar/editar: nombre, descripcion, precio, categoria, disponible, subir imagen
- Imagen: upload a Supabase Storage bucket `tenant-assets/{tenant_id}/productos/`

### admin/categorias.html
- Lista: nombre, emoji, orden, activa
- Agregar, editar, toggle, eliminar (si no tiene productos)

### admin/cuentas.html
- Lista de cuentas bancarias
- Agregar, editar, toggle, eliminar

### admin/configuracion.html — NUEVO
Permite personalizar el sitio del tenant:

**Información del negocio:**
- Nombre del negocio
- Slogan
- WhatsApp de pedidos
- Moneda (RD$ | USD)
- Costo de delivery

**Apariencia:**
- Subir logo (upload a Storage, preview inmediato)
- Color primario (color picker) — con preview en tiempo real
- Color de acento (color picker) — con preview en tiempo real
- Preview del menú con los colores seleccionados

**Al guardar:** update en tabla `tenants` con los nuevos valores

---

## 11. Portal Superadmin — /superadmin

### superadmin/index.html — Dashboard
- Total de tenants activos
- Tenants por plan (básico vs pro)
- Tenants con plan próximo a vencer (próximos 15 días)
- Ingresos estimados del mes (suma de planes activos)
- Lista de últimos tenants creados

### superadmin/tenants.html
- Tabla de todos los tenants:
  nombre, slug, plan, ciclo, vence, activo, acciones
- Filtros: plan, activo/inactivo
- Acciones: ver menú, editar, activar/desactivar
- Botón "Crear Tenant"

### superadmin/crear-tenant.html
Formulario completo para dar de alta un nuevo cliente:

**Datos del negocio:**
- Nombre, slug (auto-generado desde nombre, editable)
- Slogan
- WhatsApp
- Moneda (default RD$)
- Costo delivery (default 50)

**Plan:**
- Plan: básico | pro
- Ciclo: mensual | anual
- Fecha inicio (default hoy)
- Fecha vencimiento (calculada automáticamente)

**Admin del tenant:**
- Nombre del administrador
- Email
- Contraseña temporal

**Al crear:**
1. Insert en `tenants`
2. Crear usuario en Supabase Auth con `supabase.auth.admin.createUser()`
3. Insert en `profiles` con `tenant_id` y `rol: 'admin'`
4. Mostrar resumen con URL del menú y credenciales

---

## 12. Restricción de Plan — Lógica Frontend

```javascript
// Verificar límite antes de agregar producto
async function puedeAgregarProducto(tenantId, plan) {
  if (plan === 'pro') return true;

  const { count } = await supabase
    .from('productos')
    .select('*', { count: 'exact', head: true })
    .eq('tenant_id', tenantId);

  return count < 30;
}
```

---

## 13. Mensaje WhatsApp (dinámico por tenant)

```javascript
function generarMensajeWP(tenant, pedido, cliente) {
  const moneda = tenant.moneda; // 'RD$' o 'USD'
  return `
${tenant.nombre} — Nuevo Pedido

Cliente: ${cliente.nombre}
Telefono: ${cliente.telefono}
Entrega: ${pedido.tipo_entrega === 'delivery'
  ? `Delivery (+${moneda}${tenant.costo_delivery})`
  : 'Retirar en local'}
Pago: ${pedido.metodo_pago}

Pedido:
${pedido.items.map(i => `- ${i.cantidad}x ${i.nombre} — ${moneda}${i.subtotal}`).join('\n')}

Subtotal: ${moneda}${pedido.subtotal}
Delivery: ${moneda}${pedido.delivery}
TOTAL: ${moneda}${pedido.total}
${pedido.tipo_entrega === 'delivery'
  ? '\nEl cliente enviara su ubicacion a continuacion.' : ''}
  `.trim();
}
```

---

## 14. Identidad Visual — Fast Orden

### Paleta Fast Orden (para login, superadmin y landing futura)
```css
:root {
  --fo-bg: #0a0a0a;
  --fo-surface: #141414;
  --fo-primary: #f97316;       /* Naranja Fast Orden */
  --fo-accent: #facc15;
  --fo-text: #f5f5f5;
  --fo-text-muted: #9ca3af;
  --fo-border: #2a2a2a;
}
```

### Paleta de tenant (aplicada dinámicamente)
```css
:root {
  --color-primary: [tenant.color_primary];
  --color-accent: [tenant.color_accent];
  /* resto igual al sistema del Castillo */
}
```

### Tipografia
- Fast Orden UI: `Bebas Neue` (titulos) + `Nunito` (body)
- Tenants heredan la misma tipografia

---

## 15. URL Structure en GitHub Pages

GitHub Pages no soporta rewrites. Las URLs funcionan así:

```
fast-orden.com/menu.html?tenant=castillosabor     → Menú del Castillo
fast-orden.com/menu.html?tenant=meloburger        → Menú de D'Melo
fast-orden.com/login.html                         → Login admin
fast-orden.com/admin/index.html                   → Dashboard admin
fast-orden.com/superadmin/index.html              → Dashboard superadmin
```

En v2 con dominio propio y hosting real (Netlify/Vercel) se pueden usar paths limpios:
```
fast-orden.com/castillosabor
fast-orden.com/meloburger
```

---

## 16. Setup Inicial Supabase

1. Crear proyecto en supabase.com
2. Ejecutar SQL: tablas → RLS → Storage
3. Crear usuario superadmin desde Authentication → Users
4. Insertar en `profiles`: `{ rol: 'superadmin', nombre: 'Tu nombre', email: '...' }`
5. Copiar `Project URL` y `publishable key` a `assets/js/supabase.js`
6. Crear primer tenant desde `/superadmin/crear-tenant.html`

---

## 17. Roadmap v2 (fuera del scope actual)

- Landing page de Fast Orden con listado de clientes
- Self-service: registro de tenants con pago online
- Pasarela de pago (Azul, PayPal o Stripe)
- URLs limpias con Netlify/Vercel rewrites (`fast-orden.com/castillosabor`)
- Notificaciones por email al vencer el plan
- Historial de pedidos por tenant
- Panel de analíticas básicas (pedidos por día, productos más pedidos)
- App móvil (PWA)
