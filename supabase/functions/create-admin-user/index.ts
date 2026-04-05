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
