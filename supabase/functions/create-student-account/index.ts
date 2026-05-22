import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const CHARS = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789'

function generatePassword(length = 8): string {
  return Array.from(
    { length },
    () => CHARS[Math.floor(Math.random() * CHARS.length)],
  ).join('')
}

function buildEmailHtml(nombre: string, email: string, password: string): string {
  return `
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="margin:0;padding:0;background:#f1f5f9;font-family:'Segoe UI',Arial,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#f1f5f9;padding:40px 0;">
    <tr>
      <td align="center">
        <table width="480" cellpadding="0" cellspacing="0" style="background:#ffffff;border-radius:20px;overflow:hidden;box-shadow:0 4px 24px rgba(0,0,0,0.08);">
          <!-- Header -->
          <tr>
            <td style="background:linear-gradient(135deg,#0f2463 0%,#1565C0 60%,#00BCD4 100%);padding:36px 32px;text-align:center;">
              <p style="margin:0;font-size:28px;font-weight:800;color:#ffffff;letter-spacing:2px;">SENTRY</p>
              <p style="margin:8px 0 0;font-size:13px;color:rgba(255,255,255,0.75);">Gala FIE 2026 · ESPOCH</p>
            </td>
          </tr>
          <!-- Body -->
          <tr>
            <td style="padding:36px 32px;">
              <p style="margin:0 0 8px;font-size:20px;font-weight:700;color:#0f2463;">¡Hola, ${nombre.split(' ')[0]}!</p>
              <p style="margin:0 0 24px;font-size:14px;color:#64748b;line-height:1.6;">
                Tu entrada para la <strong>Gala FIE 2026</strong> ha sido confirmada. Ya tienes una cuenta en Sentry con las siguientes credenciales:
              </p>

              <!-- Credentials box -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background:#f8fafc;border:1.5px solid #e2e8f0;border-radius:12px;margin-bottom:24px;">
                <tr>
                  <td style="padding:20px 24px;">
                    <p style="margin:0 0 12px;font-size:11px;font-weight:700;color:#94a3b8;text-transform:uppercase;letter-spacing:1px;">Tus credenciales</p>
                    <table width="100%" cellpadding="0" cellspacing="0">
                      <tr>
                        <td style="padding:6px 0;">
                          <span style="font-size:12px;color:#64748b;">Correo</span><br>
                          <span style="font-size:15px;font-weight:700;color:#0f2463;">${email}</span>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding:10px 0 6px;">
                          <span style="font-size:12px;color:#64748b;">Contraseña temporal</span><br>
                          <span style="font-size:22px;font-weight:800;color:#1565C0;letter-spacing:3px;font-family:'Courier New',monospace;">${password}</span>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>

              <!-- Warning -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background:#fff7ed;border:1.5px solid #fed7aa;border-radius:10px;margin-bottom:24px;">
                <tr>
                  <td style="padding:14px 18px;">
                    <p style="margin:0;font-size:13px;color:#9a3412;">
                      ⚠️ <strong>Al ingresar por primera vez</strong>, el sistema te pedirá cambiar esta contraseña por una nueva de tu elección.
                    </p>
                  </td>
                </tr>
              </table>

              <p style="margin:0 0 6px;font-size:14px;color:#475569;line-height:1.6;">
                Ingresa a la app <strong>Sentry</strong>, selecciona <em>"Estudiante Politécnico"</em> e inicia sesión con tu correo y la contraseña temporal.
              </p>
              <p style="margin:0;font-size:13px;color:#94a3b8;">
                Tu QR de entrada estará disponible inmediatamente después de cambiar tu contraseña.
              </p>
            </td>
          </tr>
          <!-- Footer -->
          <tr>
            <td style="background:#f8fafc;padding:20px 32px;border-top:1px solid #e2e8f0;text-align:center;">
              <p style="margin:0;font-size:11px;color:#94a3b8;">
                Este correo fue enviado automáticamente por el sistema Sentry · FIE ESPOCH<br>
                Si tienes dudas, contacta a la organización del evento.
              </p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>`
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

    // Verify caller is an authenticated admin
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

    const { nombre, email, carrera, cedula } = await req.json() as {
      nombre: string
      email: string
      carrera: string
      cedula?: string
    }

    if (!email || !nombre) {
      return new Response(JSON.stringify({ error: 'nombre y email son requeridos' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // Check if user already exists
    const { data: existing } = await supabaseAdmin.auth.admin.listUsers()
    const alreadyExists = existing?.users?.some(
      (u) => u.email?.toLowerCase() === email.toLowerCase(),
    )

    if (alreadyExists) {
      return new Response(
        JSON.stringify({ success: true, already_exists: true }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    const password = generatePassword()

    const { error: createError } = await supabaseAdmin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: {
        nombre,
        carrera: carrera ?? '',
        cedula: cedula ?? '',
        must_change_password: true,
      },
    })

    if (createError) {
      return new Response(
        JSON.stringify({ success: false, error: createError.message }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        },
      )
    }

    // Send email via Resend
    const resendKey = Deno.env.get('RESEND_API_KEY')
    if (resendKey) {
      const fromAddress = Deno.env.get('RESEND_FROM') ?? 'Sentry FIE <onboarding@resend.dev>'
      await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${resendKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          from: fromAddress,
          to: email,
          subject: '🎉 Tu entrada Gala FIE 2026 - Credenciales Sentry',
          html: buildEmailHtml(nombre, email, password),
        }),
      })
    }

    return new Response(
      JSON.stringify({ success: true, already_exists: false }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  } catch (err) {
    return new Response(
      JSON.stringify({ success: false, error: String(err) }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      },
    )
  }
})
