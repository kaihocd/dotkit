import { expect, test } from "vitest";
import { truncateStyledLine, wrapStyledLine } from "../src/rendering/output";

const open = "\u001b]8;;file:///tmp/test.lua\u0007";
const close = "\u001b]8;;\u0007";

test("wraps hyperlinks without linking task prefixes", () => {
  expect(wrapStyledLine(`${open}abcdef${close}`, "| ", "| ", 6)).toEqual([
    `| ${open}abc${close}`,
    `| ${open}def${close}`,
  ]);
});

test("closes truncated hyperlinks before the ellipsis", () => {
  expect(truncateStyledLine(`${open}abcdef${close}`, 4)).toBe(
    `${open}abc${close}…`,
  );
});

test("preserves ST-terminated links and removes unrelated controls", () => {
  const start = "\u001b]8;id=example;file:///tmp/test.lua\u001b\\";
  const end = "\u001b]8;;\u001b\\";
  expect(wrapStyledLine(`\u001b[2J${start}abc${end}`, "", "", 80)).toEqual([
    `${start}abc${end}`,
  ]);
});
