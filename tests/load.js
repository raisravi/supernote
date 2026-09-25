// Load a QML .js library into a plain object for node tests.
// Strips ".pragma library" and emulates `.import "x.js" as Name` (loads x.js into its own context).
const fs = require("fs");
const path = require("path");
const vm = require("vm");
module.exports = function load(file) {
  const dir = path.dirname(file);
  let src = fs.readFileSync(file, "utf8").replace(/^\.pragma library\s*$/m, "");
  const ctx = {};
  vm.createContext(ctx);
  src = src.replace(/^\.import\s+"([^"]+)"\s+as\s+(\w+)\s*$/gm, (_, rel, name) => {
    ctx[name] = module.exports(path.join(dir, rel));
    return "";
  });
  vm.runInContext(src, ctx);
  return ctx;
};
