export class AppError extends Error {
  public readonly statusCode: number;
  public readonly code: string;
  public readonly details?: unknown;

  constructor(
    message: string,
    statusCode: number = 400,
    code: string = 'BAD_REQUEST',
    details?: unknown
  ) {
    super(message);
    this.name = 'AppError';
    this.statusCode = statusCode;
    this.code = code;
    this.details = details;
    Object.setPrototypeOf(this, AppError.prototype);
  }
}

export const Errors = {
  badRequest: (message: string, details?: unknown) =>
    new AppError(message, 400, 'BAD_REQUEST', details),
  notFound: (message: string) =>
    new AppError(message, 404, 'NOT_FOUND'),
  conflict: (message: string, details?: unknown) =>
    new AppError(message, 409, 'CONFLICT', details),
  unprocessable: (message: string, details?: unknown) =>
    new AppError(message, 422, 'BUSINESS_RULE_VIOLATION', details),
  storage: (message: string) =>
    new AppError(message, 502, 'STORAGE_ERROR'),
  internal: (message: string = 'Error interno del servidor') =>
    new AppError(message, 500, 'INTERNAL_SERVER_ERROR'),
};
