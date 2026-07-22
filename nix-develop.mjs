#!/usr/bin/env node

import { spawn } from "node:child_process";
import { randomUUID } from "node:crypto";
import { appendFileSync, statSync, writeSync } from "node:fs";
import { delimiter as pathDelimiter } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const maxEnvironmentBytes = 64 * 1024 * 1024;
const signalExitCodes = { SIGINT: 130, SIGTERM: 143 };
const variableName = /^[a-zA-Z_][a-zA-Z0-9_]*$/;

export class EnvironmentCollector {
  constructor(
    marker,
    writeShellOutput = (chunk) => process.stdout.write(chunk),
  ) {
    this.environment = new Map();
    this.environmentBytes = 0;
    this.fence = Buffer.from(`${marker}\0`);
    this.foundFence = false;
    this.pending = Buffer.alloc(0);
    this.writeShellOutput = writeShellOutput;
  }

  push(chunk) {
    this.pending = Buffer.concat([this.pending, chunk]);
    if (!this.foundFence) {
      const fenceIndex = this.pending.indexOf(this.fence);
      if (fenceIndex === -1) {
        const flushLength = Math.max(
          0,
          this.pending.length - this.fence.length + 1,
        );
        if (flushLength > 0) {
          this.writeShellOutput(this.pending.subarray(0, flushLength));
          this.pending = this.pending.subarray(flushLength);
        }
        return;
      }

      this.writeShellOutput(this.pending.subarray(0, fenceIndex));
      this.pending = this.pending.subarray(fenceIndex + this.fence.length);
      this.foundFence = true;
    }

    let end;
    while ((end = this.pending.indexOf(0)) !== -1) {
      const record = this.pending.subarray(0, end);
      this.environmentBytes += record.length + 1;
      if (this.environmentBytes > maxEnvironmentBytes) {
        throw new Error("nix develop environment exceeds 64 MiB");
      }

      const separator = record.indexOf(61);
      if (separator > 0) {
        this.environment.set(
          record.toString("utf8", 0, separator),
          record.toString("utf8", separator + 1),
        );
      }
      this.pending = this.pending.subarray(end + 1);
    }

    if (this.pending.length > maxEnvironmentBytes) {
      throw new Error("nix develop environment record exceeds 64 MiB");
    }
  }

  finish() {
    if (!this.foundFence) {
      this.writeShellOutput(this.pending);
      throw new Error("nix develop did not produce an environment");
    }
    if (this.pending.length !== 0) {
      throw new Error("nix develop produced an incomplete environment");
    }
    return this.environment;
  }
}

export function extractEnvironment(output, marker) {
  const shellOutput = [];
  const collector = new EnvironmentCollector(marker, (chunk) =>
    shellOutput.push(chunk),
  );
  collector.push(output);
  return {
    environment: collector.finish(),
    shellOutput: Buffer.concat(shellOutput),
  };
}

function isDirectory(path) {
  try {
    return statSync(path).isDirectory();
  } catch {
    return false;
  }
}

function multilineEntry(name, value, uuid = randomUUID) {
  let marker;
  do {
    marker = `nix_develop_${uuid()}`;
  } while (value.includes(marker));
  return `${name}<<${marker}\n${value}\n${marker}\n`;
}

export function buildFileCommands(
  environment,
  hostEnvironment = process.env,
  options = {},
) {
  const delimiter = options.pathDelimiter ?? pathDelimiter;
  const directoryExists = options.isDirectory ?? isDirectory;
  const uuid = options.uuid ?? randomUUID;
  const hostPath = new Set((hostEnvironment.PATH ?? "").split(delimiter));
  const environmentEntries = [];
  const pathEntries = [];

  for (const [name, value] of environment) {
    if (name === "PATH") {
      const added = new Set();
      const entries = [];
      for (const entry of value.split(delimiter)) {
        if (
          entry.includes("\n") ||
          entry.includes("\r") ||
          hostPath.has(entry) ||
          added.has(entry) ||
          !directoryExists(entry)
        ) {
          continue;
        }
        added.add(entry);
        entries.push(entry);
      }
      for (const entry of entries.reverse()) {
        pathEntries.push(`${entry}\n`);
      }
      continue;
    }

    if (
      !variableName.test(name) ||
      (Object.hasOwn(hostEnvironment, name) && hostEnvironment[name] === value)
    ) {
      continue;
    }

    environmentEntries.push(
      value.includes("\n")
        ? multilineEntry(name, value, uuid)
        : `${name}=${value}\n`,
    );
  }

  return {
    environmentFile: environmentEntries.join(""),
    pathFile: pathEntries.join(""),
  };
}

