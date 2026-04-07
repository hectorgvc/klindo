# SPEC_fastorden_pro.md — Fast Orden Pro
## Módulos adicionales al plan Lite

---

## 1. Resumen del Pro

El plan Pro agrega sobre el Lite:
- Sistema de pedidos con estados en tiempo real
- Módulo de Caja (cajera)
- Módulo de Cocina (pantalla de órdenes)
- Módulo de Turnos (pantalla pública TV)
- Seguimiento de orden por el cliente (URL única)
- Notas predefinidas por producto
- Dashboard con estadísticas reales
- Dos mensajes WhatsApp: uno al negocio, uno al cliente

Tecnología clave: **Supabase Realtime** para actualización instantánea entre módulos.

---

## 2. Nuevas Páginas

```
/caja.html?tenant=slug          → Módulo cajera
/cocina.html?tenant=slug        → Módulo cocina (solo lectura)
/turnos.html?tenant=slug        → Pantalla pública de turnos (TV)
/orden.html?id=uuid             → Seguimiento de orden del cliente
/admin/pedidos.html             → Historial de pedidos del tenant
/admin/dashboard.html           → Dashboard con estadísticas
/admin/notas.html               → Gestión de notas predefinidas
```

---

## 3. Nuevas Tablas Supabase

### Tabla: `pedidos`
```sql
create table public.pedidos (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid references public.tenants(id) on delete cascade not null,
  numero_dia int not null,               -- reinicia cada día: 1, 2, 3...
  tipo text not null default 'local',    -- 'local' | 'delivery'
  estado text not null default 'pendiente',
  -- Estados: pendiente | en_preparacion | listo | entregado | cancelado
  metodo_pago text,                      -- 'efectivo' | 'transferencia'
  pagado boolean default false,
  cliente_nombre text not null,
  cliente_telefono text,
  notas_generales text,
  subtotal numeric(10,2) not null,
  costo_delivery numeric(10,2) default 0,
  total numeric(10,2) not null,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  constraint estado_valido check (
    estado in ('pendiente','en_preparacion','listo','entregado','cancelado')
  )
);
```

### Tabla: `items_pedido`
```sql
create table public.items_pedido (
  id uuid primary key default gen_random_uuid(),
  pedido_id uuid references public.pedidos(id) on delete cascade not null,
  producto_id uuid references public.productos(id) on delete set null,
  nombre text not null,                  -- snapshot del nombre al momento del pedido
  precio numeric(10,2) not null,         -- snapshot del precio
  cantidad int not null default 1,
  notas text[],                          -- ['Sin cebolla', 'Sin pepinillo']
  subtotal numeric(10,2) not null,
  created_at timestamptz default now()
);
```

### Tabla: `notas_predefinidas`
```sql
create table public.notas_predefinidas (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid references public.tenants(id) on delete cascade not null,
  texto text not null,                   -- 'Sin cebolla', 'Sin pepinillo', etc.
  activa boolean default true,
  orden int default 0,
  created_at timestamptz default now()
);
```

### Tabla: `configuracion_pro`
```sql
create table public.configuracion_pro (
  tenant_id uuid references public.tenants(id) on delete cascade primary key,
  contador_fecha date default current_date,
  ultimo_numero int default 0,           -- ultimo numero de orden del dia
  created_at timestamptz default now()
);
```

---

## 4. RLS Nuevas Tablas

```sql
-- PEDIDOS
alter table public.pedidos enable row level security;

create policy "Lectura publica pedidos por id"
  on public.pedidos for select
  using (true);

create policy "Insercion publica de pedidos"
  on public.pedidos for insert
  with check (true);

create policy "Admin gestiona sus pedidos"
  on public.pedidos for update
  using (
    exists (
      select 1 from public.profiles
      where id = auth.uid()
        and tenant_id = pedidos.tenant_id
        and activo = true
    )
  );

create policy "Superadmin gestiona todos los pedidos"
  on public.pedidos for all
  using (
    exists (
      select 1 from public.profiles
      where id = auth.uid() and rol = 'superadmin'
    )
  );

-- ITEMS_PEDIDO
alter table public.items_pedido enable row level security;

create policy "Lectura publica items"
  on public.items_pedido for select using (true);

create policy "Insercion publica items"
  on public.items_pedido for insert
  with check (true);

-- NOTAS_PREDEFINIDAS
alter table public.notas_predefinidas enable row level security;

create policy "Lectura publica notas"
  on public.notas_predefinidas for select using (true);

create policy "Admin gestiona sus notas"
  on public.notas_predefinidas for all
  using (
    exists (
      select 1 from public.profiles
      where id = auth.uid()
        and tenant_id = notas_predefinidas.tenant_id
        and activo = true
    )
  );

-- CONFIGURACION_PRO
alter table public.configuracion_pro enable row level security;

create policy "Lectura publica config pro"
  on public.configuracion_pro for select using (true);

create policy "Admin gestiona su config"
  on public.configuracion_pro for all
  using (
    exists (
      select 1 from public.profiles
      where id = auth.uid()
        and tenant_id = configuracion_pro.tenant_id
        and activo = true
    )
  );
```

