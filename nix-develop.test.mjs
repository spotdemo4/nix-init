import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import test from "node:test";
import { fileURLToPath } from "node:url";

import {
  buildFileCommands,
  EnvironmentCollector,
  extractEnvironment,
  writeAll,
} from "./nix-develop.mjs";

test("extracts hook output and NUL-delimited environment", () => {
  const marker = "marker";
  const output = Buffer.concat([
    Buffer.from("hook output\0is preserved\nmarker"),
    Buffer.from(`\0PATH=/nix/a:/usr/bin\0EMPTY=\0EQUALS=a=b\0`),
  ]);

  const result = extractEnvironment(output, marker);

  assert.equal(result.shellOutput.toString(), "hook output\0is preserved\n");
  assert.deepEqual(Object.fromEntries(result.environment), {
    EMPTY: "",
    EQUALS: "a=b",
    PATH: "/nix/a:/usr/bin",
  });
});

test("rejects missing and incomplete environment fences", () => {
  assert.throws(
    () => extractEnvironment(Buffer.from("hook output"), "marker"),
    /did not produce an environment/,
  );
  assert.throws(
    () => extractEnvironment(Buffer.from("marker\0NAME=value"), "marker"),
    /incomplete environment/,
  );
});

test("streams hook output while retaining partial fences", () => {
  const shellOutput = [];
  const collector = new EnvironmentCollector("marker", (chunk) =>
    shellOutput.push(chunk),
  );

  collector.push(Buffer.from("hook output\nmar"));
  collector.push(Buffer.from("ker\0NAME=value\0"));

  assert.equal(Buffer.concat(shellOutput).toString(), "hook output\n");
  assert.deepEqual(Object.fromEntries(collector.finish()), { NAME: "value" });
});

test("dumps the current process environment", () => {
  const result = spawnSync(
    process.execPath,
    [
      fileURLToPath(new URL("nix-develop.mjs", import.meta.url)),
      "--dump-environment",
      "marker",
    ],
    {
      env: { EMPTY: "", EQUALS: "a=b" },
    },
  );

  assert.equal(result.status, 0);
  const environment = extractEnvironment(result.stdout, "marker").environment;
  assert.equal(environment.get("EMPTY"), "");
  assert.equal(environment.get("EQUALS"), "a=b");
});

test("retries partial environment writes", () => {
  const chunks = [];
  writeAll(1, "environment", (_fileDescriptor, buffer, offset, length) => {
    const written = Math.min(3, length);
    chunks.push(buffer.subarray(offset, offset + written));
    return written;
  });

  assert.equal(Buffer.concat(chunks).toString(), "environment");
});

test("builds ordered PATH and environment file commands", () => {
  const environment = new Map([
    ["PATH", "/nix/first:/nix/second:/usr/bin:/nix/first:/missing"],
    ["UNCHANGED", "same"],
    ["EMPTY", ""],
    ["MULTILINE", "first\nsecond"],
    ["INVALID-NAME", "ignored"],
  ]);
  const commands = buildFileCommands(
    environment,
    { PATH: "/usr/bin", UNCHANGED: "same" },
    {
      isDirectory: (path) => path.startsWith("/nix/"),
      pathDelimiter: ":",
      uuid: () => "uuid",
    },
  );

  assert.equal(commands.pathFile, "/nix/second\n/nix/first\n");
  assert.equal(
    commands.environmentFile,
    "EMPTY=\nMULTILINE<<nix_develop_uuid\nfirst\nsecond\nnix_develop_uuid\n",
  );
});

test("avoids multiline delimiter collisions", () => {
  const identifiers = ["collision", "safe"];
  const commands = buildFileCommands(
    new Map([["VALUE", "nix_develop_collision\n"]]),
    {},
    {
      uuid: () => identifiers.shift(),
    },
  );

  assert.equal(
    commands.environmentFile,
    "VALUE<<nix_develop_safe\nnix_develop_collision\n\nnix_develop_safe\n",
  );
});
