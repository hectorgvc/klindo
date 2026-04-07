# Fast Orden - Contexto de Sesión
## Última actualización: 2026-04-07 21:00

---

## Estado General
- Proyecto: Fast Orden (SaaS de pedidos para restaurantes)
- Plan actual: Implementando funcionalidades PRO
- Último commit: `2b31038` - "WIP: fix profiles recursion and cache busting"

---

## ARCHIVOS CREADOS/MODIFICADOS HOY

### Nuevos archivos PRO:
- `/caja.html` - Módulo cajera (tablet/PC mostrador)
- `/cocina.html` - Pantalla de cocina (solo lectura)
- `/turnos.html` - Pantalla pública TV para turnos
- `/orden.html` - Seguimiento de orden del cliente (URL única)
- `/admin/dashboard.html` - Dashboard con estadísticas
- `/admin/notas.html` - Gestión de notas predefinidas
- `/admin/pedidos.html` - Historial de pedidos del tenant

### SQL creados:
- `/supabase_fastorden_pro.sql` - Tablas y RLS para módulo PRO
- `/fix_profiles_recursion.sql` - FIX para error de recursión en profiles
- `/fix_recursion_final.sql` - FIX DEFINITIVO aplicado con función is_superadmin()

### Archivos modificados:
- `/login.html` - Separada consulta de profiles/tenants, cache `?v=6`

---

## ESTADO DE ERRORES

### ✅ FIXED: Infinite Recursion en Profiles
**SQL Ejecutado:**
```sql
DROP POLICY IF EXISTS "Superadmin ve todos los perfiles" ON profiles;

CREATE OR REPLACE FUNCTION public.is_superadmin()
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM auth.users
    WHERE id = auth.uid()
    AND (raw_user_meta_data->>'rol' = 'superadmin' OR raw_app_meta_data->>'rol' = 'superadmin')
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE POLICY "Superadmin ve todos los perfiles"
  ON profiles FOR ALL
  USING (is_superadmin());
```

**Resultado:** Success. No rows returned

---

### 🔄 PENDIENTE: JSON Coercion Error
**Síntoma:** `Cannot coerce the result to a single JSON object`

**Causa:** La consulta `.select('*, tenants(*)')` con `.single()` causaba problemas

**Fix aplicado en login.html:**
- Cambiado a consulta separada: primero profiles, luego tenants
- Usando `.maybeSingle()` en lugar de `.single()`
- Cache actualizado a `?v=6`

**Próximo paso:** Testear login con hard refresh (Ctrl+Shift+R)

---

## TABLAS PENDIENTES DE CREAR EN SUPABASE

Ejecutar `/supabase_fastorden_pro.sql` en orden:

1. Tabla `pedidos`
2. Tabla `items_pedido`
3. Tabla `notas_predefinidas`
4. Tabla `configuracion_pro`
5. Función `get_next_numero_orden()`
6. Habilitar realtime en las tablas

---

## RLS PENDIENTES (después de fix profiles)

Las policies de las tablas nuevas (`pedidos`, `items_pedido`, etc.) están definidas en `supabase_fastorden_pro.sql` pero necesitan que el fix de profiles funcione primero.

---

## FLUJO DE PEDIDO PRO - IMPLEMENTACIÓN PENDIENTE

### En menu.html:
- [ ] Modal de notas predefinidas al agregar producto
- [ ] Llamada a `get_next_numero_orden(tenant_id)` al confirmar
- [ ] Insert en tabla `pedidos`
- [ ] Insert en tabla `items_pedido` con notas
- [ ] Generar mensajes WhatsApp (negocio + cliente)
- [ ] Mostrar pantalla de confirmación con número y link de seguimiento

### Módulos en tiempo real:
- [ ] Caja: Suscripción realtime a cambios de pedidos
- [ ] Cocina: Suscripción a pedidos en_preparacion
- [ ] Turnos: Suscripción a pedidos listos
- [ ] Orden: Suscripción a cambios de estado del pedido

---

## ARCHIVOS CLAVE

| Archivo | Descripción |
|---------|-------------|
| `login.html` | Login de usuarios (fix JSON aplicado, cache v6) |
| `menu.html` | Menú público del negocio |
| `caja.html` | Módulo cajera PRO |
| `cocina.html` | Módulo cocina PRO |
| `turnos.html` | Pantalla TV turnos PRO |
| `orden.html` | Seguimiento orden cliente PRO |
| `assets/js/supabase.js` | Cliente Supabase v2 |
| `supabase_fastorden_pro.sql` | Schema PRO completo |
| `fix_recursion_final.sql` | Fix definitivo recursión |

---

## CONFIGURACIÓN SUPABASE

**URL:** `https://yetdmvlisxavxdwdxyyb.supabase.co`

**Policies de profiles actuales:**
- "Usuario ve su perfil" - SELECT (auth.uid() = id) ✅
- "Superadmin ve todos los perfiles" - ALL (is_superadmin()) ✅

---

## PRÓXIMAS TAREAS AL REGRESAR

1. **PRIORIDAD ALTA:** Testear login con hard refresh (Ctrl+Shift+R)
2. Si login funciona → Crear tablas PRO en Supabase
3. Implementar flujo de pedido en menu.html
4. Configurar realtime en módulos

---

## NOTAS

- El plan Lite está funcionando, estamos agregando funcionalidades PRO
- Se usa Supabase Realtime para actualización en tiempo real
- El número de orden es diario (reinicia cada día)
- Hay dos mensajes WhatsApp: uno al negocio, uno al cliente