---

## 5. Función: Numero de Orden Diario

```sql
create or replace function public.get_next_numero_orden(p_tenant_id uuid)
returns int as $$
declare
  v_numero int;
  v_fecha date := current_date;
begin
  -- Si no existe config, crearla
  insert into public.configuracion_pro (tenant_id, contador_fecha, ultimo_numero)
  values (p_tenant_id, v_fecha, 0)
  on conflict (tenant_id) do nothing;

  -- Si cambio el dia, resetear contador
  update public.configuracion_pro
  set ultimo_numero = 0, contador_fecha = v_fecha
  where tenant_id = p_tenant_id
    and contador_fecha < v_fecha;

  -- Incrementar y retornar
  update public.configuracion_pro
  set ultimo_numero = ultimo_numero + 1
  where tenant_id = p_tenant_id
  returning ultimo_numero into v_numero;

  return v_numero;
end;
$$ language plpgsql security definer;
```

---

## 6. Flujo de Pedido Pro (menu.html actualizado)

### Notas por producto
Al agregar un producto al carrito en plan Pro:
- Aparece un modal con las notas predefinidas del tenant
- Checkboxes: Sin cebolla ☐ | Sin pepinillo ☐ | Sin mayonesa ☐ | Sin repollo ☐ | etc.
- El cliente selecciona las que aplican
- Las notas aparecen en la card del carrito debajo del producto

### Al confirmar el pedido (Paso 4)
1. Llamar `get_next_numero_orden(tenant_id)` para obtener el número
2. Insert en `pedidos` con estado `pendiente`
3. Insert en `items_pedido` por cada producto con sus notas
4. Generar dos mensajes WhatsApp:

**Mensaje al NEGOCIO** (wa.me del tenant):
```
[Nombre negocio] — Pedido #[numero]

Cliente: [nombre]
Telefono: [telefono]
Entrega: [Local | Delivery +RD$50]
Pago: [Efectivo | Transferencia]

Orden:
- 1x Bacon Cheese Burger
  Notas: Sin cebolla, Sin pepinillo
- 2x Coca Cola

Subtotal: RD$400
Delivery: RD$0
TOTAL: RD$400
```

**Mensaje al CLIENTE** (ingresado por el cliente en el formulario):
```
✅ Tu pedido fue recibido - [Nombre negocio]

📋 Orden #[numero]
🍔 Bacon Cheese Burger x1
   📝 Sin cebolla, Sin pepinillo
🥤 Coca Cola x2
💰 Total: RD$400
💳 Pago: Efectivo al retirar

📍 Sigue el estado de tu orden en tiempo real:
👉 fast-orden.com/orden.html?id=[uuid]

Con ese enlace puedes ver exactamente
cuándo tu orden está lista para retirar,
sin necesidad de preguntar.
¡Lo verás actualizado al instante!
```

5. Mostrar en pantalla el número de orden y link de seguimiento
6. Botones: "Enviar al negocio" y "Enviar confirmación a mi WhatsApp"

---

## 7. Módulo Caja — caja.html?tenant=slug

### Acceso
- Requiere login como admin del tenant
- URL pensada para tablet o PC en el mostrador

### Layout
- Header: nombre del negocio, fecha, total vendido hoy
- Columnas de pedidos por estado:

```
[PENDIENTES]          [EN PREPARACIÓN]       [LISTOS]
  #32 Juan            #30 Maria               #28 Pedro ✅
  Bacon Burger        Hot Dog x2              Yaroa Pollo
  Coca Cola           RD$300                  RD$280
  RD$400              [Ver] [Listo ✓]         [Entregado]
  [Ver] [Confirmar]
```

