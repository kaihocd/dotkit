/** An expected operational error that callers may present without a stack trace. */
export class ExpectedError extends Error {
  public constructor(message: string, options?: ErrorOptions) {
    super(message, options);
    this.name = new.target.name;
  }
}
