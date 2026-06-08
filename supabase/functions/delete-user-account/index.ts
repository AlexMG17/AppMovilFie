import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    )

    // Verificar que el llamador está autenticado y es admin
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const { data: { user: caller } } = await supabaseAdmin.auth.getUser(
      authHeader.replace('Bearer ', ''),
    )
    if (!caller) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // Verificar que el llamador es admin
    const { data: callerData } = await supabaseAdmin
      .from('usuarios')
      .select('roles(nombre)')
      .eq('email', caller.email!)
      .single()

    const rolNombre = ((callerData?.roles as { nombre?: string } | null)?.nombre ?? '').toLowerCase()
    if (rolNombre !== 'admin' && rolNombre !== 'administrador') {
      return new Response(JSON.stringify({ error: 'Solo administradores pueden eliminar usuarios' }), {
        status: 403,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const { email } = await req.json() as { email: string }

    if (!email) {
      return new Response(JSON.stringify({ error: 'email es requerido' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // 1. Buscar id_usuario en la tabla usuarios
    const { data: usuarioData } = await supabaseAdmin
      .from('usuarios')
      .select('id_usuario')
      .eq('email', email)
      .maybeSingle()

    const idUsuario = usuarioData?.id_usuario as number | undefined

    if (idUsuario) {
      // 2. Obtener los id_entrada del usuario para borrar asistencias
      const { data: entradas } = await supabaseAdmin
        .from('entradas')
        .select('id_entrada')
        .eq('id_usuario', idUsuario)

      const idsEntrada = (entradas ?? []).map((e: { id_entrada: number }) => e.id_entrada)

      if (idsEntrada.length > 0) {
        // 3. Borrar asistencias ligadas a esas entradas
        await supabaseAdmin
          .from('asistencias')
          .delete()
          .in('id_entrada', idsEntrada)
      }

      // 4. Borrar entradas del usuario
      await supabaseAdmin
        .from('entradas')
        .delete()
        .eq('id_usuario', idUsuario)

      // 5. Borrar pagos del usuario
      await supabaseAdmin
        .from('pagos')
        .delete()
        .eq('id_usuario', idUsuario)

      // 6. Borrar scan_logs si el usuario era validador
      await supabaseAdmin
        .from('scan_logs')
        .delete()
        .eq('id_guardia', idUsuario)

      // 7. Borrar de la tabla usuarios
      await supabaseAdmin
        .from('usuarios')
        .delete()
        .eq('id_usuario', idUsuario)
    }

    // 8. Buscar el auth.uid por email y borrar la cuenta de Supabase Auth
    const { data: authUsers } = await supabaseAdmin.auth.admin.listUsers()
    const authUser = authUsers?.users?.find((u) => u.email === email)

    if (authUser) {
      const { error: deleteAuthError } = await supabaseAdmin.auth.admin.deleteUser(authUser.id)
      if (deleteAuthError) {
        console.error('Error eliminando auth user:', deleteAuthError.message)
        // No bloqueamos — la cuenta de DB ya fue limpiada
      }
    }

    return new Response(
      JSON.stringify({ success: true }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  } catch (err) {
    console.error('delete-user-account error:', String(err))
    return new Response(
      JSON.stringify({ success: false, error: String(err) }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      },
    )
  }
})
