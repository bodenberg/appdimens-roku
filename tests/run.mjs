// Packages the test channel (library + tests) and runs it in brs-cli (brs-engine).
// Exit code 0 only when the suite prints "APPDIMENS RESULT: OK".
import { execFileSync } from "node:child_process";
import { cpSync, mkdirSync, rmSync, existsSync, readFileSync, writeFileSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const out = join(root, "build", "tests-channel");
rmSync(out, { recursive: true, force: true });
mkdirSync(join(out, "source"), { recursive: true });
mkdirSync(join(out, "tests"), { recursive: true });
cpSync(join(root, "tests", "manifest"), join(out, "manifest"));
cpSync(join(root, "source"), join(out, "source"), { recursive: true });
cpSync(join(root, "tests", "source"), join(out, "source"), { recursive: true });
for (const f of ["golden.json", "custom-strategy-fixture.json"]) {
  if (existsSync(join(root, "tests", f))) cpSync(join(root, "tests", f), join(out, "tests", f));
}
const zip = join(root, "build", "tests-channel.zip");
rmSync(zip, { force: true });
execFileSync("zip", ["-qr", zip, "."], { cwd: out });
const cli = join(root, "node_modules", ".bin", "brs-cli");
let text = "";
try {
  text = execFileSync(cli, [zip], { encoding: "utf8", stdio: ["ignore", "pipe", "pipe"], timeout: 600000 });
} catch (e) {
  text = (e.stdout || "") + (e.stderr || "");
}
const clean = (t) => t.split("\n").filter((l) => !/Network Gateway|spawnSync ip/.test(l)).join("\n");
console.log(clean(text));
let ok = /APPDIMENS RESULT: OK/.test(text);

// SceneGraph example: a single ui_resolution (fhd) keeps 1920x1080 coordinates (firmware autoscale);
// "hd,fhd" follows the device (brs-engine simulates an HD device → 1280x720, sizes × 2/3).
for (const [res, expect] of [["fhd", "space=1920x1080 card=720 font=48"], ["hd,fhd", "space=1280x720 card=480 font=32"]]) {
  const dir = join(root, "build", "example-" + res.replace(",", "-"));
  rmSync(dir, { recursive: true, force: true });
  cpSync(join(root, "examples", "hello"), dir, { recursive: true });
  cpSync(join(root, "source"), join(dir, "source"), { recursive: true });
  writeFileSync(join(dir, "manifest"), readFileSync(join(dir, "manifest"), "utf8").replace(/ui_resolutions=.*/, "ui_resolutions=" + res));
  const z = dir + ".zip";
  rmSync(z, { force: true });
  execFileSync("zip", ["-qr", z, "."], { cwd: dir });
  let o = "";
  try { o = execFileSync(cli, [z], { encoding: "utf8", stdio: ["ignore", "pipe", "pipe"], timeout: 120000 }); }
  catch (e) { o = (e.stdout || "") + (e.stderr || ""); }
  const line = clean(o).split("\n").find((l) => l.startsWith("HELLO READY")) || "(no output)";
  const pass = line.includes(expect);
  console.log(`example ui_resolutions=${res}: ${line} ${pass ? "OK" : "FAIL (want " + expect + ")"}`);
  ok = ok && pass;
}
process.exit(ok ? 0 : 1);
