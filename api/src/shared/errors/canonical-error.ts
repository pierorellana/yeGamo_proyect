export interface CanonicalErrorDetails {
  [key: string]: unknown;
}

export interface CanonicalErrorResponse {
  code: string;
  message: string;
  details: CanonicalErrorDetails;
  traceId: string;
}