### Acciones por pedido
- **Ver detalle** — modal con todos los items y notas
- **Confirmar** (desde Pendiente) — abre modal de confirmación:
  - Resumen del pedido
  - Toggle "¿Ya pagó?" con método de pago
  - Botón "Enviar a cocina" → estado cambia a `en_preparacion`
- **Listo** (desde En Preparación) — estado cambia a `listo`
  - Pantalla de turnos se actualiza automáticamente
  - Cliente ve "Listo para retirar" en su URL de seguimiento
- **Entregado** (desde Listo) → estado `entregado`
- **Cancelar** — con confirmación, estado `cancelado`

### Realtime
```javascript
const channel = supabase
  .channel('pedidos-caja')
  .on('postgres_changes', {
    event: '*',
    schema: 'public',
    table: 'pedidos',
    filter: `tenant_id=eq.${tenantId}`
  }, (payload) => {
    actualizarPedidoEnUI(payload);
  })
  .subscribe();
```

Cuando llega un pedido nuevo suena una notificación de audio + vibración visual.

---

## 8. Módulo Cocina — cocina.html?tenant=slug

### Acceso
- Solo lectura — no requiere login
- URL protegida por tenant slug (no es adivinable fácilmente)
- Pensada para tablet montada en la cocina

### Layout
Grid de cards de pedidos en estado `en_preparacion`:

```
┌─────────────────┐  ┌─────────────────┐
│   ORDEN #32     │  │   ORDEN #33     │
│ ─────────────── │  │ ─────────────── │
│ Bacon Burger x1 │  │ Yaroa Pollo x2  │
│ ⚠️ Sin cebolla  │  │ Hot Dog x1      │
│ Coca Cola x2    │  │                 │
│                 │  │                 │
│ Local • Efectivo│  │ Delivery        │
│ 14:32           │  │ 14:35           │
└─────────────────┘  └─────────────────┘
```

- Cards grandes, legibles desde lejos
- Notas especiales destacadas en amarillo/naranja
- Tiempo transcurrido desde que entró a preparación
- Cards más antiguas de 15 min se marcan en rojo (alerta)
- Actualización en tiempo real via Supabase Realtime
- Sin botones de acción — solo visualización

---

## 9. Módulo Turnos — turnos.html?tenant=slug

### Acceso
- Completamente público
- Pensado para TV con Android abriendo la URL en el navegador
- Sin login requerido

### Layout
Pantalla dividida en dos secciones:

```
┌─────────────────────────────────────────┐
│         MI CASTILLO SABOR               │
│    ══════════════════════════           │
│                                         │
│  🟡 EN PREPARACIÓN                      │
│  ┌────┐ ┌────┐ ┌────┐ ┌────┐           │
│  │ 30 │ │ 31 │ │ 32 │ │ 33 │           │
│  └────┘ └────┘ └────┘ └────┘           │
│                                         │
│  ✅ LISTO PARA RETIRAR                  │
│  ┌────┐ ┌────┐                          │
│  │ 28 │ │ 29 │                          │
│  └────┘ └────┘                          │
│                                         │
│  Logo del negocio     14:45 Lun 06 Abr  │
└─────────────────────────────────────────┘
```

- Tipografía muy grande
- Números en preparación: fondo amarillo
- Números listos: fondo verde pulsante (animación CSS)
- Cuando un número pasa a "Listo": animación de entrada llamativa
- Cuando un número pasa a "Entregado": desaparece con animación
- Actualización en tiempo real via Supabase Realtime
- Solo muestra pedidos del día actual

---

## 10. Seguimiento de Orden — orden.html?id=uuid

### Acceso
- Completamente público
- URL única por pedido (UUID no adivinable)

### Layout (mobile-first)
```
┌─────────────────────┐
│  MI CASTILLO SABOR  │
│                     │
│   Tu Orden #32      │
│                     │
│  ●━━━━━━━━━━━━━━○   │
│  Recibido           │
│                     │
│  ●━━━━━━○━━━━━━━○   │
│  En Preparación 🔥  │  ← estado actual animado
│                     │
│  ○━━━━━━━━━━━━━━○   │
│  Listo para Retirar │
│                     │
│  ─────────────────  │
│  Bacon Burger x1    │
│  Sin cebolla        │
│  Coca Cola x2       │
│  ─────────────────  │
│  Total: RD$400      │
│                     │
│  Actualizado: 14:33 │
└─────────────────────┘
```

