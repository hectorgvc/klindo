# Wash Order - Sistema de Gestión para Lavanderías

## Descripción del Proyecto

Wash Order es una adaptación del sistema Fast Orden Pro, reorientado específicamente para el sector de lavanderías y tintorerías. El sistema mantiene la arquitectura robusta del original pero adapta la experiencia a los flujos de trabajo característicos de servicios de limpieza de textiles.

## Filosofía de Diseño

### Paleta de Colores - Tema Claro

Al ser un negocio de limpieza, el diseño debe transmitir frescura, higiene y claridad:

```css
/* Colores principales */
--bg-primary: #ffffff;           /* Blanco puro - fondo principal */
--bg-secondary: #f8fafc;        /* Gris muy claro - cards/secciones */
--bg-tertiary: #f1f5f9;         /* Gris claro - elementos secundarios */
--border-color: #e2e8f0;        /* Bordes suaves */

/* Texto */
--text-primary: #1e293b;        /* Slate 800 - texto principal */
--text-secondary: #64748b;      /* Slate 500 - texto secundario */
--text-muted: #94a3b8;          /* Slate 400 - texto terciario */

/* Acentos - Agua/Limpieza */
--accent-primary: #0ea5e9;      /* Sky 500 - azul agua */
--accent-secondary: #06b6d4;    /* Cyan 500 - turquesa */
--accent-tertiary: #14b8a6;     /* Teal 500 - verde agua */

/* Estados */
--success: #22c55e;             /* Verde - éxito/listo */
--warning: #f59e0b;             /* Ámbar - pendiente */
--danger: #ef4444;              /* Rojo - urgente/cancelado */
--info: #3b82f6;                /* Azul - información */

/* Estados de prendas/servicios */
--estado-recibido: #f59e0b;     /* Ámbar - prendas recién ingresadas */
--estado-en-proceso: #0ea5e9;   /* Azul agua - en lavado/planchado */
--estado-listo: #22c55e;        /* Verde - listo para retiro */
--estado-entregado: #10b981;    /* Esmeralda - entregado al cliente */
--estado-en-camino: #8b5cf6;    /* Violeta - en delivery */
```

### Tipografía

- **Display/Headings**: 'Bebas Neue' o 'Poppins' (limpio, moderno)
- **Body**: 'Inter' o 'Nunito' (legible, amigable)

---

## Arquitectura de Servicios

### Modelo de Datos Adaptado

#### Tabla: `servicios` (antes productos)

```sql
CREATE TABLE servicios (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid REFERENCES tenants(id),

  /* Identificación */
  nombre varchar(100) NOT NULL,           -- Ej: "Lavado Regular", "Planchado", "Tintorería"
  descripcion text,                      -- Descripción del servicio
  codigo varchar(20),                    -- Código interno (opcional)

  /* Tipo de servicio */
  tipo servicio_type NOT NULL,           -- Enum: lavado, secado, planchado, tintoreria, combo, extras

  /* Precios - Estructura flexible para lavandería */
  precio_por_unidad decimal(10,2),       -- Precio por prenda (camisa, pantalón)
  precio_por_kilo decimal(10,2),         -- Precio por kilo de ropa
  precio_fijo decimal(10,2),             -- Precio fijo (ej: edredón, cortina)

  /* Unidad de cobro */
  unidad_cobro unidad_type DEFAULT 'unidad', -- Enum: unidad, kilo, metro, fijo

  /* Configuración */
  tiempo_estimado_minutos integer,       -- Tiempo estimado de proceso
  requiere_recepcion boolean DEFAULT true,

  /* Categorización */
  categoria_id uuid REFERENCES categorias_servicio(id),

  /* Visibilidad */
  activo boolean DEFAULT true,
  visible_menu boolean DEFAULT true,

  /* Media */
  imagen_url text,

  /* Ordenamiento */
  orden integer DEFAULT 0,

  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

/* Tipos ENUM */
CREATE TYPE servicio_type AS ENUM (
  'lavado',      -- Lavado de prendas
  'secado',      -- Secado (si es servicio separado)
  'planchado',   -- Planchado/steam
  'tintoreria',  -- Limpieza en seco
  'combo',       -- Paquetes (lavado + secado + planchado)
  'extras',      -- Servicios adicionales (manchas, desmanchado)
  'hogar'        -- Artículos grandes: cortinas, edredones, alfombras
);

CREATE TYPE unidad_cobro_type AS ENUM (
  'unidad',   -- Por prenda individual
  'kilo',     -- Por peso
  'metro',    -- Por metro lineal (cortinas)
  'fijo'      -- Precio fijo único
);
```

