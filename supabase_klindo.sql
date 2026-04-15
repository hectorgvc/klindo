-- ═══════════════════════════════════════════════════════
-- KLINDO — Schema de Base de Datos (IDEMPOTENTE)
-- Sistema de Gestión para Lavanderías y Tintorerías
-- ═══════════════════════════════════════════════════════
-- Seguro para ejecutar múltiples veces sin errores.
-- ═══════════════════════════════════════════════════════

-- ── 1. TIPOS ENUM (seguros ante re-ejecución) ──────────

DO $$ BEGIN
  CREATE TYPE estado_orden_type AS ENUM (
    'recibido', 'en_lavado', 'en_seco', 'en_planchado',
    'listo', 'en_camino', 'entregado', 'cancelado'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE entrega_type AS ENUM ('retiro', 'delivery');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE unidad_cobro_type AS ENUM ('unidad', 'kilo', 'metro', 'fijo');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE metodo_pago_type AS ENUM ('efectivo', 'transferencia', 'tarjeta', 'otro');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE servicio_tipo_type AS ENUM (
    'lavado', 'secado', 'planchado', 'tintoreria', 'combo', 'extras', 'hogar'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE estado_item_type AS ENUM ('pendiente', 'en_proceso', 'completado', 'con_problema');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE rol_type AS ENUM ('superadmin', 'admin', 'operador', 'repartidor');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE plan_type AS ENUM ('lite', 'pro');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ── 2. TABLA: tenants ──────────────────────────────────

CREATE TABLE IF NOT EXISTS public.tenants (
  id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre                  varchar(100) NOT NULL,
  slug                    varchar(50)  NOT NULL UNIQUE,
  whatsapp                varchar(20),
  logo_url                text,

  -- Plan
  plan                    plan_type NOT NULL DEFAULT 'lite',
  plan_expira_at          timestamptz,
  activo                  boolean NOT NULL DEFAULT true,

  -- Config básica
  moneda                  varchar(10) DEFAULT 'RD$',
  telefono                varchar(20),
  direccion               text,
  color_marca             varchar(7) DEFAULT '#0ea5e9',

  -- Delivery
  modulo_delivery_activo  boolean DEFAULT false,
  delivery_costo_base     numeric(10,2) DEFAULT 0,
  delivery_radio_km       integer DEFAULT 5,

  -- Horario (JSON)
  horario                 jsonb,

  created_at              timestamptz DEFAULT now(),
  updated_at              timestamptz DEFAULT now()
);

ALTER TABLE public.tenants ENABLE ROW LEVEL SECURITY;

-- ── 3. TABLA: profiles ─────────────────────────────────

CREATE TABLE IF NOT EXISTS public.profiles (
  id          uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  tenant_id   uuid REFERENCES public.tenants(id) ON DELETE CASCADE,
  nombre      varchar(100) NOT NULL,
  rol         rol_type NOT NULL DEFAULT 'admin',
  activo      boolean NOT NULL DEFAULT true,
  avatar_url  text,
  created_at  timestamptz DEFAULT now(),
  updated_at  timestamptz DEFAULT now()
);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- ── 4. TABLA: categorias_servicio ──────────────────────

CREATE TABLE IF NOT EXISTS public.categorias_servicio (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  nombre      varchar(50) NOT NULL,
  descripcion text,
  icono       varchar(50),
  icono_emoji varchar(10),
  color       varchar(7) DEFAULT '#0ea5e9',
  orden       integer DEFAULT 0,
  activo      boolean DEFAULT true,
  created_at  timestamptz DEFAULT now()
);

ALTER TABLE public.categorias_servicio ENABLE ROW LEVEL SECURITY;

-- ── 5. TABLA: servicios ────────────────────────────────

CREATE TABLE IF NOT EXISTS public.servicios (
  id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id               uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  categoria_id            uuid REFERENCES public.categorias_servicio(id) ON DELETE SET NULL,

  nombre                  varchar(100) NOT NULL,
  descripcion             text,
  codigo                  varchar(20),
  icono_emoji             varchar(10) DEFAULT '🧺',

  tipo                    servicio_tipo_type DEFAULT 'lavado',

  precio_por_unidad       numeric(10,2),
  precio_por_kilo         numeric(10,2),
  precio_por_metro        numeric(10,2),
  precio_fijo             numeric(10,2),

  unidad_cobro            unidad_cobro_type DEFAULT 'unidad',
  tiempo_estimado_minutos integer DEFAULT 120,

  activo                  boolean DEFAULT true,
  imagen_url              text,
  orden                   integer DEFAULT 0,

  created_at              timestamptz DEFAULT now(),
  updated_at              timestamptz DEFAULT now()
);

ALTER TABLE public.servicios ENABLE ROW LEVEL SECURITY;

-- ── 6. TABLA: ordenes_servicio ─────────────────────────

CREATE TABLE IF NOT EXISTS public.ordenes_servicio (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id           uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,

  numero_dia          integer NOT NULL DEFAULT 1,
  numero_orden        varchar(20),

  cliente_nombre      varchar(100) NOT NULL,
  cliente_telefono    varchar(20),
  cliente_direccion   text,

  tipo_entrega        entrega_type DEFAULT 'retiro',
  estado              estado_orden_type DEFAULT 'recibido',

  delivery_activo     boolean DEFAULT false,
  delivery_costo      numeric(10,2) DEFAULT 0,
  repartidor_id       uuid REFERENCES public.profiles(id) ON DELETE SET NULL,

  subtotal            numeric(10,2) DEFAULT 0,
  total               numeric(10,2) DEFAULT 0,
  pagado              boolean DEFAULT false,
  metodo_pago         metodo_pago_type DEFAULT 'efectivo',

  fecha_promesa       timestamptz,
  fecha_entrega       timestamptz,

  notas_recepcion     text,
  notas_entrega       text,

  created_at          timestamptz DEFAULT now(),
  updated_at          timestamptz DEFAULT now()
);

ALTER TABLE public.ordenes_servicio ENABLE ROW LEVEL SECURITY;

-- ── 7. TABLA: items_orden ──────────────────────────────

CREATE TABLE IF NOT EXISTS public.items_orden (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  orden_id            uuid NOT NULL REFERENCES public.ordenes_servicio(id) ON DELETE CASCADE,
  servicio_id         uuid REFERENCES public.servicios(id) ON DELETE SET NULL,

  servicio_nombre     varchar(100) NOT NULL,
  cantidad            integer DEFAULT 1,
  peso_kg             numeric(5,2),
  precio_unitario     numeric(10,2) NOT NULL,
  subtotal            numeric(10,2) NOT NULL,

  estado_item         estado_item_type DEFAULT 'pendiente',

  tiene_manchas       boolean DEFAULT false,
  descripcion_manchas text,
  requiere_atencion   boolean DEFAULT false,
  notas               text,

  created_at          timestamptz DEFAULT now()
);

ALTER TABLE public.items_orden ENABLE ROW LEVEL SECURITY;

-- ── 8. TABLA: configuracion_tenant ─────────────────────

CREATE TABLE IF NOT EXISTS public.configuracion_tenant (
  tenant_id                  uuid PRIMARY KEY REFERENCES public.tenants(id) ON DELETE CASCADE,
  contador_fecha             date DEFAULT current_date,
  ultimo_numero              integer DEFAULT 0,
  zonas_delivery             jsonb,
  horario_delivery_desde     time,
  horario_delivery_hasta     time,
  dias_delivery              integer[],
  tiempo_preparacion_minutos integer DEFAULT 1440,
  updated_at                 timestamptz DEFAULT now()
);

ALTER TABLE public.configuracion_tenant ENABLE ROW LEVEL SECURITY;

-- ── 9. FUNCIONES ───────────────────────────────────────

CREATE OR REPLACE FUNCTION public.klindo_next_orden_num(p_tenant_id uuid)
RETURNS integer AS $$
DECLARE
  v_numero integer;
  v_fecha  date := current_date;
BEGIN
  INSERT INTO public.configuracion_tenant (tenant_id, contador_fecha, ultimo_numero)
  VALUES (p_tenant_id, v_fecha, 0)
  ON CONFLICT (tenant_id) DO NOTHING;

  UPDATE public.configuracion_tenant
  SET ultimo_numero = 0, contador_fecha = v_fecha
  WHERE tenant_id = p_tenant_id AND contador_fecha < v_fecha;

  UPDATE public.configuracion_tenant
  SET ultimo_numero = ultimo_numero + 1
  WHERE tenant_id = p_tenant_id
  RETURNING ultimo_numero INTO v_numero;

  RETURN v_numero;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.is_superadmin()
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM auth.users
    WHERE id = auth.uid()
    AND (
      raw_user_meta_data->>'rol' = 'superadmin'
      OR raw_app_meta_data->>'rol' = 'superadmin'
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ── 10. RLS POLICIES (DROP IF EXISTS antes de crear) ───

-- TENANTS
DROP POLICY IF EXISTS "Lectura pública de tenant activo" ON public.tenants;
DROP POLICY IF EXISTS "Superadmin gestiona tenants"      ON public.tenants;

CREATE POLICY "Lectura pública de tenant activo"
  ON public.tenants FOR SELECT USING (activo = true);

CREATE POLICY "Superadmin gestiona tenants"
  ON public.tenants FOR ALL USING (is_superadmin());

-- PROFILES
DROP POLICY IF EXISTS "Usuario ve su perfil"          ON public.profiles;
DROP POLICY IF EXISTS "Superadmin ve todos los perfiles" ON public.profiles;

CREATE POLICY "Usuario ve su perfil"
  ON public.profiles FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Superadmin ve todos los perfiles"
  ON public.profiles FOR ALL USING (is_superadmin());

-- CATEGORIAS_SERVICIO
DROP POLICY IF EXISTS "Lectura pública de categorías"  ON public.categorias_servicio;
DROP POLICY IF EXISTS "Admin gestiona sus categorías"  ON public.categorias_servicio;

CREATE POLICY "Lectura pública de categorías"
  ON public.categorias_servicio FOR SELECT USING (true);

CREATE POLICY "Admin gestiona sus categorías"
  ON public.categorias_servicio FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid()
        AND tenant_id = categorias_servicio.tenant_id
        AND activo = true
    )
  );

-- SERVICIOS
DROP POLICY IF EXISTS "Lectura pública de servicios activos" ON public.servicios;
DROP POLICY IF EXISTS "Admin gestiona sus servicios"         ON public.servicios;

CREATE POLICY "Lectura pública de servicios activos"
  ON public.servicios FOR SELECT USING (activo = true);

CREATE POLICY "Admin gestiona sus servicios"
  ON public.servicios FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid()
        AND tenant_id = servicios.tenant_id
        AND activo = true
    )
  );

