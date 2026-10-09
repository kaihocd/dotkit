import { randomBytes } from "node:crypto";
import { mkdir, mkdtemp, rm } from "node:fs/promises";
import {
  createServer,
  createConnection,
  type Server,
  type Socket,
} from "node:net";
import { tmpdir } from "node:os";
import { join } from "node:path";
import type { TaskStore } from "./store";
import type {
  CommandFrame,
  OutputChunk,
  ProcessResult,
  TaskEvent,
  TaskRunId,
} from "./types";

const SOCKET_ENV = "DOTKIT_TASK_EVENT_SOCKET";
const TOKEN_ENV = "DOTKIT_TASK_EVENT_TOKEN";
const PROTOCOL_VERSION = 1;

type WireResult =
  | {
      readonly status: "exited";
      readonly exitCode: number | null;
      readonly signal: NodeJS.Signals | null;
    }
  | { readonly status: "spawn-error"; readonly message: string };

type WireEvent =
  | {
      readonly type: "workspace-started";
      readonly runId: number;
      readonly id: string;
      readonly script: string;
      readonly packageCount: number;
      readonly startedAt: number;
    }
  | {
      readonly type: "command-started";
      readonly runId: number;
      readonly parentRunId?: number;
      readonly id: string;
      readonly projectName: string;
      readonly command: CommandFrame["command"];
      readonly startedAt: number;
    }
  | {
      readonly type: "command-output";
      readonly runId: number;
      readonly sequence: number;
      readonly stream: OutputChunk["stream"];
      readonly data: string;
    }
  | {
      readonly type: "command-finished";
      readonly runId: number;
      readonly id: string;
      readonly projectName: string;
      readonly command: CommandFrame["command"];
      readonly result: WireResult;
      readonly durationMs: number;
      readonly finishedAt: number;
    }
  | {
      readonly type: "workspace-finished";
      readonly runId: number;
      readonly id: string;
      readonly script: string;
      readonly durationMs: number;
      readonly succeeded: boolean;
      readonly finishedAt: number;
    };

type WireMessage =
  | { readonly version: 1; readonly type: "hello"; readonly token: string }
  | { readonly version: 1; readonly type: "event"; readonly event: WireEvent };

function encodeResult(result: ProcessResult): WireResult {
  return result.status === "spawn-error"
    ? { status: "spawn-error", message: result.error.message }
    : result;
}

function decodeResult(result: WireResult): ProcessResult {
  return result.status === "spawn-error"
    ? { status: "spawn-error", error: new Error(result.message) }
    : result;
}

function encodeEvent(event: TaskEvent): WireEvent {
  switch (event.type) {
    case "workspace-started":
    case "command-started":
      return event;
    case "command-output":
      return {
        type: event.type,
        runId: event.runId,
        sequence: event.chunk.sequence,
        stream: event.chunk.stream,
        data: Buffer.from(event.chunk.data).toString("base64"),
      };
    case "command-finished":
      return {
        type: event.type,
        runId: event.runId,
        id: event.frame.id,
        projectName: event.frame.projectName,
        command: event.frame.command,
        result: encodeResult(event.frame.result),
        durationMs: event.frame.durationMs,
        finishedAt: event.finishedAt,
      };
    case "workspace-finished":
      return {
        type: event.type,
        runId: event.runId,
        id: event.frame.id,
        script: event.frame.script,
        durationMs: event.frame.durationMs,
        succeeded: event.frame.packages.every(
          ({ result }) => result.status === "exited" && result.exitCode === 0,
        ),
        finishedAt: event.finishedAt,
      };
  }
}

function writeMessage(socket: Socket, message: WireMessage): void {
  socket.write(`${JSON.stringify(message)}\n`);
}

export class NestedEventClient {
  private unsubscribe?: () => void;

  private constructor(private readonly socket: Socket) {}

  public static async connectFromEnvironment(): Promise<
    NestedEventClient | undefined
  > {
    const socketPath = process.env[SOCKET_ENV];
    const token = process.env[TOKEN_ENV];
    if (!socketPath || !token) return undefined;
    const socket = createConnection(socketPath);
    await new Promise<void>((resolve, reject) => {
      socket.once("connect", resolve);
      socket.once("error", reject);
    });
    writeMessage(socket, { version: PROTOCOL_VERSION, type: "hello", token });
    return new NestedEventClient(socket);
  }

  public attach(store: TaskStore): void {
    this.unsubscribe = store.subscribe((_tree, event) => {
      writeMessage(this.socket, {
        version: PROTOCOL_VERSION,
        type: "event",
        event: encodeEvent(event),
      });
    });
  }

  public async dispose(): Promise<void> {
    this.unsubscribe?.();
    this.unsubscribe = undefined;
    const drained = new Promise<void>((resolve, reject) => {
      let response = "";
      this.socket.setEncoding("utf8");
      this.socket.on("data", (chunk: string) => {
        response += chunk;
        if (response.includes("drained\n")) resolve();
      });
      this.socket.once("error", reject);
      this.socket.once("close", () => {
        if (!response.includes("drained\n")) {
          reject(
            new Error(
              "Nested Task event connection closed before acknowledgement",
            ),
          );
        }
      });
    });
    this.socket.end();
    await drained;
  }
}

