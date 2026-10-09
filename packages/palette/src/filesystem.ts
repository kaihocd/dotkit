/** Returns whether an unknown failure exposes the requested Node.js error code. */
export function hasErrorCode(
  error: unknown,
  code: string,
): error is NodeJS.ErrnoException {
  return error instanceof Error && "code" in error && error.code === code;
}
