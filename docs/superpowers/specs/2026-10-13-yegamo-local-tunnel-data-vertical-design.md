# yeGamo — vertical local con datos y túnel móvil

**Fecha:** 2026-10-13  
**Estado:** aprobado para planificación e implementación  
**Ámbito:** API NestJS, PostgreSQL/PostGIS, cliente Flutter y ejecución desde un iPhone conectado por datos móviles

## Objetivo

Habilitar una vertical local verificable de yeGamo que permita al cliente
Flutter conectado a un iPhone físico consumir el API mediante una URL HTTPS
pública generada por el reenvío de puertos de VS Code, consultar el catálogo
demo de transporte desde PostgreSQL/PostGIS y planificar un viaje con el
proveedor demo de desarrollo.

El resultado debe funcionar con una URL de túnel proporcionada en tiempo de
ejecución mediante `YEGAMO_API_BASE_URL`; ninguna URL pública, credencial o
dato de usuario se versiona.

## Alcance

### Incluido

- Preparación local de PostgreSQL con PostGIS y `pgcrypto`.
- Aplicación y verificación de las migraciones existentes en
  `api/db/migrations/`.
- Carga explícita del seed sintético de desarrollo en
  `api/db/seeds/development.sql`.
- Lectura del catálogo de paradas y rutas mediante un repositorio de API
  conectado al puerto `TransitReadPort`.
- Consulta PostGIS de paradas cercanas con `ST_DWithin` y distancia con
  `ST_Distance`.
- Respuestas honestas: el catálogo sintético se marca como `DEGRADED`; no se
  inventan ETA ni se publica `LIVE`.
- Activación explícita de `DemoTransitProvider` únicamente en desarrollo para
  `POST /v1/journeys/plan`.
- Corrección del flujo Flutter Home para no enviar peticiones protegidas desde
  una sesión invitada y para enviar coordenadas cuando consulte cercanía.
- Flujo de permiso de ubicación delegado al diálogo nativo del sistema
  operativo, sin una alerta simulada previa dentro de Flutter.
- Declaraciones nativas de ubicación `while-in-use` para iOS y Android,
  necesarias para que `geolocator` pueda solicitar y leer la posición.
- Radio de consulta de 3000 m cuando `YEGAMO_DEMO_DATA=true`, para cubrir el
  fixture sintético disperso; en otros entornos se conserva el radio de
  1000 m.
- Configuración de Flutter con la URL HTTPS del túnel mediante
  `--dart-define`.
- Pruebas automatizadas de los límites API/Flutter y verificación manual del
  flujo desde el iPhone.
- Documentación reproducible de arranque, migración, seed y túnel.

### Fuera de alcance

- Integración de un proveedor autorizado de transporte o geocodificación.
- Autenticación OIDC real, emisión de tokens o bypass de seguridad.
- Persistencia de ubicación precisa sin consentimiento.
- ETA, frecuencia o estado `LIVE` derivados del catálogo sintético.
- WebSocket, SSE, microservicios o una segunda base operativa.
- Publicación permanente del API en Internet.
- Rediseño de las 17 pantallas baseline.

## Criterios de aceptación

1. Con PostgreSQL/PostGIS activo, `npm run db:migrate` aplica todas las
   migraciones desde una base vacía y `npm run db:verify` confirma extensiones,
   tablas e índices requeridos.
2. El seed solo se ejecuta con `yegamo.seed_mode=development` y deja las
   paradas demo cercanas a las coordenadas de Guayaquil definidas en el
   fixture.
3. `GET /v1/health` responde `200`.
4. `GET /v1/transit/stops/nearby?lat=-2.1550&lon=-79.8950&radiusM=3000`
   responde `200` con las paradas demo, sus coordenadas, distancia y
   `dataState: DEGRADED`.
5. La misma consulta fuera del radio responde una lista vacía, no un error ni
   una ETA inventada.
6. `POST /v1/journeys/plan` responde con el proveedor demo solo cuando
   `NODE_ENV` no es `production` y `DEMO_PROVIDER_ENABLED=true`; sus datos
   permanecen degradados y sin timestamps LIVE.
7. Una sesión Flutter invitada no provoca `401` por cargar Home, favoritos o
   notificaciones; favoritos y notificaciones permanecen locales hasta que
   exista una sesión autenticada.
8. El botón de permiso invoca directamente `requestPermission` de la
   plataforma; Flutter no muestra una alerta que imite el permiso nativo.
9. Con `YEGAMO_DEMO_DATA=true`, las consultas de cercanía usan el radio máximo
   permitido de 3000 m sin sustituir las coordenadas reales del dispositivo.
10. iOS declara `NSLocationWhenInUseUsageDescription` y Android declara
    `ACCESS_FINE_LOCATION` y `ACCESS_COARSE_LOCATION`.
11. Flutter acepta una URL HTTPS del túnel con
   `--dart-define=YEGAMO_API_BASE_URL=...` y el iPhone puede consultar el API
   usando datos móviles.
12. No se versionan `.env`, tokens, credenciales, artefactos generados ni datos
   de usuarios.
13. Pasan `git diff --check`, typecheck/build/tests del API y
    `flutter analyze`/tests del cliente aplicables.

## Diseño técnico

### Flujo de datos

```text
PostgreSQL + PostGIS
  └─ migraciones + seed demo
       └─ PrismaTransitReadRepository
            └─ TransitService
                 └─ GET /v1/transit/stops/nearby

DemoTransitProvider (solo development)
  └─ TransitGatewayService
       └─ POST /v1/journeys/plan

iPhone por datos móviles
  └─ URL HTTPS pública de VS Code Ports
       └─ NestJS escuchando en 0.0.0.0:3000
            └─ Flutter ApiClient configurado por YEGAMO_API_BASE_URL
```

