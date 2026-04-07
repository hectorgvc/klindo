-- ============================================================
-- FAST ORDEN PRO — Tablas adicionales
-- Ejecutar en el SQL Editor de Supabase
-- ============================================================

-- 1. PEDIDOS
create table public.pedidos (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid references public.tenants(id) on delete cascade not null,
  numero_dia int not null,
  tipo text not null default 'local',
  estado text not null default 'pendiente',
  metodo_pago text,
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

-- 2. ITEMS_PEDIDO
create table public.items_pedido (
  id uuid primary key default gen_random_uuid(),
  pedido_id uuid references public.pedidos(id) on delete cascade not null,
  producto_id uuid references public.productos(id) on delete set null,
  nombre text not null,
  precio numeric(10,2) not null,
  cantidad int not null default 1,
  notas text[],
  subtotal numeric(10,2) not null,
  created_at timestamptz default now()
);

-- 3. NOTAS_PREDEFINIDAS
create table public.notas_predefinidas (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid references public.tenants(id) on delete cascade not null,
  texto text not null,
  activa boolean default true,
  orden int default 0,
  created_at timestamptz default now()
);

-- 4. CONFIGURACION_PRO
create table public.configuracion_pro (
  tenant_id uuid references public.tenants(id) on delete cascade primary key,
  contador_fecha date default current_date,
  ultimo_numero int default 0,
  created_at timestamptz default now()
);

-- ============================================================
-- RLS
-- ============================================================

-- PEDIDOS
alter table public.pedidos enable row level security;

create policy "Lectura publica pedidos"
  on public.pedidos for select using (true);

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

create policy "Superadmin gestiona todas las notas"
  on public.notas_predefinidas for all
  using (
    exists (
      select 1 from public.profiles
      where id = auth.uid() and rol = 'superadmin'
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

create policy "Superadmin gestiona toda la config"
  on public.configuracion_pro for all
  using (
    exists (
      select 1 from public.profiles
      where id = auth.uid() and rol = 'superadmin'
    )
  );

-- ============================================================
-- FUNCION: Numero de orden diario (atomica, sin duplicados)
-- ============================================================

create or replace function public.get_next_numero_orden(p_tenant_id uuid)
returns int as $$
declare
  v_numero int;
  v_fecha date := current_date;
begin
  insert into public.configuracion_pro (tenant_id, contador_fecha, ultimo_numero)
  values (p_tenant_id, v_fecha, 0)
  on conflict (tenant_id) do nothing;

  update public.configuracion_pro
  set ultimo_numero = 0, contador_fecha = v_fecha
  where tenant_id = p_tenant_id
    and contador_fecha < v_fecha;

  update public.configuracion_pro
  set ultimo_numero = ultimo_numero + 1
  where tenant_id = p_tenant_id
  returning ultimo_numero into v_numero;

  return v_numero;
end;
$$ language plpgsql security definer;

-- ============================================================
-- ACTUALIZAR TABLA TENANTS
-- Cambiar plan 'basico' a 'lite' para consistencia
-- ============================================================

alter table public.tenants
add constraint plan_valido check (plan in ('lite', 'pro'));

-- ============================================================
-- TRIGGER: updated_at en pedidos
-- ============================================================

create or replace function public.handle_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger pedidos_updated_at
  before update on public.pedidos
  for each row execute procedure public.handle_updated_at();

-- ============================================================
-- HABILITAR REALTIME en tablas necesarias
-- ============================================================

alter publication supabase_realtime add table public.pedidos;
alter publication supabase_realtime add table public.items_pedido;
```
