# Mudanzas

Aplicación Flutter para solicitar mudanzas, seleccionar origen/destino en mapa,
escoger vehículo y seguir al conductor en tiempo real.

## Arquitectura

- `lib/`: aplicación Flutter para Android y web.
- `supabase/`: backend versionado (PostgreSQL, PostGIS, Auth, RLS y Realtime).
- OpenStreetMap/Nominatim: mapa, búsqueda y geocodificación durante el prototipo.

El backend vive en este mismo repositorio, pero en una carpeta independiente.
Así una migración de base de datos puede revisarse junto con la versión de la
app que la usa. Si posteriormente aparece un servidor propio grande, puede
extraerse sin cambiar la estructura actual de Flutter.

## Backend local

Requisitos: Docker y [Supabase CLI](https://supabase.com/docs/guides/local-development/cli/getting-started).

```powershell
npm install
npm run backend:start
npm run backend:reset
```

La migración inicial crea perfiles, vehículos, solicitudes, historial de
estados y ubicaciones. Todas las tablas tienen Row Level Security. Los canales
`move:<uuid>` son privados y solo admiten al cliente, conductor asignado o un
administrador.

La analítica local está desactivada porque Vector no puede acceder al socket de
Docker Desktop en Windows. Esto no desactiva la base de datos, Auth, Realtime,
Storage ni Studio.

## Conectar un proyecto de Supabase

1. Crear un proyecto gratuito en Supabase.
2. Copiar la URL y la clave pública (`anon`/publishable) desde la configuración
   del proyecto. Nunca colocar `service_role` dentro de Flutter.
3. Aplicar la migración:

```powershell
npx supabase login
npx supabase link --project-ref TU_PROJECT_REF
npx supabase db push
```

4. En Realtime Settings, desactivar **Allow public access** para exigir las
   políticas de los canales privados.
5. Ejecutar la app con las credenciales públicas:

```powershell
flutter run --dart-define=SUPABASE_URL=https://TU-PROYECTO.supabase.co `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=TU_CLAVE_PUBLICA
```

Sin esos valores, la aplicación conserva el modo demo y no escribe datos.

### Google OAuth local

Crea `supabase/.env.local` (está excluido de Git) con:

```env
SUPABASE_AUTH_EXTERNAL_GOOGLE_CLIENT_ID=TU_CLIENT_ID
SUPABASE_AUTH_EXTERNAL_GOOGLE_CLIENT_SECRET=TU_CLIENT_SECRET
```

El cliente OAuth de Google debe permitir el callback local
`http://127.0.0.1:54321/auth/v1/callback`. En Android, Supabase regresa a la
app mediante `io.supabase.mudanzas://login-callback/`.

## Seguimiento sin saturar la cuota

`LiveTrackingService` publica la ubicación por Realtime como máximo cada 10
segundos, o antes si el conductor se mueve al menos 25 metros. La base de datos
guarda el último punto y un punto histórico aproximadamente cada minuto. Esto
mantiene el mapa fluido sin hacer una escritura por cada lectura del GPS.

## Verificación

```powershell
flutter analyze
flutter test
```

## APK desde la nube

El flujo `.github/workflows/android.yml` ejecuta análisis, pruebas y genera una
APK ARM64 en GitHub Actions cada vez que cambia `main`. La APK queda disponible
durante 30 días como artefacto de la ejecución.

Al subir una etiqueta que coincida con la versión de `pubspec.yaml`, por ejemplo
`v1.0.11`, el mismo flujo crea un GitHub Release y adjunta la APK. La URL y clave
pública de Supabase están configuradas como variables de Actions; la llave de
firma Android y sus contraseñas están guardadas como secretos del repositorio.
