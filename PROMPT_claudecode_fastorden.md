# Prompt para Claude Code — Fast Orden SaaS

Lee los archivos SPEC_fastorden.md adjunto y construye el proyecto Fast Orden completo.

## Credenciales Supabase
- URL: https://yetdmvlisxavxdwdxyyb.supabase.co
- Publishable key: sb_publishable_ysSwpu3wAKcKR4OQzynpTg_Dvk8NznP

## Stack
- HTML + CSS + Vanilla JS (ES Modules)
- Tailwind CSS via CDN
- Lucide Icons via CDN (https://unpkg.com/lucide@latest/dist/umd/lucide.min.js)
- Supabase JS v2 via CDN (https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2)
- Google Fonts: Bebas Neue + Nunito

## Identidad Visual Fast Orden
- Tema oscuro siempre (#0a0a0a fondo)
- Color primario Fast Orden: #f97316 (naranja)
- Acento: #facc15 (amarillo dorado)
- Los tenants tienen sus propios colores aplicados dinamicamente via CSS variables
- Tipografia: Bebas Neue para titulos, Nunito para body
- Iconos: Lucide Icons exclusivamente

## Orden de construccion

### Fase 1 — Base
1. Estructura completa de carpetas y archivos
2. assets/js/supabase.js — cliente Supabase configurado
3. assets/js/auth.js — login, logout, proteccion de rutas, deteccion de rol
4. assets/js/tenant-theme.js — aplicar colores/logo/nombre del tenant dinamicamente
5. assets/css/main.css — variables CSS, estilos base, tema oscuro

### Fase 2 — Portal Publico
6. menu.html — menu publico del tenant (lee ?tenant=slug de la URL)
   - Navbar con logo y nombre del tenant
   - Hero con slogan
   - Buscador en tiempo real
   - Tabs por categorias
   - Cards de productos
   - Carrito lateral
   - Flujo de pedido modal (tipo entrega → pago → datos → confirmacion)
   - Mensaje WhatsApp dinamico con datos del tenant
7. cuentas.html — cuentas bancarias del tenant con boton copiar

### Fase 3 — Portal Admin
8. login.html — login unificado con redireccion por rol
9. admin/index.html — dashboard con contadores y barra de progreso del plan
10. admin/productos.html — CRUD con limite de plan basico (30 productos)
11. admin/categorias.html — CRUD categorias
12. admin/cuentas.html — CRUD cuentas bancarias
13. admin/configuracion.html — personalizar nombre, slogan, logo, whatsapp, moneda, colores, costo delivery

### Fase 4 — Portal Superadmin
14. superadmin/index.html — dashboard con metricas globales
15. superadmin/tenants.html — lista y gestion de todos los tenants
16. superadmin/crear-tenant.html — formulario crear tenant + usuario admin

## Logica de planes
- Plan basico: maximo 30 productos
- Plan pro: ilimitado
- Verificar limite antes de permitir agregar producto
- En admin/index.html mostrar barra de progreso: X/30 productos usados
- Si plan vencido: bloquear acceso al admin con mensaje de renovacion
- Si plan vence en menos de 15 dias: mostrar alerta en dashboard

## Logica multi-tenant critica
- TODOS los queries deben incluir .eq('tenant_id', tenantId)
- El tenant_id del admin logueado se obtiene de su profile en Supabase
- Guardarlo en sessionStorage al hacer login para no hacer query extra en cada pagina
- El menu publico obtiene el tenant via query param: ?tenant=slug
- Los colores, logo, nombre y slogan se aplican dinamicamente al cargar el menu

## URLs en GitHub Pages (sin rewrites)
- Menu publico: /menu.html?tenant=castillosabor
- Login: /login.html
- Admin: /admin/index.html
- Superadmin: /superadmin/index.html

## Notas importantes
- No hay registro publico de tenants — solo el superadmin los crea
- El superadmin tiene tenant_id = null en su profile
- Usar sessionStorage para el tenant actual, no localStorage
- Validar plan antes de cada operacion de escritura en productos
- El buscador filtra client-side sobre productos ya cargados en memoria

## Creacion de usuarios admin — Supabase Edge Function

Al crear un tenant desde superadmin, el usuario admin se crea via Edge Function
para no exponer el service_role key en el frontend.

### Crear la Edge Function en Supabase
Archivo: supabase/functions/create-admin-user/index.ts

```typescript
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  // Verificar que quien llama es superadmin
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) return new Response('Unauthorized', { status: 401 })

  const supabaseAdmin = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  )

  // Verificar que el token pertenece a un superadmin
  const supabaseClient = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: authHeader } } }
  )

  const { data: { user } } = await supabaseClient.auth.getUser()
  if (!user) return new Response('Unauthorized', { status: 401 })

  const { data: profile } = await supabaseAdmin
    .from('profiles')
    .select('rol')
    .eq('id', user.id)
    .single()

  if (!profile || profile.rol !== 'superadmin') {
    return new Response('Forbidden', { status: 403 })
  }

  // Crear el usuario admin del tenant
  const { nombre, email, password, tenant_id } = await req.json()

  const { data: newUser, error } = await supabaseAdmin.auth.admin.createUser({
    email,
    password,
    email_confirm: true
  })

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' }
    })
  }

  // Crear el profile vinculado al tenant
  await supabaseAdmin.from('profiles').insert({
    id: newUser.user.id,
    tenant_id,
    nombre,
    email,
    rol: 'admin'
  })

  return new Response(JSON.stringify({ success: true, user_id: newUser.user.id }), {
    headers: { 'Content-Type': 'application/json' }
  })
})
```

### Como llamarla desde el frontend (superadmin/crear-tenant.html)
```javascript
// 1. Primero crear el tenant
const { data: tenant } = await supabase
  .from('tenants')
  .insert({ slug, nombre, slogan, whatsapp, plan, ciclo, plan_expira_at, ... })
  .select()
  .single()

// 2. Luego crear el usuario admin via Edge Function
const { data: { session } } = await supabase.auth.getSession()

const response = await fetch(
  'https://yetdmvlisxavxdwdxyyb.supabase.co/functions/v1/create-admin-user',
  {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${session.access_token}`
    },
    body: JSON.stringify({
      nombre: adminNombre,
      email: adminEmail,
      password: adminPassword,
      tenant_id: tenant.id
    })
  }
)

const result = await response.json()
```

### Desplegar la Edge Function
Claude Code debe generar el archivo de la Edge Function y las instrucciones para deployarla:
```bash
npx supabase functions deploy create-admin-user --project-ref yetdmvlisxavxdwdxyyb
```

## Empezar por
1. Estructura de carpetas
2. supabase.js
3. auth.js
4. menu.html con toda su logica
