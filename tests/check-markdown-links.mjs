#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const markdownFiles = [];

function collect(directory) {
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    if (entry.name === ".git") continue;
    const target = path.join(directory, entry.name);
    if (entry.isDirectory()) collect(target);
    if (entry.isFile() && entry.name.endsWith(".md")) markdownFiles.push(target);
  }
}

collect(root);

const problems = [];
const patterns = [
  /!?(?:\[[^\]]*\])\(([^)]+)\)/g,
  /<(?:a|img)\s+[^>]*(?:href|src)="([^"]+)"[^>]*>/g,
];

for (const markdownFile of markdownFiles) {
  const text = fs.readFileSync(markdownFile, "utf8");
  for (const pattern of patterns) {
    for (const match of text.matchAll(pattern)) {
      let reference = match[1].trim();
      if (
        reference.startsWith("http://") ||
        reference.startsWith("https://") ||
        reference.startsWith("mailto:") ||
        reference.startsWith("#")
      ) {
        continue;
      }
      reference = reference.split("#", 1)[0];
      if (reference.startsWith("<") && reference.endsWith(">")) {
        reference = reference.slice(1, -1);
      }
      const resolved = path.resolve(path.dirname(markdownFile), decodeURI(reference));
      if (!resolved.startsWith(`${root}${path.sep}`) && resolved !== root) {
        problems.push(`${path.relative(root, markdownFile)} escapes repository: ${reference}`);
      } else if (!fs.existsSync(resolved)) {
        problems.push(`${path.relative(root, markdownFile)} missing target: ${reference}`);
      }
    }
  }
}

if (problems.length > 0) {
  process.stderr.write(`${problems.join("\n")}\n`);
  process.exit(1);
}

process.stdout.write(`Checked ${markdownFiles.length} Markdown files\n`);