### API y persistencia

El módulo Transit dejará de usar `UnavailableTransitReadPort` como
implementación operativa y usará un repositorio de infraestructura que
implemente `TransitReadPort`. Las consultas PostGIS se mantendrán dentro del
repositorio, con parámetros enlazados, porque requieren funciones
geoespaciales que no son CRUD ordinario.

La consulta de cercanía filtrará agencias, paradas y estados canónicos activos,
calculará metros desde el origen y ordenará por distancia. La ruta incluirá su
agencia canónica. Como el esquema actual no contiene horarios de transporte,
el endpoint de departures devolverá una lista vacía y la app conservará el
estado explícito de “Llegadas no disponibles”.

El seed de desarrollo es un fixture sintético. Sus entidades se mapearán a
`DEGRADED`; no se presentarán como proveedor autorizado ni como información en
tiempo real.

### Flujo invitado de Flutter

`HomeRepository` recibirá las dependencias necesarias para distinguir una
sesión invitada y obtener coordenadas sin persistirlas. Solo solicitará
paradas cercanas cuando exista un origen válido. Las consultas de favoritos,
notificaciones y rutinas continuarán bajo control de sus repositorios:

- invitado: almacenamiento local;
- autenticado: almacenamiento local más sincronización API.

Esto evita que Home convierta una sesión invitada válida en un estado de error
por `401` y evita enviar `/transit/stops/nearby` sin `lat` y `lon`.

### Permiso nativo y cobertura del fixture demo

La pantalla Flutter de permisos explica el uso de ubicación y conserva la
opción de origen manual, pero su acción principal delega directamente en
`LocationService.requestWhileInUse()`. No se renderiza una alerta que imite el
diálogo de iOS o Android: el sistema operativo decide el texto, botones y
momento de la solicitud. La app solo representa el resultado posterior
(`granted`, `denied`, `deniedForever`, `serviceDisabled` o `restricted`).

Cuando `YEGAMO_DEMO_DATA=true`, `HomeRepository` y `NearbyRepository` siguen
usando las coordenadas reales concedidas por el sistema, pero envían
`radiusM=3000` para que el catálogo demo de desarrollo pueda aparecer aunque
sus dos paradas estén separadas varios kilómetros. Sin esa bandera, el cliente
usa `radiusM=1000`.

La configuración de plataforma declara únicamente el permiso foreground/
while-in-use: `NSLocationWhenInUseUsageDescription` en iOS y
`ACCESS_FINE_LOCATION`/`ACCESS_COARSE_LOCATION` en Android. No se solicita ni
se declara ubicación en segundo plano.

La pantalla Nearby conservará su origen manual para poder comprobar el fixture
de Guayaquil desde cualquier ubicación física. Esta ruta de prueba no concede
permisos ni persiste coordenadas.

### Túnel y configuración móvil

El API no necesita CORS para el cliente Flutter nativo. NestJS escuchará en su
configuración local normal sobre el puerto 3000; VS Code Ports expondrá ese
puerto con visibilidad pública y una URL HTTPS. Flutter recibirá esa URL en
tiempo de ejecución:

```bash
fvm flutter run -d 00008140-001461680A7B801C \
  --dart-define=YEGAMO_ENV=development \
  --dart-define=YEGAMO_DEMO_DATA=true \
  --dart-define=YEGAMO_API_BASE_URL=https://URL_DEL_TUNEL
```

La URL del túnel no se escribirá en código ni en archivos versionados. Si el
túnel cambia, se reinicia Flutter con el nuevo valor.

## Manejo de errores

- Sin `DATABASE_URL`: `db:migrate` y `db:verify` fallan explícitamente.
- Sin PostgreSQL/PostGIS: el arranque de migración se considera bloqueado; no
  se simula un pase con SQLite, memoria o datos Flutter.
- Sin proveedor autorizado: journeys responde el error canónico de proveedor
  no disponible, salvo que el proveedor demo haya sido habilitado
  explícitamente en desarrollo.
- Sin coordenadas: Flutter muestra permiso/origen requerido y no hace una
  petición inválida.
- Sin token en modo invitado: Flutter no llama endpoints protegidos.
- URL de túnel inválida o caída: `ApiClient` conserva sus estados de red y no
  presenta datos como actuales.

## Verificación

### API

```bash
cd api
PATH=/Users/jorge/.nvm/versions/node/v20.19.4/bin:$PATH npm run db:migrate
PATH=/Users/jorge/.nvm/versions/node/v20.19.4/bin:$PATH npm run db:verify
PATH=/Users/jorge/.nvm/versions/node/v20.19.4/bin:$PATH npm test -- --runInBand --watchman=false
PATH=/Users/jorge/.nvm/versions/node/v20.19.4/bin:$PATH npm run typecheck
PATH=/Users/jorge/.nvm/versions/node/v20.19.4/bin:$PATH npm run build
```

### Flutter

```bash
cd yegamo_app
fvm flutter analyze
fvm flutter test
```

### Runtime

Con el API levantado y el puerto reenviado, comprobar `/v1/health`, paradas
cercanas desde el fixture de Guayaquil y planificación desde la app en el
iPhone por datos móviles. El resultado debe conservar `X-Trace-Id` y los
estados de calidad definidos por el contrato.

## Límites y decisiones

- Se conserva el monolito modular NestJS.
- Se conserva PostgreSQL/PostGIS como fuente operativa única.
- Las migraciones existentes son la fuente ejecutable; no se crea un SQL
  paralelo de bootstrap.
- El seed no se ejecuta automáticamente desde el runner de migraciones.
- La URL de túnel es configuración de ejecución, no configuración de producto.
- El proveedor demo es una capacidad explícita de desarrollo, no una fuente
  productiva.
