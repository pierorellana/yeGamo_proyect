import {
  INestApplication,
  UnprocessableEntityException,
  ValidationPipe,
} from '@nestjs/common';

import { CanonicalHttpExceptionFilter } from './shared/errors/canonical-http-exception.filter';
import { TraceIdInterceptor } from './shared/trace/trace-id.interceptor';

export function configureApp(app: INestApplication): INestApplication {
  app.enableShutdownHooks();
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
