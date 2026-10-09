import { join } from "node:path";
import { defineProfiles } from "./src/profiles";

export default defineProfiles(({ home }) => ({
  xdg: {
    XDG_CONFIG_HOME: join(home, ".config"),
    XDG_DATA_HOME: join(home, ".local", "share"),
    XDG_CACHE_HOME: join(home, ".cache"),
    XDG_STATE_HOME: join(home, ".local", "state"),
  },
}));