#### Tabla: `categorias_servicio`

```sql
CREATE TABLE categorias_servicio (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid REFERENCES tenants(id),
  nombre varchar(50) NOT NULL,           -- Ej: "Ropa Regular", "Tintorería", "Hogar"
  descripcion text,
  icono varchar(50),                     -- Icono Lucide
  color varchar(7) DEFAULT '#0ea5e9',   -- Color de acento para la categoría
  orden integer DEFAULT 0,
  activo boolean DEFAULT true,
  created_at timestamptz DEFAULT now()
);
```

#### Tabla: `pedidos` → `ordenes_servicio`

```sql
CREATE TABLE ordenes_servicio (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid REFERENCES tenants(id),

  /* Identificación */
  numero_dia serial,                     -- Número correlativo del día
  numero_orden varchar(20),             -- Código único (ej: WO-240415-001)

  /* Cliente */
  cliente_id uuid REFERENCES clientes(id),
  cliente_nombre varchar(100),
  cliente_telefono varchar(20),
  cliente_direccion text,               -- Para delivery

  /* Tipo de servicio */
  tipo_entrega entrega_type DEFAULT 'retiro', -- Enum: retiro, delivery

  /* Estados del flujo de lavandería */
  estado estado_orden DEFAULT 'recibido',
  -- recibido -> en_lavado -> en_seco -> en_planchado -> listo -> entregado

  /* Módulo Delivery (opcional por tenant) */
  delivery_activo boolean DEFAULT false,
  delivery_costo decimal(10,2) DEFAULT 0,
  repartidor_id uuid REFERENCES profiles(id),

  /* Pagos */
  total decimal(10,2) DEFAULT 0,
  subtotal decimal(10,2) DEFAULT 0,
  pagado boolean DEFAULT false,
  metodo_pago metodo_pago_type DEFAULT 'efectivo',

  /* Fechas */
  fecha_promesa timestamp,                -- Fecha prometida de entrega
  fecha_entrega timestamp,              -- Fecha real de entrega

  /* Notas */
  notas_recepcion text,                   -- Notas al recibir
  notas_entrega text,                     -- Notas al entregar

  /* Campos de control */
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE TYPE estado_orden AS ENUM (
  'recibido',      -- Orden recién ingresada
  'en_lavado',     -- En proceso de lavado
  'en_seco',       -- En tintorería/secado
  'en_planchado',  -- Planchando
  'listo',         -- Listo para retiro/delivery
  'en_camino',     -- En delivery
  'entregado',     -- Entregado al cliente
  'cancelado'      -- Cancelado
);

CREATE TYPE entrega_type AS ENUM (
  'retiro',    -- Cliente retira en local
  'delivery'   -- Entrega a domicilio
);
```

#### Tabla: `items_orden` (detalle de prendas)

```sql
CREATE TABLE items_orden (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  orden_id uuid REFERENCES ordenes_servicio(id) ON DELETE CASCADE,

  /* Servicio aplicado */
  servicio_id uuid REFERENCES servicios(id),
  servicio_nombre varchar(100),

  /* Descripción de la prenda */
  prenda_descripcion varchar(200),      -- Ej: "Camisa azul", "Edredón king size"
  prenda_categoria varchar(50),         -- Ej: "camisa", "pantalon", "edredon"

  /* Cantidad y medición */
  cantidad integer DEFAULT 1,
  peso_kg decimal(5,2),                  -- Peso si aplica (para cobro por kilo)

  /* Precios */
  precio_unitario decimal(10,2),
  subtotal decimal(10,2),

  /* Estado específico del item */
  estado_item estado_item DEFAULT 'pendiente',
  -- pendiente -> en_proceso -> completado

  /* Problemas/observaciones */
  tiene_manstas boolean DEFAULT false,
  descripcion_manchas text,
  requiere_atencion boolean DEFAULT false,
  notas text,

  /* Fotos (para evidencia de estado) */
  fotos_recepcion text[],              -- URLs de fotos al recibir
  fotos_entrega text[],                -- URLs de fotos al entregar

  created_at timestamptz DEFAULT now()
);

CREATE TYPE estado_item AS ENUM (
  'pendiente',     -- Aún no se procesa
  'en_proceso',    -- En alguna etapa del proceso
  'completado',    -- Terminado
  'con_problema'   -- Requiere atención especial
);
```

#### Tabla: `prendas_catalogo` (opcional - catálogo de prendas frecuentes)

