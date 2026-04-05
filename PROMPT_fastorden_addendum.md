# Addendum al PROMPT_claudecode_fastorden.md
## Nuevas funcionalidades: Ofertas e Importación de Productos

Agregar estas dos funcionalidades al proyecto Fast Orden además de todo lo ya especificado.

---

## FUNCIONALIDAD 1: Ofertas

### Nueva tabla en Supabase

```sql
create table public.ofertas (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid references public.tenants(id) on delete cascade not null,
  tipo text not null,                    -- 'descuento' | 'combo'
  nombre text not null,                  -- ej: "Burger del Día" o "Combo Familiar"
  descripcion text,
  -- Para tipo 'descuento': referencia al producto existente
  producto_id uuid references public.productos(id) on delete cascade,
  precio_original numeric(10,2),         -- precio normal del producto
  precio_oferta numeric(10,2) not null,  -- precio con descuento
  -- Para tipo 'combo': descripcion libre de lo que incluye
  contenido_combo text,                  -- ej: "2 Burgers + 2 Bebidas + 2 Papas"
  imagen_url text,
  -- Vigencia
  siempre_activa boolean default false,  -- si true, ignora fechas y dias
  fecha_inicio date,
  fecha_fin date,
  dias_semana text[],                    -- ['lunes','miercoles','viernes']
  activa boolean default true,
  orden int default 0,
  created_at timestamptz default now()
);

-- RLS
alter table public.ofertas enable row level security;

create policy "Lectura publica ofertas"
  on public.ofertas for select using (true);

create policy "Admin gestiona sus ofertas"
  on public.ofertas for all
  using (
    exists (
      select 1 from public.profiles
      where id = auth.uid()
        and tenant_id = ofertas.tenant_id
        and activo = true
    )
  );

create policy "Superadmin gestiona todas las ofertas"
  on public.ofertas for all
  using (
    exists (
      select 1 from public.profiles
      where id = auth.uid() and rol = 'superadmin'
    )
  );
```

### Lógica de vigencia (client-side)

```javascript
function ofertaEstaActiva(oferta) {
  if (!oferta.activa) return false;
  if (oferta.siempre_activa) return true;

  const hoy = new Date();
  const diasSemana = ['domingo','lunes','martes','miercoles',
                      'jueves','viernes','sabado'];
  const diaHoy = diasSemana[hoy.getDay()];

  // Verificar fechas
  if (oferta.fecha_inicio && oferta.fecha_fin) {
    const inicio = new Date(oferta.fecha_inicio);
    const fin = new Date(oferta.fecha_fin);
    fin.setHours(23, 59, 59);
    if (hoy < inicio || hoy > fin) return false;
  }

  // Verificar días de la semana
  if (oferta.dias_semana && oferta.dias_semana.length > 0) {
    if (!oferta.dias_semana.includes(diaHoy)) return false;
  }

  return true;
}
```

### Visualización en el menú público (menu.html)

Agregar una sección **"🔥 Ofertas de Hoy"** justo antes de los tabs de categorías:

- Solo se muestra si hay al menos una oferta activa ese día
- Fondo degradado llamativo (naranja oscuro a rojo) para diferenciarla del resto
- Cards de oferta con:
  - Badge rojo "OFERTA" en la esquina superior
  - Nombre de la oferta en grande
  - Descripción o contenido del combo
  - Para tipo descuento: precio original tachado + precio oferta en grande
  - Para tipo combo: precio del combo destacado
  - Botón "Agregar" — agrega al carrito igual que cualquier producto
- Título de la sección con icono de fuego animado (CSS animation)
- Si no hay ofertas activas: la sección no se renderiza

### Portal Admin — admin/ofertas.html (página nueva)

- Lista de todas las ofertas con: nombre, tipo, precio, vigencia, activa (toggle)
- Formulario agregar/editar oferta:

  **Tipo de oferta:**
  - Radio: "Descuento en producto" | "Combo especial"

  **Si es Descuento:**
  - Selector de producto existente (dropdown con productos del tenant)
  - Precio de oferta (el original se autocompleta)
  - Preview del ahorro: "El cliente ahorra RD$X (Y%)"

  **Si es Combo:**
  - Nombre del combo
  - Descripción del contenido (textarea)
  - Precio del combo
  - Opción de subir imagen

  **Vigencia (aplica a ambos tipos):**
  - Toggle "Siempre activa"
  - Si no es siempre activa, mostrar:
    - Date picker: Fecha inicio — Fecha fin
    - Checkboxes días de la semana: Lun | Mar | Mié | Jue | Vie | Sáb | Dom
    - Pueden combinarse: fechas Y días específicos