interface Registration {
  readonly parentRunId: TaskRunId;
  readonly token: string;
}

export class NestedEventServer {
  private readonly registrations = new Map<string, Registration>();
  private nextImportedRunId = -1;
  private server?: Server;
  private directory?: string;
  private socketPath?: string;

  public constructor(private readonly store: TaskStore) {}

  public async start(): Promise<void> {
    this.directory = await mkdtemp(join(tmpdir(), "dotkit-task-"));
    await mkdir(this.directory, { mode: 0o700, recursive: true });
    this.socketPath = join(this.directory, "events.sock");
    this.server = createServer((socket) => this.accept(socket));
    await new Promise<void>((resolve, reject) => {
      this.server!.once("error", reject);
      this.server!.listen(this.socketPath, resolve);
    });
  }

  public environment(parentRunId: TaskRunId): Readonly<Record<string, string>> {
    if (!this.socketPath)
      throw new Error("Nested event server has not started");
    const token = randomBytes(24).toString("hex");
    this.registrations.set(token, { parentRunId, token });
    return { [SOCKET_ENV]: this.socketPath, [TOKEN_ENV]: token };
  }

  public async dispose(): Promise<void> {
    if (this.server) {
      await new Promise<void>((resolve) => this.server!.close(() => resolve()));
    }
    if (this.directory)
      await rm(this.directory, { recursive: true, force: true });
    this.server = undefined;
    this.directory = undefined;
    this.socketPath = undefined;
  }

  private accept(socket: Socket): void {
    let buffer = "";
    let registration: Registration | undefined;
    const runIds = new Map<number, TaskRunId>();
    socket.setEncoding("utf8");
    socket.on("data", (chunk: string) => {
      buffer += chunk;
      for (;;) {
        const newline = buffer.indexOf("\n");
        if (newline < 0) break;
        const line = buffer.slice(0, newline);
        buffer = buffer.slice(newline + 1);
        const message = JSON.parse(line) as WireMessage;
        if (message.version !== PROTOCOL_VERSION) {
          socket.destroy(new Error("Unsupported nested Task protocol version"));
          return;
        }
        if (message.type === "hello") {
          registration = this.registrations.get(message.token);
          if (!registration)
            socket.destroy(new Error("Invalid nested Task token"));
          continue;
        }
        if (!registration) {
          socket.destroy(new Error("Nested Task sent an event before hello"));
          return;
        }
        this.importEvent(message.event, registration.parentRunId, runIds);
      }
    });
    socket.on("end", () => socket.end("drained\n"));
  }

  private importEvent(
    event: WireEvent,
    parentRunId: TaskRunId,
    runIds: Map<number, TaskRunId>,
  ): void {
    const importedRunId = this.importedRunId(event.runId, runIds);
    switch (event.type) {
      case "workspace-started":
        this.store.dispatch({ ...event, runId: importedRunId, parentRunId });
        break;
      case "command-started":
        this.store.dispatch({
          ...event,
          runId: importedRunId,
          parentRunId:
            event.parentRunId === undefined
              ? parentRunId
              : this.importedRunId(event.parentRunId, runIds),
        });
        break;
      case "command-output":
        this.store.dispatch({
          type: event.type,
          runId: importedRunId,
          chunk: {
            sequence: event.sequence,
            stream: event.stream,
            data: Buffer.from(event.data, "base64"),
          },
        });
        break;
      case "command-finished":
        this.store.dispatch({
          type: event.type,
          runId: importedRunId,
          frame: {
            type: "command",
            id: event.id,
            projectName: event.projectName,
            command: event.command,
            output: [],
            result: decodeResult(event.result),
            durationMs: event.durationMs,
          },
          finishedAt: event.finishedAt,
        });
        break;
      case "workspace-finished":
        this.store.dispatch({
          type: event.type,
          runId: importedRunId,
          frame: {
            type: "workspace",
            id: event.id,
            script: event.script,
            packages: event.succeeded
              ? []
              : [
                  {
                    type: "command",
                    id: "nested failure",
                    projectName: "nested",
                    command: { executable: "", args: [], cwd: "" },
                    output: [],
                    result: { status: "exited", exitCode: 1, signal: null },
                    durationMs: 0,
                  },
                ],
            durationMs: event.durationMs,
          },
          finishedAt: event.finishedAt,
        });
        break;
    }
  }

  private importedRunId(
    remoteRunId: number,
    runIds: Map<number, TaskRunId>,
  ): TaskRunId {
    const existing = runIds.get(remoteRunId);
    if (existing !== undefined) return existing;
    const imported = this.nextImportedRunId--;
    runIds.set(remoteRunId, imported);
    return imported;
  }
}