```sql
CREATE TABLE prendas_catalogo (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid REFERENCES tenants(id),

  nombre varchar(100),                   -- Ej: "Camisa", "Pantalón", "Vestido"
  categoria varchar(50),                 -- Ej: "ropa_hombre", "ropa_mujer", "hogar"

  /* Precios sugeridos por servicio */
  precio_lavado decimal(10,2),
  precio_planchado decimal(10,2),
  precio_tintoreria decimal(10,2),

  /* Configuración */
  tiempo_estimado_minutos integer,
  requiere_planchado boolean DEFAULT false,

  icono varchar(50),                     -- Icono representativo
  orden integer DEFAULT 0,
  activo boolean DEFAULT true
);
```

---

## Servicios Predeterminados de Lavandería

### Categorías Base

1. **Lavado Regular** (icono: droplets)
2. **Tintorería/Limpieza en Seco** (icono: sparkle)
3. **Planchado** (icono: iron)
4. **Ropa de Hogar** (icono: home)
5. **Combos y Paquetes** (icono: package)
6. **Servicios Especiales** (icono: star)

### Servicios Detallados

#### 1. LAVADO REGULAR

| Servicio | Descripción | Unidad | Precio Sugerido |
|----------|-------------|--------|-----------------|
| Camisas/Blusas | Lavado y secado de camisas | Por unidad | $2.50 - $4.00 |
| Pantalones/Jeans | Lavado de pantalones | Por unidad | $3.50 - $5.00 |
| Playeras/Polos | Lavado de playeras | Por unidad | $2.00 - $3.00 |
| Ropa Interior | Lavado de prendas íntimas | Por kilo | $1.50 - $2.50 |
| Ropa por Kilo | Lavado general por peso | Por kilo | $1.20 - $2.00 |
| Calcetines (par) | Lavado de calcetines | Por par | $1.00 - $1.50 |

#### 2. TINTORERÍA (LIMPIEZA EN SECO)

| Servicio | Descripción | Unidad | Precio Sugerido |
|----------|-------------|--------|-----------------|
| Traje Completo | Limpieza en seco de traje | Por unidad | $15.00 - $25.00 |
| Sacos/Blazers | Limpieza de sacos | Por unidad | $8.00 - $12.00 |
| Vestidos Cortos | Vestidos casuales | Por unidad | $10.00 - $15.00 |
| Vestidos Largos | Vestidos de gala | Por unidad | $18.00 - $30.00 |
| Abrigos/Chalecos | Prendas de abrigo | Por unidad | $12.00 - $20.00 |
| Corbatas | Limpieza de corbatas | Por unidad | $3.00 - $5.00 |

#### 3. PLANCHADO / STEAM

| Servicio | Descripción | Unidad | Precio Sugerido |
|----------|-------------|--------|-----------------|
| Camisas Planchadas | Planchado con máquina | Por unidad | $1.50 - $2.50 |
| Planchado Steam | Steam para delicadas | Por unidad | $2.50 - $4.00 |
| Pantalones Planchados | Planchado de pantalones | Por unidad | $2.00 - $3.00 |
| Sábanas Planchadas | Planchado de sábanas | Por unidad | $4.00 - $6.00 |

#### 4. ROPA DE HOGAR

| Servicio | Descripción | Unidad | Precio Sugerido |
|----------|-------------|--------|-----------------|
| Edredón Individual | Lavado de edredón | Por unidad | $8.00 - $12.00 |
| Edredón Matrimonial | Lavado de edredón grande | Por unidad | $12.00 - $18.00 |
| Edredón King | Lavado de edredón king | Por unidad | $15.00 - $25.00 |
| Cobertor/Manta | Lavado de cobertores | Por unidad | $10.00 - $15.00 |
| Cortinas Livianas | Lavado de cortinas | Por metro | $3.00 - $5.00 |
| Cortinas Pesadas | Cortinas blackout | Por metro | $5.00 - $8.00 |
| Tapetes | Lavado de tapetes pequeños | Por unidad | $5.00 - $10.00 |
| Alfombras | Lavado de alfombras | Por metro² | $8.00 - $15.00 |
| Fundas de Almohada | Lavado de fundas | Por par | $3.00 - $5.00 |
| Sábanas (juego) | Juego completo sábanas | Por juego | $6.00 - $10.00 |

#### 5. COMBOS Y PAQUETES

| Servicio | Descripción | Incluye | Precio Sugerido |
|----------|-------------|---------|-----------------|
| Combo Básico | Lavado + Secado | 3 kg de ropa | $8.00 - $12.00 |
| Combo Premium | Lavado + Secado + Planchado | 3 kg de ropa | $15.00 - $20.00 |
| Combo Empresarial | Servicio semanal para empresas | Personalizado | Cotizar |
| Plan Mensual | Servicio recurrente | Personalizado | Cotizar |

