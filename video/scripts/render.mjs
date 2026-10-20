// Renders every composition (or the ones named: node scripts/render.mjs Flood-1x1) to out/<id>.mp4, plus a still.
import { spawnSync } from "node:child_process";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const bin = join(root, "node_modules", ".bin", "remotion");
const run = (args) => {
  const r = spawnSync(bin, args, { cwd: root, stdio: "inherit" });
  if (r.status !== 0) process.exit(r.status ?? 1);
};
const list = spawnSync(bin, ["compositions", "src/index.ts", "--quiet"], { cwd: root, encoding: "utf8" });
const all = list.stdout.split(/\s+/).filter((s) => /^[A-Za-z]+-\d+x\d+$/.test(s));
const ids = process.argv.slice(2).length ? process.argv.slice(2) : all;
for (const id of ids) {
  run(["render", "src/index.ts", id, `out/${id}.mp4`, "--codec=h264", "--crf=20", "--log=error"]);
  run(["still", "src/index.ts", id, `out/${id}.png`, "--frame=300", "--log=error"]);
}