- Barra de progreso visual con los estados
- Estado actual animado (pulso, fuego, etc.)
- Detalle de los items del pedido
- Al llegar a "Listo": animación celebración + texto grande "¡Tu orden está lista!"
- Actualización en tiempo real via Supabase Realtime
- Sin login requerido

---

## 11. Dashboard — admin/dashboard.html

### Métricas del día
- Total de pedidos hoy
- Total vendido hoy (RD$)
- Ticket promedio hoy
- Pedidos pendientes ahora mismo

### Gráficas (Chart.js via CDN)
- Ventas por hora del día actual (barras)
- Productos más pedidos hoy (top 5, barras horizontales)

### Métricas de la semana
- Ventas por día de la semana (línea)
- Comparativa semana actual vs semana anterior

### Métricas del mes
- Total vendido este mes
- Total pedidos este mes
- Días con más ventas (heatmap simple)

### Cuadre de caja
- Pedidos pagados en efectivo: RD$X
- Pedidos pagados por transferencia: RD$X
- Pedidos pendientes de pago: RD$X
- Total cobrado hoy: RD$X
- Botón "Exportar resumen del día" (genera texto para copiar o descargar CSV)

---

## 12. Admin Notas Predefinidas — admin/notas.html

- Lista de notas del tenant: Sin cebolla, Sin pepinillo, etc.
- Agregar nueva nota (texto libre)
- Toggle activa/inactiva
- Reordenar (drag & drop o flechas arriba/abajo)
- Eliminar con confirmación

### Notas sugeridas iniciales (seed por tenant Pro)
```javascript
const notasIniciales = [
  'Sin cebolla',
  'Sin pepinillo',
  'Sin mayonesa',
  'Sin repollo',
  'Sin tomate',
  'Sin mostaza',
  'Sin salsa',
  'Extra queso',
  'Bien cocido',
  'Termino medio'
];
```

---

## 13. Historial de Pedidos — admin/pedidos.html

- Tabla de todos los pedidos con filtros:
  - Por fecha (hoy, ayer, últimos 7 días, rango)
  - Por estado
  - Por tipo (local/delivery)
  - Por método de pago
- Columnas: #, cliente, items, total, estado, pagado, hora
- Clic en pedido → modal con detalle completo
- Exportar a CSV el rango seleccionado

---

## 14. Cambios en Superadmin

### superadmin/tenants.html — columna Plan
- Mostrar badge: LITE | PRO
- Al editar tenant: selector de plan (Lite/Pro)
- Al cambiar a Pro: crear registro en `configuracion_pro` automáticamente
- Al cambiar a Lite: módulos Pro se deshabilitan pero datos se conservan

### Control de acceso por plan
```javascript
// En caja.html, cocina.html, turnos.html, dashboard.html
const { data: tenant } = await supabase
  .from('tenants')
  .select('plan, activo, plan_expira_at')
  .eq('slug', slug)
  .single();

if (tenant.plan !== 'pro') {
  mostrarPantallaUpgrade();
  return;
}
```

---

## 15. Actualizar Tabla Tenants

```sql
-- Agregar campo plan_pro_activo para control rapido
alter table public.tenants
add column if not exists moneda text default 'RD$';

-- Actualizar constraint de plan
alter table public.tenants
drop constraint if exists plan_valido;

alter table public.tenants
add constraint plan_valido check (plan in ('lite', 'pro'));

-- Actualizar registros existentes
update public.tenants set plan = 'lite' where plan = 'basico';
```

---

## 16. Notas de Implementación

- Supabase Realtime se suscribe por `tenant_id` para aislar los canales
- El módulo cocina y turnos no requieren auth — solo leen datos públicos filtrados por tenant
- Los pedidos se insertan públicamente (el cliente no está logueado) — el RLS lo permite
- El número de orden diario usa una función SQL atómica para evitar duplicados
- Chart.js se carga solo en admin/dashboard.html via CDN
- Los snapshots de nombre y precio en items_pedido son importantes — si el admin cambia el precio después, el pedido histórico conserva el precio original
- El polling de orden.html como fallback si Realtime falla: cada 10 segundos
- La pantalla de turnos debe funcionar sin interacción — autorefresh si pierde conexión Realtime
