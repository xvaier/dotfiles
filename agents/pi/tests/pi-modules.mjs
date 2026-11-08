// Preload for `node --test`: when a bare import (@earendil-works/*, typebox) cannot be resolved
// from this repository, resolve it from the managed Pi install so tests and extensions load the
// same packages Pi does.
import { readFileSync } from "node:fs";
import { registerHooks } from "node:module";
import { homedir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

const install = join(process.env.PI_CODING_AGENT_DIR || join(homedir(), ".pi/agent"), "install");
const modules = process.env.PI_NODE_MODULES
  || join(install, "releases", readFileSync(join(install, "current-version"), "utf8").trim(), "node_modules");
const anchor = pathToFileURL(join(modules, "pi-tests-anchor.js")).href;

registerHooks({
  resolve(specifier, context, next) {
    try {
      return next(specifier, context);
    } catch (error) {
      if (error.code !== "ERR_MODULE_NOT_FOUND") throw error;
      return next(specifier, { ...context, parentURL: anchor });
    }
  },
});
