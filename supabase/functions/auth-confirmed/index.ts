const appCallback = 'io.supabase.mudanzas://login-callback/'

// Compatibilidad con los correos enviados antes de usar el enlace profundo.
// El navegador conserva el fragmento de autenticacion al seguir una redireccion
// cuyo destino no declara otro fragmento.
Deno.serve(() => new Response(null, {
  status: 302,
  headers: {
    Location: appCallback,
    'Cache-Control': 'no-store',
  },
}))
