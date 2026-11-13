import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { readFileSync, readdirSync } from "node:fs";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("../", import.meta.url));
const archive = "dist/DankPomodoroTimerPlusPlus.tar.gz";
const expected = new Set([
    "plugin.json", "Pomodoro.js", "README.md", "LICENSE",
    ...readdirSync(root).filter(name => name.endsWith(".qml")),
    ...readdirSync(new URL("../translations/", import.meta.url)).map(name => "translations/" + name)
]);
const members = execFileSync("tar", ["-tzf", archive], { cwd: root, encoding: "utf8" })
    .trim().split("\n").filter(name => !name.endsWith("/"));
assert.equal(members.length, expected.size, "Archive has missing, duplicate or unexpected files");
for (const member of members) {
    assert.ok(expected.has(member), "Unexpected archive member: " + member);
    const bytes = execFileSync("tar", ["-xOf", archive, member], { cwd: root });
    assert.deepEqual(bytes, readFileSync(new URL("../" + member, import.meta.url)), "Outdated archive member: " + member);
    expected.delete(member);
}
assert.equal(expected.size, 0, "Missing archive members: " + [...expected].join(", "));
console.log("Archive contains every runtime file and matches the current sources.");
