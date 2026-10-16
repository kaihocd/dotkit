import type { TaskDefinition } from "../src/types";
import { oxlint } from "./oxlint";
import { prettier } from "./prettier";
import { luacheck } from "./luacheck";
import { stylua } from "./stylua";
import { typecheck } from "./tools";

/** Built-in definitions keyed by their complete, opaque Task IDs. */
export const TASK_DEFINITIONS: readonly TaskDefinition[] = [
  typecheck(),
  luacheck(),
  prettier("check"),
  prettier("fix"),
  oxlint("check"),
  oxlint("fix"),
  stylua("check"),
  stylua("fix"),
];
