# Brújula P&C

Plataforma del equipo de Planeamiento Financiero y Control de Gestión para seguir los reportes mensuales, aprender y proponer mejoras, con rangos, un personaje 3D y un vestidor.

- `index.html`: la aplicación completa (una sola página).
- `supabase/schema.sql`: tablas, permisos y datos de ejemplo de la base de datos.
- `supabase/actualizacion-2.sql`: penalidades, rango protegido y Sala de entrenamiento.
- `supabase/actualizacion-3.sql`: fotos del equipo en un espacio privado de Supabase Storage.
- `supabase/actualizacion-4.sql`: personaje vivo, entrega y validación de reportes con historial, reconocimientos, preguntas del equipo, apoyos y comentarios en ideas, y reinicio de temporada.
- `supabase/actualizacion-5.sql`: borrar el historial de un reporte o de un expediente, nombres de cursos editables desde la Academia y fecha de cada avance de la Academia.

Los archivos SQL se ejecutan en orden: `schema.sql`, `actualizacion-2`, `-3`, `-4` y `-5`.

## Cómo funciona
- La web se publica con GitHub Pages.
- Los datos y el ingreso viven en Supabase.
- Cada persona entra eligiendo su nombre y su contraseña. Internamente cada usuario es `<clave>@brujula-pc.com`, donde la clave es `jefe`, `lider`, `analista`, `auxiliar` o `asistente`. No se envía ningún correo.
- Armando (jefe) y Alvaro (líder) pueden administrar reportes, ideas y cursos. Los demás solo ven los datos y editan su propio alias y personaje, y proponen ideas.

## Qué incluye
- **Mi día**: lo primero al entrar. Muestra cómo está tu detective y qué necesita, convertido en tareas concretas.
- **Personaje vivo**: cinco cualidades en un gráfico de araña (Energía, Orden, Conocimiento, Ánimo y Precisión) y una frase financiera del día. Las cuatro primeras que se llenan con trabajo real y bajan en días hábiles. Tiene emociones visibles, una motivación propia y, si no se le atiende, se desvanece. Nunca muere ni quita XP. Tiene modo vacaciones. El equipo ve el estado de cada detective.
- **Reportes**: el responsable marca «En curso» o «Entregado» con evidencia, el copiloto registra su revisión y la Comisaría pone el sello con comentario obligatorio en observaciones, errores o tardanza. Todo queda en un historial. Las penalidades solo las ven el interesado y la Comisaría.
- **Detective del mes**: el 1 de cada mes se muestra el top 3 del mes anterior (sin el Comisario) por XP ganados en ese mes, y en vivo cómo va el mes en curso.
- **Insignias mensuales**: siete insignias que se ganan cada mes (plazo, cero errores, copiloto, aprendizaje, ideas, reconocimientos y Detective del mes). Si se repiten suben de nivel. La credencial muestra también las habilidades que el equipo refuerza en conjunto.
- **Academia**: el avance de cada curso y los nombres de cursos y habilidades se editan en la misma página, solo Armando y Alvaro.
- **Tablero del Comisario**: indicadores del mes, tendencia, bandeja de validación, detalle por persona y exportación a Excel (CSV) o PDF.
- **Sala de entrenamiento**: Pregunta del día con sustento de la respuesta correcta, 5 minijuegos (Interrogatorio, ¿Verdad o mito?, Palabra oculta, ¿Sube o baja?, Ordena el proceso) y preguntas propuestas por el equipo.
- **Ideas** con responsable, siguiente paso, apoyos y comentarios. **Reconocimientos** entre compañeros.
- Guía de bienvenida, cambio de contraseña obligatorio en el primer ingreso, fotos privadas y reinicio de temporada para empezar todos en cero.
- Los XP y rangos son un juego interno del equipo: no forman parte de la evaluación de desempeño oficial ni de la remuneración.

## Seguridad
- La clave `sb_publishable_…` que aparece en `index.html` es pública por diseño. Los permisos reales los aplican las reglas de seguridad (RLS) de `supabase/schema.sql`.
- No subir nunca la clave `sb_secret_…`, la `service_role` ni la contraseña de la base de datos.
- No guardar cifras financieras de la Caja. Solo nombres de reportes, fechas y estados.
- La privacidad de las penalidades se aplica en la app y en el historial (`cp_events`, protegido con RLS). El estado de cada reporte en la tabla `checkpoints` lo puede leer cualquier usuario con sesión iniciada.
