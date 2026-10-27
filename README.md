# Brújula P&C

Plataforma del equipo de Planeamiento Financiero y Control de Gestión para seguir los reportes mensuales, aprender y proponer mejoras, con rangos, un personaje 3D y un vestidor.

- `index.html`: la aplicación completa (una sola página).
- `supabase/schema.sql`: tablas, permisos y datos de ejemplo de la base de datos.
- `supabase/actualizacion-2.sql`: penalidades, rango protegido y Sala de entrenamiento.
- `supabase/actualizacion-3.sql`: fotos del equipo en un espacio privado de Supabase Storage.
- `supabase/actualizacion-4.sql`: personaje vivo, entrega y validación de reportes con historial, reconocimientos, preguntas del equipo, apoyos y comentarios en ideas, y reinicio de temporada.

Los archivos SQL se ejecutan en orden: `schema.sql`, `actualizacion-2`, `-3` y `-4`.

## Cómo funciona
- La web se publica con GitHub Pages.
- Los datos y el ingreso viven en Supabase.
- Cada persona entra eligiendo su nombre y su contraseña. Internamente cada usuario es `<clave>@brujula-pc.com`, donde la clave es `jefe`, `lider`, `analista`, `auxiliar` o `asistente`. No se envía ningún correo.
- Armando (jefe) y Alvaro (líder) pueden administrar reportes, ideas y cursos. Los demás solo ven los datos y editan su propio alias y personaje, y proponen ideas.

## Qué incluye
- **Mi día**: lo primero al entrar. Muestra cómo está tu detective y qué necesita, convertido en tareas concretas.
- **Personaje vivo**: cuatro necesidades (Energía, Orden, Conocimiento y Ánimo) que se llenan con trabajo real y bajan en días hábiles. Tiene emociones visibles, una motivación propia y, si no se le atiende, se desvanece. Nunca muere ni quita XP. Tiene modo vacaciones. El equipo ve el estado de cada detective.
- **Reportes**: el responsable marca «En curso» o «Entregado» con evidencia, el copiloto registra su revisión y la Comisaría pone el sello con comentario obligatorio en observaciones, errores o tardanza. Todo queda en un historial. Las penalidades solo las ven el interesado y la Comisaría.
- **Tablero del Comisario**: indicadores del mes, tendencia, bandeja de validación, detalle por persona y exportación a Excel (CSV) o PDF.
- **Sala de entrenamiento**: Pregunta del día, 5 minijuegos y preguntas propuestas por el equipo.
- **Ideas** con responsable, siguiente paso, apoyos y comentarios. **Reconocimientos** entre compañeros.
- Guía de bienvenida, cambio de contraseña obligatorio en el primer ingreso, fotos privadas y reinicio de temporada para empezar todos en cero.
- Los XP y rangos son un juego interno del equipo: no forman parte de la evaluación de desempeño oficial ni de la remuneración.

## Seguridad
- La clave `sb_publishable_…` que aparece en `index.html` es pública por diseño. Los permisos reales los aplican las reglas de seguridad (RLS) de `supabase/schema.sql`.
- No subir nunca la clave `sb_secret_…`, la `service_role` ni la contraseña de la base de datos.
- No guardar cifras financieras de la Caja. Solo nombres de reportes, fechas y estados.
- La privacidad de las penalidades se aplica en la app y en el historial (`cp_events`, protegido con RLS). El estado de cada reporte en la tabla `checkpoints` lo puede leer cualquier usuario con sesión iniciada.