#### 6. SERVICIOS ESPECIALES

| Servicio | Descripción | Unidad | Precio Sugerido |
|----------|-------------|--------|-----------------|
| Desmanchado | Tratamiento de manchas difíciles | Por prenda | $3.00 - $8.00 |
| Restauración | Recuperación de prendas | Por prenda | $10.00 - $25.00 |
| Impermeabilización | Aplicación de protectores | Por prenda | $5.00 - $10.00 |
| Limpieza de Zapatos | Limpieza y encerado | Por par | $8.00 - $15.00 |
| Limpieza de Bolsos | Limpieza de carteras/bolsos | Por unidad | $10.00 - $25.00 |
| Planchado Express | Servicio rápido (< 2 hrs) | Por unidad | +50% precio |
| Lavado Express | Lavado rápido (< 4 hrs) | Por kilo | +50% precio |

---

## Flujos de Trabajo (Workflows)

### Flujo Principal de una Orden

```
RECEPCIÓN (Caja/Recepción)
    ↓
[Cliente entrega prendas]
    ↓
REGISTRO DE PRENDAS
    ↓
[Se pesan/identifican prendas individuales]
    ↓
EN LAVADO
    ↓
[Proceso de lavado]
    ↓
EN SECADO / TINTORERÍA
    ↓
[Secado o limpieza en seco]
    ↓
EN PLANCHADO
    ↓
[Planchado/steam]
    ↓
CONTROL DE CALIDAD
    ↓
LISTO PARA ENTREGA
    ↓
[Empacado y etiquetado]
    ↓
├─→ RETIRO EN LOCAL (Caja)
│       ↓
│   ENTREGADO
│
└─→ DELIVERY (si activo)
        ↓
    EN CAMINO
        ↓
    ENTREGADO
```

### Estados de Items (Prendas Individuales)

Cada prenda dentro de una orden puede tener su propio estado:
- `pendiente`: Aún no comienza su proceso
- `en_lavado`: En máquina de lavar
- `en_seco`: En tintorería
- `en_planchado`: En proceso de planchado
- `completado`: Terminada
- `con_problema`: Requiere atención (mancha no sale, daño, etc.)

---

## Configuración del Módulo Delivery

### Tabla: `configuracion_tenant` (ampliada)

```sql
CREATE TABLE configuracion_tenant (
  tenant_id uuid PRIMARY KEY REFERENCES tenants(id),

  /* Módulo Delivery - Opcional */
  modulo_delivery_activo boolean DEFAULT false,
  delivery_gratuito boolean DEFAULT false,
  delivery_monto_minimo_gratis decimal(10,2) DEFAULT 0,
  delivery_costo_base decimal(10,2) DEFAULT 0,
  delivery_costo_por_km decimal(10,2) DEFAULT 0,
  delivery_radio_km integer DEFAULT 5,   -- Radio de cobertura en km

  /* Zonas de delivery */
  zonas_delivery jsonb,                  -- Array de zonas con precios
  -- Ej: [{"nombre": "Zona Centro", "precio": 50}, {"nombre": "Zona Norte", "precio": 80}]

  /* Horarios de delivery */
  horario_delivery_desde time,
  horario_delivery_hasta time,
  dias_delivery_disponibles integer[],   -- Días de la semana [1,2,3,4,5,6] (Domingo=0)

  /* Tiempo estimado */
  tiempo_preparacion_minutos integer DEFAULT 240, -- 4 horas default

  updated_at timestamptz DEFAULT now()
);
```

### UI: Activación/Desactivación de Delivery

En el panel de administración, el tenant debe poder:

1. **Activar/Desactivar módulo completo**
   - Toggle: "Ofrecer servicio a domicilio"
   - Si está desactivado: No aparece opción delivery en menú ni caja

2. **Configurar tarifas** (si está activo)
   - Opción A: Costo fijo por zona
   - Opción B: Costo por distancia (km)
   - Opción C: Delivery gratuito con monto mínimo

3. **Configurar horarios**
   - Horario de recepción de pedidos delivery
   - Días disponibles

4. **Configurar tiempo de entrega**
   - Express (mismo día)
   - Estándar (24 horas)
   - Programado (fecha específica)

---

## Estructura de Archivos Propuesta

