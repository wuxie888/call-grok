#!/usr/bin/env node

import fs from "node:fs";

const result = JSON.parse(fs.readFileSync(0, "utf8"));

if (result.status !== "success") {
  throw new Error(`expected success, received ${result.status}`);
}
if (result.x_search_used !== true || result.items.length !== 1) {
  throw new Error("expected one native-X evidence item");
}
if (result._run?.structured_output_recovered !== true) {
  throw new Error("expected the fallback extractor to report recovery");
}
if (result._run?.model !== "grok-test" || result._run?.turns !== 2) {
  throw new Error("expected run metadata to be preserved");
}
