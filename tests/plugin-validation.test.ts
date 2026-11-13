import assert from "node:assert/strict";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test, { type TestContext } from "node:test";
import { validatePlugin } from "../scripts/validate-plugin.ts";

function fixture(t: TestContext) {
    const root = mkdtempSync(join(tmpdir(), "pomodoro-manifest-"));
    t.after(() => rmSync(root, { recursive: true, force: true }));
    const manifest = JSON.parse(readFileSync(new URL("../plugin.json", import.meta.url), "utf8"));
    for (const file of ["package.json", "README.md", "LICENSE"])
        writeFileSync(join(root, file), readFileSync(new URL("../" + file, import.meta.url)));
    for (const file of [manifest.component, manifest.settings])
        writeFileSync(join(root, file), "import QtQuick\nItem {}\n");
    const save = () => writeFileSync(join(root, "plugin.json"), JSON.stringify(manifest));
    save();
    return { root, manifest, save };
}

test("plugin validation accepts the runtime manifest without npm dependencies", t => {
    validatePlugin(fixture(t).root);
});

test("plugin validation rejects incompatible IDs, missing permissions and version drift", t => {
    const { root, manifest, save } = fixture(t);
    const original = structuredClone(manifest);
    manifest.id = "invalid-plugin";
    save();
    assert.throws(() => validatePlugin(root), /camelCase/);
    Object.assign(manifest, original, { permissions: ["settings_read", "settings_write"] });
    save();
    assert.throws(() => validatePlugin(root), /Missing permission: process/);
    Object.assign(manifest, original, { version: "99.0.0" });
    save();
    assert.throws(() => validatePlugin(root), /versions differ/);
});

test("plugin entry points must exist inside the distributable directory", t => {
    const { root, manifest, save } = fixture(t);
    manifest.component = "../outside.qml";
    save();
    assert.throws(() => validatePlugin(root), /inside the plugin/);
    manifest.component = "missing.qml";
    save();
    assert.throws(() => validatePlugin(root), /ENOENT/);
});

test("plugin dependencies prefer documented DMS replacements", t => {
    const { root, manifest, save } = fixture(t);
    manifest.dependencies = ["libnotify"];
    save();
    assert.throws(() => validatePlugin(root), /Use dms notify instead of libnotify/);
    manifest.dependencies = [];
    save();
    validatePlugin(root);
});
