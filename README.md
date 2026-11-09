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
