import {
  INestApplication,
  UnprocessableEntityException,
  ValidationPipe,
} from '@nestjs/common';

import { CanonicalHttpExceptionFilter } from './shared/errors/canonical-http-exception.filter';
import { TraceIdInterceptor } from './shared/trace/trace-id.interceptor';

export function configureApp(app: INestApplication): INestApplication {
  app.enableShutdownHooks();
  // Baseline security headers (JSON API: nothing should be framed, sniffed or cached by proxies).
  app.use((_request: unknown, response: { setHeader(name: string, value: string): void }, next: () => void) => {
    response.setHeader('X-Content-Type-Options', 'nosniff');
    response.setHeader('X-Frame-Options', 'DENY');
    response.setHeader('Referrer-Policy', 'no-referrer');
    response.setHeader('Cache-Control', 'no-store');
    response.setHeader('Strict-Transport-Security', 'max-age=15552000; includeSubDomains');
    next();
  });
  (app.getHttpAdapter().getInstance() as { disable?: (name: string) => void }).disable?.('x-powered-by');
  app.setGlobalPrefix('v1');
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
      errorHttpStatusCode: 422,
      exceptionFactory: (errors) => new UnprocessableEntityException(errors),
    }),
  );
  app.useGlobalInterceptors(new TraceIdInterceptor());
  app.useGlobalFilters(new CanonicalHttpExceptionFilter());

  return app;
}
