import { spawnSync } from "node:child_process";
import {
  cpSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { resolve } from "node:path";

const root = resolve(import.meta.dirname, "..");
const workspace = mkdtempSync(resolve(tmpdir(), "picker-types-"));
const fixture = readFileSync(
  resolve(import.meta.dirname, "selection-types.lua"),
  "utf8",
);

function check(extra: string) {
  writeFileSync(resolve(workspace, "fixture.lua"), fixture + extra);
  const result = spawnSync(
    "lua-language-server",
    ["--check=.", "--checklevel=Hint", "--configpath=.luarc.json"],
    { cwd: workspace, encoding: "utf8", timeout: 30_000 },
  );

  if (result.error) throw result.error;
  if (result.status === null)
    throw new Error("LuaLS terminated without an exit code");
  return { status: result.status, output: result.stdout + result.stderr };
}

try {
  cpSync(
    resolve(root, "lua/picker/selection"),
    resolve(workspace, "lua/picker/selection"),
    { recursive: true },
  );
  const config = JSON.parse(readFileSync(resolve(root, ".luarc.json"), "utf8"));
  config.diagnostics = {
    ...config.diagnostics,
    neededFileStatus: {
      "param-type-mismatch": "Any",
      "assign-type-mismatch": "Any",
      "unknown-operator": "Any",
    },
  };
  writeFileSync(resolve(workspace, ".luarc.json"), JSON.stringify(config));

  const valid = check("");
  if (valid.status !== 0) throw new Error(valid.output);
  console.log("PASS valid inferred item type");

  const cases = [
    ["reject wrong replacement array", "\nselection:replace(123)\n"],

    [
      "retain current item type",
      "\n---@param value number\nlocal function take_number(value)\n  print(value)\nend\nlocal current = selection:current()\nif current then\n  take_number(current)\nend\n",
    ],
  ];

  for (const [name, source] of cases) {
    const invalid = check(source);
    if (
      invalid.status === 0 ||
      !/param-type-mismatch|type-check|unknown-operator/.test(invalid.output)
    ) {
      throw new Error(`${name}: expected a type diagnostic\n${invalid.output}`);
    }
    console.log(`PASS ${name}`);
  }

  // LuaLS 3.19.1 does not reject incompatible array element types even for a
  // non-generic function. Keep the limitation visible, separate from passes.
  const arrayProbe = check(`
---@param entries SelectionTestItem[]
local function consume_items(entries)
  print(entries)
end
---@type number[]
local numbers = { 123 }
consume_items(numbers)
`);
  if (arrayProbe.status === 0) {
    console.warn(
      "LIMITATION: LuaLS accepts number[] for SelectionTestItem[] even without Selection or generics",
    );
  } else if (!arrayProbe.output.includes("param-type-mismatch")) {
    throw new Error(arrayProbe.output);
  } else {
    const replacement = check(
      "\n---@type number[]\nlocal numbers = { 123 }\nselection:replace(numbers)\n",
    );
    if (
      replacement.status === 0 ||
      !replacement.output.includes("param-type-mismatch")
    ) {
      throw new Error(
        `Array checking works, but Selection loses the item type\n${replacement.output}`,
      );
    }
    console.log("PASS reject wrong replacement item type");
  }
} finally {
  rmSync(workspace, { recursive: true, force: true });
}