- Toggle activa/inactiva desde la lista
- Eliminar con confirmación

### Agregar enlace en admin/index.html
- Acceso rápido a Ofertas en el dashboard
- Contador de ofertas activas hoy

---

## FUNCIONALIDAD 2: Importación de Productos (CSV)

### Archivo de plantilla — products_template.csv

Claude Code debe generar este archivo como descargable desde el admin:

```
nombre,categoria,precio,descripcion,disponible
Cheese Burger,Hamburguesas,250,Hamburguesa clasica con queso,SI
Bacon Cheese Burger,Hamburguesas,320,Con queso y bacon crujiente,SI
Yaroa de Pollo,Yaroas,280,Base de papas fritas pollo y queso fundido,SI
Coca Cola,Bebidas,80,Lata 355ml,SI
Producto Agotado,Bebidas,50,Este no aparece en el menu,NO
```

### Campos del CSV

| Campo | Requerido | Valores válidos | Default |
|---|---|---|---|
| nombre | ✅ | Texto | — |
| categoria | ✅ | Debe coincidir con una categoría existente del tenant | — |
| precio | ✅ | Número (sin símbolos) | — |
| descripcion | ❌ | Texto | vacío |
| disponible | ❌ | SI / NO | SI |

### UI en admin/productos.html

Agregar botón **"Importar CSV"** junto al botón "Agregar Producto":

**Flujo de importación:**
1. Clic en "Importar CSV"
2. Modal con:
   - Botón para descargar la plantilla `products_template.csv`
   - Área de drag & drop o selector de archivo
   - Vista previa de los productos detectados en tabla (nombre, categoría, precio, disponible)
   - Indicador de errores por fila: categoría no encontrada, precio inválido, nombre vacío
   - Contador: "X productos listos para importar, Y con errores"
   - Botón "Importar X productos válidos"
3. Al confirmar:
   - Insertar solo los productos válidos
   - Resumen final: "Se importaron X productos. Y filas ignoradas por errores."
4. Verificar límite del plan antes de importar:
   - Si plan básico y la importación supera los 30 productos: advertencia
   - "Solo puedes importar X productos más. Los primeros X del archivo serán importados."

### Parsing del CSV (client-side con PapaParse)

```html
<script src="https://cdnjs.cloudflare.com/ajax/libs/PapaParse/5.4.1/papaparse.min.js"></script>
```

```javascript
Papa.parse(file, {
  header: true,
  skipEmptyLines: true,
  complete: async (results) => {
    const categorias = await cargarCategoriasTenant(tenantId);
    const categoriasMap = {};
    categorias.forEach(c => categoriasMap[c.nombre.toLowerCase()] = c.id);

    const validos = [];
    const errores = [];

    results.data.forEach((row, index) => {
      const erroresFila = [];

      if (!row.nombre?.trim()) erroresFila.push('Nombre requerido');
      if (!row.categoria?.trim()) erroresFila.push('Categoria requerida');
      if (!row.precio || isNaN(parseFloat(row.precio))) erroresFila.push('Precio invalido');

      const categoriaId = categoriasMap[row.categoria?.toLowerCase()];
      if (row.categoria && !categoriaId) {
        erroresFila.push(`Categoria "${row.categoria}" no existe`);
      }

      if (erroresFila.length > 0) {
        errores.push({ fila: index + 2, errores: erroresFila, data: row });
      } else {
        validos.push({
          tenant_id: tenantId,
          categoria_id: categoriaId,
          nombre: row.nombre.trim(),
          descripcion: row.descripcion?.trim() || '',
          precio: parseFloat(row.precio),
          disponible: row.disponible?.toUpperCase() !== 'NO'
        });
      }
    });

    mostrarPreviewImportacion(validos, errores);
  }
});
```

---

## Actualizar navegación admin

Agregar en el navbar/sidebar del portal admin el enlace a:
- **Ofertas** (con icono Lucide: `tag`)
- **Importar** ya está dentro de Productos

## Actualizar dashboard admin/index.html

Agregar al dashboard:
- Card: Ofertas activas hoy (contador)
- Card: Total productos / límite del plan

---

## Notas de implementación

- Las ofertas se cargan junto con el menú al inicio — una sola query filtrando por tenant_id
- El filtro de vigencia se hace client-side para no complicar queries
- PapaParse se carga via CDN solo en admin/productos.html, no en páginas públicas
- La plantilla CSV se genera dinámicamente en JS (no es un archivo estático)
- Los combos se agregan al carrito como cualquier producto (nombre + precio_oferta)
- Para tipo descuento, al agregar al carrito usar nombre del producto + "(Oferta)" y precio_oferta
