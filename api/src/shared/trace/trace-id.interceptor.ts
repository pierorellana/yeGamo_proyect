import {
  CallHandler,
  ExecutionContext,
  Injectable,
  NestInterceptor,
} from '@nestjs/common';
import type { Response } from 'express';
import { Observable, tap } from 'rxjs';

import {
  resolveTraceId,
  TRACE_ID_HEADER,
  TraceableRequest,
} from './trace-context';

@Injectable()
export class TraceIdInterceptor implements NestInterceptor {
  intercept(
    context: ExecutionContext,
    next: CallHandler,
  ): Observable<unknown> {
    const http = context.switchToHttp();
    const request = http.getRequest<TraceableRequest>();
    const response = http.getResponse<Response>();
    const traceId = resolveTraceId(request.headers['x-trace-id']);

    request.traceId = traceId;
    response.header(TRACE_ID_HEADER, traceId);

    return next.handle().pipe(
      tap(() => response.header(TRACE_ID_HEADER, traceId)),
    );
  }
}
