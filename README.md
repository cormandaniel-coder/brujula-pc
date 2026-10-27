# Brújula P&C

Plataforma del equipo de Planeamiento Financiero y Control de Gestión para seguir los reportes mensuales, aprender y proponer mejoras, con rangos, un personaje 3D y un vestidor.

- `index.html`: la aplicación completa (una sola página).
- `supabase/schema.sql`: tablas, permisos y datos de ejemplo de la base de datos.

## Cómo funciona
- La web se publica con GitHub Pages.
- Los datos y el ingreso viven en Supabase.
- Cada persona entra eligiendo su nombre y su contraseña. Internamente cada usuario es `<clave>@brujula-pc.com`, donde la clave es `jefe`, `lider`, `analista`, `auxiliar` o `asistente`. No se envía ningún correo.
- Armando (jefe) y Alvaro (líder) pueden administrar reportes, ideas y cursos. Los demás solo ven los datos y editan su propio alias y personaje, y proponen ideas.

## Seguridad
- La clave `sb_publishable_…` que aparece en `index.html` es pública por diseño. Los permisos reales los aplican las reglas de seguridad (RLS) de `supabase/schema.sql`.
- No subir nunca la clave `sb_secret_…`, la `service_role` ni la contraseña de la base de datos.
- No guardar cifras financieras de la Caja. Solo nombres de reportes, fechas y estados.