```
washorder/
├── index.html                  # Landing page / Menú público
├── login.html                  # Login administrativo
├── recepcion.html              # Módulo de recepción (antes caja)
├── cocina.html → planta.html   # Vista de planta/procesos (KDS)
├── admin/
│   ├── dashboard.html
│   ├── servicios.html          # Gestión de servicios
│   ├── ordenes.html            # Gestión de órdenes
│   ├── clientes.html           # Base de clientes
│   ├── configuracion.html      # Config general + delivery
│   └── repartidores.html       # Solo si delivery activo
├── delivery.html               # App para repartidores (opcional)
├── assets/
│   ├── css/
│   │   └── main.css            # Tema claro - lavandería
│   ├── js/
│   │   ├── supabase.js
│   │   ├── auth.js
│   │   ├── tenant-theme.js     # Tema claro configurable
│   │   └── washorder.js        # Lógica específica
│   └── icons/                  # Iconos de prendas/servicios
└── supabase/
    └── functions/              # Edge functions
        └── create-order/
```

---

## Configuración Supabase Requerida

### 1. Credenciales Necesarias

Para conectar el proyecto se requieren:

```javascript
// Variables de entorno
SUPABASE_URL=https://xxxxx.supabase.co
SUPABASE_ANON_KEY=eyJxxx...
SUPABASE_SERVICE_ROLE_KEY=eyJxxx...  // Solo para edge functions
```

### 2. Tablas Core (del sistema base)

- `tenants` - Multi-tenancy
- `profiles` - Usuarios y repartidores
- `configuracion` - Ajustes globales

### 3. Tablas Específicas (nuevas)

- `servicios` - Catálogo de servicios
- `categorias_servicio` - Agrupación de servicios
- `ordenes_servicio` - Órdenes de trabajo
- `items_orden` - Detalle de prendas
- `prendas_catalogo` - Catálogo de prendas (opcional)
- `configuracion_tenant` - Config extendida por tenant

### 4. Row Level Security (RLS)

Las políticas deben seguir el mismo patrón que Fast Orden:
- Tenants solo ven su propio tenant_id
- Usuarios autenticados según su rol
- Delivery solo ve órdenes asignadas

### 5. Storage Buckets

- `tenant-logos` - Logos de negocios
- `servicios-imagenes` - Fotos de servicios
- `ordenes-fotos` - Evidencia fotográfica de prendas

---

## Diferencias Clave vs Fast Orden Original

| Aspecto | Fast Orden (Restaurante) | Wash Order (Lavandería) |
|---------|---------------------------|-------------------------|
| **Producto** | Alimentos (consumo inmediato) | Servicios de limpieza (proceso) |
| **Duración** | Minutos | Horas/Días |
| **Unidades** | Unidades fijas (1 hamburguesa) | Variables (por unidad, peso, metro) |
| **Estados** | Pendiente → Preparación → Listo | Múltiples etapas de proceso |
| **Delivery** | Casi siempre | Opcional configurable |
| **Diseño** | Oscuro (ambiente nocturno) | Claro (higiene, limpieza) |
| **Pago** | Antes o después | Generalmente al entregar |
| **Fotos** | Opcional | Importante (evidencia de estado) |

---

## Funcionalidades Adicionales Sugeridas

### Para el Futuro

1. **App móvil para clientes**
   - Rastreo de orden en tiempo real
   - Fotos de prendas recibidas
   - Notificaciones push (orden lista)

2. **Impresión de tickets**
   - Tickets térmicos para prendas
   - Códigos QR para rastreo

3. **Programa de fidelidad**
   - Puntos por servicios
   - Descuentos recurrentes

4. **Integración WhatsApp**
   - Notificaciones automáticas
   - Confirmación de delivery

5. **Reportes avanzados**
   - Rendimiento por máquina
   - Prendas más solicitadas
   - Ingresos por tipo de servicio

6. **Gestión de inventario**
   - Detergentes, suavizantes
   - Alertas de stock bajo

---

## Próximos Pasos

1. **Definir estructura completa de base de datos** (SQL)
2. **Crear seed data** con servicios de lavandería predeterminados
3. **Diseñar wireframes** con tema claro
4. **Desarrollar módulo de recepción** (registro de prendas)
5. **Desarrollar vista de planta** (seguimiento de procesos)
6. **Implementar módulo delivery opcional**
7. **Configurar sistema de fotos** para evidencia
8. **Testing con lavandería real**

---

## Notas de Implementación

- Mantener compatibilidad con arquitectura multi-tenant existente
- Usar mismas convenciones de código que Fast Orden
- Priorizar responsive design (tablets en recepción)
- Considerar impresión de etiquetas/tickets desde el navegador
- Implementar caché local para funcionamiento offline básico
