import { execFile } from "node:child_process";
import { readFile } from "node:fs/promises";
import { dirname, relative, resolve, sep } from "node:path";
import { promisify } from "node:util";
import { TaskError } from "./errors";
import type { ProjectContext, WorkspaceProject } from "./types";

const execFileAsync = promisify(execFile);

interface PnpmProject {
  readonly name?: string;
  readonly path: string;
}

interface PackageManifest {
  readonly name?: string;
  readonly scripts?: Readonly<Record<string, string>>;
}

function contains(directory: string, candidate: string): boolean {
  const path = relative(directory, candidate);
  return (
    path === "" ||
    (!path.startsWith(`..${sep}`) && path !== ".." && !path.startsWith(sep))
  );
}

async function findWorkspaceDirectory(cwd: string): Promise<string> {
  let directory = resolve(cwd);

  while (true) {
    try {
      // Walking parent directories is intentionally sequential.
      // oxlint-disable-next-line no-await-in-loop
      await readFile(resolve(directory, "pnpm-workspace.yaml"));
      return directory;
    } catch (error) {
      const code = (error as NodeJS.ErrnoException).code;
      if (code !== "ENOENT") {
        throw error;
      }
    }

    const parent = dirname(directory);
    if (parent === directory) {
      throw new TaskError(`No pnpm workspace found from ${cwd}`);
    }
    directory = parent;
  }
}

/** Selects the deepest workspace project containing cwd and its child projects. */
export function createProjectContext(
  cwd: string,
  workspaceDirectory: string,
  projects: readonly WorkspaceProject[],
): ProjectContext {
  const absoluteCwd = resolve(cwd);
  const project = projects
    .filter(({ directory }) => contains(directory, absoluteCwd))
    .toSorted(
      (left, right) => right.directory.length - left.directory.length,
    )[0];

  if (!project) {
    throw new TaskError(
      `Current directory is not inside a workspace project: ${absoluteCwd}`,
    );
  }

  const nestedProjects = projects.filter(
    ({ directory }) =>
      directory !== project.directory && contains(project.directory, directory),
  );

  return {
    cwd: absoluteCwd,
    project,
    workspace: {
      directory: workspaceDirectory,
      projects,
    },
    nestedProjects,
  };
}

/**
 * Discovers pnpm's workspace model and reads package scripts. This is the only
 * boundary where Task asks pnpm for workspace membership.
 */
export async function discoverProjectContext(
  cwd = process.cwd(),
): Promise<ProjectContext> {
  const workspaceDirectory = await findWorkspaceDirectory(cwd);
  const { stdout } = await execFileAsync(
    "pnpm",
    ["list", "--recursive", "--depth=-1", "--json"],
    {
      cwd: workspaceDirectory,
      maxBuffer: 10 * 1024 * 1024,
    },
  );
  const listedProjects = JSON.parse(stdout) as readonly PnpmProject[];
  const projects = await Promise.all(
    listedProjects.map(async (listed): Promise<WorkspaceProject> => {
      const directory = resolve(listed.path);
      const manifest = JSON.parse(
        await readFile(resolve(directory, "package.json"), "utf8"),
      ) as PackageManifest;

      return {
        name:
          manifest.name ??
          listed.name ??
          (relative(workspaceDirectory, directory) || "."),
        directory,
        relativeDirectory: relative(workspaceDirectory, directory) || ".",
        scripts: manifest.scripts ?? {},
      };
    }),
  );

  return createProjectContext(cwd, workspaceDirectory, projects);
}
