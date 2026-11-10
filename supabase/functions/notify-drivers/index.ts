import { createClient } from 'npm:@supabase/supabase-js@2'
import { JWT } from 'npm:google-auth-library@9'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const authorization = req.headers.get('Authorization')
    if (!authorization) return json({ error: 'No autorizado' }, 401)

    const supabaseUrl = requiredEnv('SUPABASE_URL')
    const anonKey = requiredEnv('SUPABASE_ANON_KEY')
    const serviceRoleKey = requiredEnv('SUPABASE_SERVICE_ROLE_KEY')

    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authorization } },
    })
    const { data: userData, error: userError } = await userClient.auth.getUser()
    if (userError || !userData.user) return json({ error: 'No autorizado' }, 401)

    const { move_id: moveId } = await req.json()
    if (typeof moveId !== 'string') return json({ error: 'Solicitud inválida' }, 400)

    const { data: move, error: moveError } = await userClient
      .from('move_requests')
      .select('id,customer_id,vehicle_type,origin_address,destination_address,route_distance_meters,status')
      .eq('id', moveId)
      .eq('customer_id', userData.user.id)
      .eq('status', 'requested')
      .single()
    if (moveError || !move) return json({ error: 'Mudanza no encontrada' }, 404)

    const admin = createClient(supabaseUrl, serviceRoleKey)
    const { data: drivers, error: driversError } = await admin
      .from('profiles')
      .select('id')
      .eq('role', 'driver')
    if (driversError) throw driversError

    const driverIds = (drivers ?? []).map((driver) => driver.id)
    if (driverIds.length === 0) return json({ sent: 0 })

    const { data: devices, error: devicesError } = await admin
      .from('push_tokens')
      .select('token')
      .in('user_id', driverIds)
    if (devicesError) throw devicesError

    const tokens = [...new Set((devices ?? []).map((device) => device.token))]
    if (tokens.length === 0) return json({ sent: 0 })

    const serviceAccount = JSON.parse(requiredEnv('FIREBASE_SERVICE_ACCOUNT'))
    const jwt = new JWT({
      email: serviceAccount.client_email,
      key: serviceAccount.private_key,
      scopes: ['https://www.googleapis.com/auth/firebase.messaging'],
    })
    const accessToken = await jwt.getAccessToken()
    if (!accessToken.token) throw new Error('No se pudo autorizar FCM')

    const vehicle = vehicleLabel(move.vehicle_type)
    const results = await Promise.all(tokens.map((token) =>
      sendMessage(serviceAccount.project_id, accessToken.token!, token, {
        title: 'Nueva mudanza disponible',
        body: `${vehicle} · ${distanceLabel(move.route_distance_meters)}`,
        moveId: move.id,
      })
    ))

    return json({ sent: results.filter(Boolean).length, devices: tokens.length })
  } catch (error) {
    console.error(error)
    return json({ error: error instanceof Error ? error.message : 'Error interno' }, 500)
  }
})

async function sendMessage(
  projectId: string,
  accessToken: string,
  token: string,
  content: { title: string; body: string; moveId: string },
) {
  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        message: {
          token,
          notification: { title: content.title, body: content.body },
          data: { type: 'available_move', move_id: content.moveId },
          android: {
            priority: 'high',
            notification: {
              sound: 'default',
              icon: 'ic_stat_truck',
              color: '#176B87',
            },
          },
        },
      }),
    },
  )
  if (!response.ok) {
    console.error('FCM error', response.status, await response.text())
    return false
  }
  return true
}

function requiredEnv(name: string) {
  const value = Deno.env.get(name)
  if (!value) throw new Error(`Falta el secreto ${name}`)
  return value
}

function vehicleLabel(value: string) {
  if (value === 'motocarro') return 'Motocarro'
  if (value === 'camioneta_estacas') return 'Camioneta de estacas'
  if (value === 'turbo') return 'Turbo'
  return 'Mudanza'
}

function distanceLabel(meters: number | null) {
  if (!meters) return 'distancia por calcular'
  const kilometers = meters / 1000
  return `${kilometers < 10 ? kilometers.toFixed(1) : Math.round(kilometers)} km`
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}
