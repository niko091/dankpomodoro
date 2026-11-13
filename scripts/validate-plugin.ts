import assert from "node:assert/strict";
import { readFileSync, statSync } from "node:fs";
import { dirname, isAbsolute, relative, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

export function validatePlugin(root: string): void {
    const read = (file: string) => readFileSync(resolve(root, file), "utf8");
    const manifest = JSON.parse(read("plugin.json"));
    for (const field of ["id", "name", "description", "version", "author", "type", "component", "settings", "license", "requires_dms"]) {
        assert.equal(typeof manifest[field], "string", "Missing manifest field: " + field);
        assert.ok(manifest[field].trim(), "Empty manifest field: " + field);
    }
    assert.match(manifest.id, /^[a-z][a-zA-Z0-9]*$/, "Plugin ID must be camelCase");
    assert.equal(manifest.type, "widget");
    assert.match(manifest.version, /^\d+\.\d+\.\d+$/, "Version must be X.Y.Z");
    assert.equal(manifest.version, JSON.parse(read("package.json")).version, "Package and manifest versions differ");
    assert.match(manifest.requires_dms, /^>=\d+\.\d+\.\d+$/);
    for (const field of ["component", "settings"]) {
        const path = relative(root, resolve(root, manifest[field]));
        assert.ok(path && !path.startsWith("..") && !isAbsolute(path), field + " must stay inside the plugin");
        assert.ok(statSync(resolve(root, path)).isFile(), field + " must reference a file");
    }
    assert.ok(Array.isArray(manifest.permissions), "Permissions must be an array");
    const allowed = new Set(["settings_read", "settings_write", "process", "network"]);
    for (const permission of manifest.permissions)
        assert.ok(allowed.has(permission), "Unknown permission: " + permission);
    for (const permission of ["settings_read", "settings_write", "process"])
        assert.ok(manifest.permissions.includes(permission), "Missing permission: " + permission);
    const dependencies = manifest.dependencies ?? [];
    assert.ok(Array.isArray(dependencies), "Dependencies must be an array");
    const alternatives = new Map([
        ["libnotify", "dms notify"], ["notify-send", "dms notify"],
        ["wl-clipboard", "dms cl"], ["xclip", "dms cl"],
        ["grim", "dms screenshot"], ["slurp", "dms screenshot"],
        ["grimblast", "dms screenshot"], ["flameshot", "dms screenshot"],
        ["qrencode", "dms qr"], ["trash-cli", "dms trash"],
        ["brightnessctl", "dms brightness"], ["wlr-randr", "dms randr"], ["xrandr", "dms randr"]
    ]);
    for (const dependency of dependencies) {
        assert.equal(typeof dependency, "string");
        assert.ok(!alternatives.has(dependency), "Use " + alternatives.get(dependency) + " instead of " + dependency);
    }
    assert.ok(read("README.md").trim().length > 100, "Document installation and usage");
    assert.ok(read("LICENSE").trim().length > 0, "License file is missing");
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
    validatePlugin(resolve(dirname(fileURLToPath(import.meta.url)), ".."));
    console.log("Plugin manifest, entry points, dependencies and documentation are valid.");
}