-- ORDENES_SERVICIO
DROP POLICY IF EXISTS "Admin ve sus órdenes"        ON public.ordenes_servicio;
DROP POLICY IF EXISTS "Admin inserta órdenes"       ON public.ordenes_servicio;
DROP POLICY IF EXISTS "Admin actualiza sus órdenes" ON public.ordenes_servicio;
DROP POLICY IF EXISTS "Superadmin todas las órdenes" ON public.ordenes_servicio;

CREATE POLICY "Admin ve sus órdenes"
  ON public.ordenes_servicio FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND tenant_id = ordenes_servicio.tenant_id
    )
  );

CREATE POLICY "Admin inserta órdenes"
  ON public.ordenes_servicio FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND tenant_id = ordenes_servicio.tenant_id
    )
  );

CREATE POLICY "Admin actualiza sus órdenes"
  ON public.ordenes_servicio FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND tenant_id = ordenes_servicio.tenant_id
    )
  );

CREATE POLICY "Superadmin todas las órdenes"
  ON public.ordenes_servicio FOR ALL USING (is_superadmin());

-- ITEMS_ORDEN
DROP POLICY IF EXISTS "Admin ve items de sus órdenes" ON public.items_orden;
DROP POLICY IF EXISTS "Admin inserta items"           ON public.items_orden;
DROP POLICY IF EXISTS "Superadmin todos los items"    ON public.items_orden;