export function writeAll(fileDescriptor, value, writer = writeSync) {
  const buffer = Buffer.isBuffer(value) ? value : Buffer.from(value);
  let offset = 0;
  while (offset < buffer.length) {
    const written = writer(
      fileDescriptor,
      buffer,
      offset,
      buffer.length - offset,
      null,
    );
    if (written === 0) {
      throw new Error("unable to write environment");
    }
    offset += written;
  }
}

export function dumpEnvironment(marker) {
  writeAll(1, `${marker}\0`);
  for (const [name, value] of Object.entries(process.env)) {
    writeAll(1, `${name}=${value}\0`);
  }
}

export function runNixDevelop(arguments_, marker, options = {}) {
  return new Promise((resolve, reject) => {
    let child;
    const writeShellOutput =
      options.writeShellOutput ??
      ((chunk) => {
        if (!process.stdout.write(chunk)) {
          child.stdout.pause();
          process.stdout.once("drain", () => child.stdout.resume());
        }
      });
    const collector = new EnvironmentCollector(marker, writeShellOutput);
    const childEnvironment = { ...process.env };
    delete childEnvironment.BASH_ENV;
    child = spawn(
      "nix",
      [
        "develop",
        ...arguments_,
        "--command",
        process.execPath,
        fileURLToPath(import.meta.url),
        "--dump-environment",
        marker,
      ],
      {
        env: childEnvironment,
        stdio: ["inherit", "pipe", "inherit"],
      },
    );
    let streamError;

    const forwardSignal = (signal) => child.kill(signal);
    const onInterrupt = () => forwardSignal("SIGINT");
    const onTerminate = () => forwardSignal("SIGTERM");
    const removeSignalHandlers = () => {
      process.off("SIGINT", onInterrupt);
      process.off("SIGTERM", onTerminate);
    };

    process.once("SIGINT", onInterrupt);
    process.once("SIGTERM", onTerminate);
    child.stdout.on("data", (chunk) => {
      if (streamError) return;
      try {
        collector.push(chunk);
      } catch (error) {
        streamError = error;
        child.kill("SIGTERM");
      }
    });
    child.on("error", (error) => {
      removeSignalHandlers();
      reject(error);
    });
    child.on("close", (code, signal) => {
      removeSignalHandlers();
      let finishError;
      let environment;
      if (!streamError) {
        try {
          environment = collector.finish();
        } catch (error) {
          finishError = error;
        }
      }
      resolve({
        code: code ?? 1,
        environment,
        error: finishError,
        signal,
        streamError,
      });
    });
  });
}

export async function main(arguments_ = process.argv.slice(2)) {
  const nodeMajor = Number.parseInt(process.versions.node, 10);
  if (nodeMajor < 20) {
    throw new Error("Node.js 20 or newer is required");
  }

  const marker = `nix-develop-${randomUUID()}`;
  const result = await runNixDevelop(
    arguments_.length === 0 ? ["./#default"] : arguments_,
    marker,
  );

  if (result.streamError) {
    throw result.streamError;
  }
  if (result.signal) {
    process.exitCode = signalExitCodes[result.signal] ?? 1;
    return;
  }
  if (result.code !== 0) {
    process.exitCode = result.code;
    return;
  }
  if (result.error) {
    throw result.error;
  }

  const commands = buildFileCommands(result.environment);
  if (commands.environmentFile) {
    appendFileSync(
      process.env.GITHUB_ENV ?? "/dev/stderr",
      commands.environmentFile,
    );
  }
  if (commands.pathFile) {
    appendFileSync(process.env.GITHUB_PATH ?? "/dev/stderr", commands.pathFile);
  }
}

if (
  process.argv[1] &&
  import.meta.url === pathToFileURL(process.argv[1]).href
) {
  if (process.argv[2] === "--dump-environment") {
    dumpEnvironment(process.argv[3]);
  } else {
    main().catch((error) => {
      console.error(error instanceof Error ? error.message : error);
      process.exitCode = 1;
    });
  }
}
