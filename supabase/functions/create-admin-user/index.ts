import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: 'No authorization header' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Cliente admin con service role
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    // Verificar el token del usuario que hace la llamada
    const token = authHeader.replace('Bearer ', '')
    const { data: { user }, error: userError } = await supabaseAdmin.auth.getUser(token)

    if (userError || !user) {
      return new Response(
        JSON.stringify({ error: 'Token inválido', details: userError }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Verificar el rol del usuario que hace la llamada
    const { data: profile, error: profileError } = await supabaseAdmin
      .from('profiles')
      .select('rol, tenant_id')
      .eq('id', user.id)
      .single()

    if (profileError || !profile || (profile.rol !== 'superadmin' && profile.rol !== 'admin')) {
      return new Response(
        JSON.stringify({ 
           error: 'Acceso denegado por rol o perfil', 
           role: profile?.rol,
           profileError: profileError 
        }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Obtener datos posteados
    const { nombre, email, password, tenant_id, rol } = await req.json()
    const userRole = rol || 'admin'

    // Seguridad adicional para admins normales
    if (profile.rol === 'admin') {
      if (tenant_id !== profile.tenant_id) {
        return new Response(
          JSON.stringify({ error: 'Acceso denegado. Tenant incorrecto.' }),
          { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }
      if (userRole === 'superadmin') {
        return new Response(
          JSON.stringify({ error: 'Acceso denegado. Rol no permitido.' }),
          { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }
    }

    // Verificar si el usuario ya existe
    const { data: { users: existingUsers } } = await supabaseAdmin.auth.admin.listUsers()
    const existingUser = existingUsers?.find(u => u.email === email)

    let userId: string

    if (existingUser) {
      // Usuario ya existe — usar el id existente
      userId = existingUser.id
    } else {
      // Crear nuevo usuario
      const { data: newUser, error: createError } = await supabaseAdmin.auth.admin.createUser({
        email,
        password,
        email_confirm: true
      })

      if (createError) {
        return new Response(
          JSON.stringify({ error: createError.message }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      userId = newUser.user.id
    }

    // Verificar si ya tiene profile
    const { data: existingProfile } = await supabaseAdmin
      .from('profiles')
      .select('id')
      .eq('id', userId)
      .maybeSingle()

    if (!existingProfile) {
      // Crear el profile sin email
      const { error: profileInsertError } = await supabaseAdmin
        .from('profiles')
        .insert({
          id: userId,
          tenant_id,
          nombre,
          rol: userRole,
          activo: true
        })

      if (profileInsertError) {
        return new Response(
          JSON.stringify({ error: profileInsertError.message }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }
    } else {
      // Actualizar profile existente con nuevo tenant
      const { error: profileUpdateError } = await supabaseAdmin
        .from('profiles')
        .update({
          tenant_id,
          nombre,
          rol: userRole,
          activo: true
        })
        .eq('id', userId)

      if (profileUpdateError) {
        return new Response(
          JSON.stringify({ error: profileUpdateError.message }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }
    }

    return new Response(
      JSON.stringify({ success: true, user_id: userId }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