CREATE POLICY "Admin ve items de sus órdenes"
  ON public.items_orden FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.ordenes_servicio o
      JOIN public.profiles p ON p.tenant_id = o.tenant_id
      WHERE o.id = items_orden.orden_id AND p.id = auth.uid()
    )
  );

CREATE POLICY "Admin inserta items"
  ON public.items_orden FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.ordenes_servicio o
      JOIN public.profiles p ON p.tenant_id = o.tenant_id
      WHERE o.id = items_orden.orden_id AND p.id = auth.uid()
    )
  );

CREATE POLICY "Superadmin todos los items"
  ON public.items_orden FOR ALL USING (is_superadmin());

-- CONFIGURACION_TENANT
DROP POLICY IF EXISTS "Admin ve y gestiona su config" ON public.configuracion_tenant;
DROP POLICY IF EXISTS "Superadmin config todos"       ON public.configuracion_tenant;

CREATE POLICY "Admin ve y gestiona su config"
  ON public.configuracion_tenant FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND tenant_id = configuracion_tenant.tenant_id
    )
  );

CREATE POLICY "Superadmin config todos"
  ON public.configuracion_tenant FOR ALL USING (is_superadmin());

-- ── 11. REALTIME ───────────────────────────────────────

DO $$ BEGIN
  ALTER publication supabase_realtime ADD TABLE public.ordenes_servicio;
