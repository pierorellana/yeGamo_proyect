import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
} from '@nestjs/common';
import type { Response } from 'express';

import type {
  CanonicalErrorDetails,
  CanonicalErrorResponse,
} from './canonical-error';
import {
  resolveTraceId,
  TRACE_ID_HEADER,
  TraceableRequest,
} from '../trace/trace-context';

const ERROR_CODES: Record<number, string> = {
  [HttpStatus.BAD_REQUEST]: 'BAD_REQUEST',
  [HttpStatus.UNAUTHORIZED]: 'UNAUTHORIZED',
  [HttpStatus.FORBIDDEN]: 'FORBIDDEN',
  [HttpStatus.NOT_FOUND]: 'NOT_FOUND',
  [HttpStatus.CONFLICT]: 'CONFLICT',
  [HttpStatus.UNPROCESSABLE_ENTITY]: 'VALIDATION_ERROR',
  [HttpStatus.TOO_MANY_REQUESTS]: 'RATE_LIMITED',
  [HttpStatus.SERVICE_UNAVAILABLE]: 'PROVIDER_UNAVAILABLE',
};

const DEFAULT_MESSAGES: Record<number, string> = {
  [HttpStatus.BAD_REQUEST]: 'La solicitud no es válida.',
  [HttpStatus.UNAUTHORIZED]: 'Falta autenticación válida.',
  [HttpStatus.FORBIDDEN]: 'No tienes permiso para esta operación.',
  [HttpStatus.NOT_FOUND]: 'El recurso solicitado no existe.',
  [HttpStatus.CONFLICT]: 'La operación entra en conflicto con el estado actual.',
  [HttpStatus.UNPROCESSABLE_ENTITY]: 'La solicitud no cumple el contrato.',
  [HttpStatus.TOO_MANY_REQUESTS]: 'Se superó el límite de solicitudes.',
  [HttpStatus.SERVICE_UNAVAILABLE]: 'El servicio no está disponible.',
  [HttpStatus.INTERNAL_SERVER_ERROR]: 'Ocurrió un error interno.',
};

@Catch()
export class CanonicalHttpExceptionFilter implements ExceptionFilter {
  catch(exception: unknown, host: ArgumentsHost): void {
    const http = host.switchToHttp();
    const response = http.getResponse<Response>();
    const request = http.getRequest<TraceableRequest>();
    const status =
      exception instanceof HttpException
        ? exception.getStatus()
        : HttpStatus.INTERNAL_SERVER_ERROR;
    const traceId = request.traceId ?? resolveTraceId(undefined);
    const body = this.toCanonicalResponse(exception, status, traceId);

    response.header(TRACE_ID_HEADER, traceId).status(status).json(body);
  }

  private toCanonicalResponse(
    exception: unknown,
    status: number,
    traceId: string,
  ): CanonicalErrorResponse {
    const exceptionResponse =
      exception instanceof HttpException ? exception.getResponse() : undefined;
    const responseObject = this.asRecord(exceptionResponse);
    const rawMessage = responseObject?.message;
    const details: CanonicalErrorDetails = {};

    if (Array.isArray(rawMessage)) {
      details.validationErrors = rawMessage;
    } else if (responseObject !== undefined && rawMessage !== undefined) {
      details.originalMessage = rawMessage;
    }

    return {
      code: ERROR_CODES[status] ?? 'INTERNAL_ERROR',
      message:
        typeof rawMessage === 'string'
          ? rawMessage
          : DEFAULT_MESSAGES[status] ??
            DEFAULT_MESSAGES[HttpStatus.INTERNAL_SERVER_ERROR] ??
            'Ocurrió un error interno.',
      details,
      traceId,
    };
  }

  private asRecord(value: unknown): Record<string, unknown> | undefined {
    if (typeof value === 'object' && value !== null) {
      return value as Record<string, unknown>;
    }

    if (typeof value === 'string') {
      return { message: value };
    }

    return undefined;
  }
}
