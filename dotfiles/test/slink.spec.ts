import { execFile } from "node:child_process";
import { lstat, mkdtemp, readlink, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { promisify } from "node:util";

import { describe, expect, it, onTestFinished } from "vitest";

async function fixture() {
  const root = await mkdtemp(join(tmpdir(), "dotkit-dotfiles-"));
  const home = join(root, "home");
  const configHome = join(home, ".config");
  const dataHome = join(home, ".local", "share");
  onTestFinished(() => rm(root, { force: true, recursive: true }));
  return { root, home, configHome, dataHome };
}

const packageDirectory = resolve(import.meta.dirname, "..");
const executeFile = promisify(execFile);

async function runSlink({
  home,
  configHome,
  dataHome,
  onlyPreview = false,
}: {
  readonly home: string;
  readonly configHome: string;
  readonly dataHome: string;
  readonly onlyPreview?: boolean;
}) {
  await executeFile(
    "pnpm",
    [
      "exec",
      "tsx",
      join(packageDirectory, "scripts/slink.ts"),
      ...(onlyPreview ? ["--only-preview"] : []),
    ],
    {
      cwd: packageDirectory,
      env: {
        ...process.env,
        HOME: home,
        XDG_CONFIG_HOME: configHome,
        XDG_DATA_HOME: dataHome,
      },
    },
  );
}

describe("Dotfiles slink", () => {
  it("links visible Zsh sources to their conventional target names", async () => {
    const { home, configHome, dataHome } = await fixture();

    await runSlink({ home, configHome, dataHome });

    await expect(readlink(join(home, ".zshenv"))).resolves.toBe(
      join(packageDirectory, "configs", "zsh", "zshenv.zsh"),
    );
    await expect(readlink(join(configHome, "zsh", ".zshrc"))).resolves.toBe(
      join(packageDirectory, "configs", "zsh", "zshrc.zsh"),
    );
    await Promise.all(
      ["fzf.zsh", "keys.zsh", "tools.zsh"].map(async (name) => {
        await expect(readlink(join(configHome, "zsh", name))).resolves.toBe(
          join(packageDirectory, "configs", "zsh", name),
        );
      }),
    );
  });

  it("links application configurations to their XDG targets", async () => {
    const { home, configHome, dataHome } = await fixture();

    await runSlink({ home, configHome, dataHome });

    await expect(readlink(join(configHome, "starship.toml"))).resolves.toBe(
      join(packageDirectory, "configs", "starship", "starship.toml"),
    );
    await expect(readlink(join(configHome, "wezterm"))).resolves.toBe(
      join(packageDirectory, "configs", "wezterm"),
    );
    await expect(readlink(join(configHome, "nvim"))).resolves.toBe(
      join(packageDirectory, "configs", "nvim"),
    );
    await expect(lstat(dataHome)).rejects.toMatchObject({ code: "ENOENT" });
  });

  it("previews all links without changing the filesystem", async () => {
    const { home, configHome, dataHome } = await fixture();

    await runSlink({ onlyPreview: true, home, configHome, dataHome });

    await expect(lstat(join(home, ".zshenv"))).rejects.toMatchObject({
      code: "ENOENT",
    });
    await expect(lstat(join(configHome, "zsh"))).rejects.toMatchObject({
      code: "ENOENT",
    });
    await expect(
      lstat(join(configHome, "starship.toml")),
    ).rejects.toMatchObject({
      code: "ENOENT",
    });
    await expect(lstat(join(configHome, "wezterm"))).rejects.toMatchObject({
      code: "ENOENT",
    });
    await expect(lstat(join(configHome, "nvim"))).rejects.toMatchObject({
      code: "ENOENT",
    });
    await expect(lstat(dataHome)).rejects.toMatchObject({ code: "ENOENT" });
  });
});