EXCEPTION WHEN others THEN NULL; END $$;

DO $$ BEGIN
  ALTER publication supabase_realtime ADD TABLE public.items_orden;
EXCEPTION WHEN others THEN NULL; END $$;

-- ── 12. SEED: Datos de prueba ──────────────────────────
-- Ejecutar DESPUÉS de crear el primer tenant.
-- Reemplaza TU_TENANT_ID con el UUID del tenant.

/*
INSERT INTO public.categorias_servicio (tenant_id, nombre, icono_emoji, color, orden) VALUES
  ('TU_TENANT_ID', 'Lavado Regular', '🫧', '#0ea5e9', 1),
  ('TU_TENANT_ID', 'Tintorería',     '✨', '#8b5cf6', 2),
  ('TU_TENANT_ID', 'Planchado',      '🔥', '#06b6d4', 3),
  ('TU_TENANT_ID', 'Ropa de Hogar',  '🏠', '#22c55e', 4),
  ('TU_TENANT_ID', 'Combos',         '📦', '#f59e0b', 5),
  ('TU_TENANT_ID', 'Especiales',     '⭐', '#ef4444', 6);

INSERT INTO public.servicios (tenant_id, nombre, tipo, unidad_cobro, precio_por_unidad, icono_emoji, orden) VALUES
  ('TU_TENANT_ID', 'Camisa/Blusa',      'lavado',     'unidad', 150.00, '👔', 1),
  ('TU_TENANT_ID', 'Pantalón/Jean',     'lavado',     'unidad', 200.00, '👖', 2),
  ('TU_TENANT_ID', 'Playera/Polo',      'lavado',     'unidad', 100.00, '👕', 3),
  ('TU_TENANT_ID', 'Vestido Corto',     'lavado',     'unidad', 250.00, '👗', 4),
  ('TU_TENANT_ID', 'Vestido Largo',     'lavado',     'unidad', 400.00, '👘', 5),
  ('TU_TENANT_ID', 'Ropa por Kilo',     'lavado',     'kilo',   120.00, '⚖️', 6),
  ('TU_TENANT_ID', 'Edredón Individual','hogar',      'unidad', 500.00, '🛌', 7),
  ('TU_TENANT_ID', 'Edredón Queen',     'hogar',      'unidad', 700.00, '🛏️', 8),
  ('TU_TENANT_ID', 'Edredón King',      'hogar',      'unidad', 900.00, '🏨', 9),
  ('TU_TENANT_ID', 'Sábanas (juego)',   'hogar',      'unidad', 450.00, '🛁', 10),
  ('TU_TENANT_ID', 'Cortinas',          'hogar',      'metro',  200.00, '🪟', 11),
  ('TU_TENANT_ID', 'Alfombra',          'hogar',      'metro',  350.00, '🟫', 12),
  ('TU_TENANT_ID', 'Traje Completo',    'tintoreria', 'unidad', 900.00, '🤵', 13),
  ('TU_TENANT_ID', 'Saco/Blazer',       'tintoreria', 'unidad', 550.00, '🧥', 14),
  ('TU_TENANT_ID', 'Abrigo',            'tintoreria', 'unidad', 700.00, '🧣', 15),
  ('TU_TENANT_ID', 'Planchado Camisa',  'planchado',  'unidad',  80.00, '🔥', 16),
  ('TU_TENANT_ID', 'Planchado Pantalón','planchado',  'unidad', 100.00, '🔥', 17),
  ('TU_TENANT_ID', 'Desmanchado',       'extras',     'unidad', 200.00, '🧪', 18),
  ('TU_TENANT_ID', 'Limpieza Zapatos',  'extras',     'unidad', 350.00, '👟', 19),
  ('TU_TENANT_ID', 'Combo Básico 3kg',  'combo',      'fijo',   450.00, '📦', 20);
*/

-- ── FIN DEL SCRIPT ─────────────────────────────────────
