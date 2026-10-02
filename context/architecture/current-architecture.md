# Arquitectura actual y objetivo inmediato

## Topología

yeGamo se mantiene como un único workspace y repositorio con tres superficies:

```text
Flutter (`yegamo_app/`)
        │ REST/JSON `/v1`
        ▼
API NestJS modular (`api/`)
        ├── reglas de dominio y casos de uso
        ├── gateway de proveedores autorizados
        ├── persistencia PostgreSQL + PostGIS
        └── worker para tareas fuera de la petición
```

El API es stateless para las peticiones HTTP. El estado duradero vive en PostgreSQL; cache, circuit breakers y estado temporal de jobs quedan detrás de abstracciones que permitan escalar horizontalmente.

## Responsabilidades por superficie

### Flutter

Flutter presenta, coordina navegación, mantiene estado de pantalla y persiste el modo invitado localmente. Los widgets no hacen HTTP ni contienen reglas de negocio. Los providers/services consumen el contrato `/v1`, mapean estados canónicos y muestran `CURRENT`, `STALE`, `DEGRADED`, `OFFLINE_CACHE` o `UNAVAILABLE` sin fabricar ETA ni fuente.

### API NestJS

NestJS autentica, autoriza, valida entradas, ejecuta casos de uso y aplica reglas de ranking, planificación, confiabilidad, privacidad e idempotencia. Los módulos se organizan por dominio y el núcleo de planificación/gateway no depende de NestJS, Prisma, `pg` ni un proveedor externo.

### Provider Gateway

El gateway consulta adapters autorizados y convierte sus respuestas a modelos canónicos. Decide timeout, fallback, frescura, circuit breaker, licencia de cache y `dataState`. `DemoTransitProvider` solo puede habilitarse en desarrollo, pruebas o demostración marcada; nunca se publica como fuente productiva.

### Persistencia

PostgreSQL + PostGIS almacena únicamente datos autorizados y con constraints explícitos. Las migraciones SQL versionadas son la fuente de verdad. Prisma Client cubre CRUD tipado; `pg` crudo queda restringido a PostGIS, locking o concurrencia cuando exista justificación documentada.

### Worker

Un proceso worker comparte el código del monolito y ejecuta rutinas, alertas de salida, notificaciones, expiración/retención, métricas agregadas y refresh de feeds cuando la licencia lo permita. No se agrega WebSocket/SSE al MVP.

## Flujo de una petición

```text
request → trace → auth → validación → controller → caso de uso
→ dominio → repositorio/provider gateway → mapper canónico → respuesta `/v1`
```

Los errores usan el contrato canónico con `code`, `message`, `details` y `traceId`. Las decisiones de arquitectura que alteren estos límites requieren un ADR.
