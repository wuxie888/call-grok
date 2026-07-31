#!/usr/bin/env node

let input = "";
for await (const chunk of process.stdin) {
  input += chunk;
}

function jsonObjects(text) {
  const values = [];

  for (let start = 0; start < text.length; start += 1) {
    if (text[start] !== "{") continue;

    let depth = 0;
    let quoted = false;
    let escaped = false;

    for (let index = start; index < text.length; index += 1) {
      const character = text[index];

      if (quoted) {
        if (escaped) {
          escaped = false;
        } else if (character === "\\") {
          escaped = true;
        } else if (character === '"') {
          quoted = false;
        }
        continue;
      }

      if (character === '"') {
        quoted = true;
      } else if (character === "{") {
        depth += 1;
      } else if (character === "}") {
        depth -= 1;
        if (depth === 0) {
          const candidate = text.slice(start, index + 1);
          try {
            values.push(JSON.parse(candidate));
            start = index;
          } catch {
            // Keep scanning for the next balanced object.
          }
          break;
        }
      }
    }
  }

  return values;
}

function isIntelResult(value) {
  return (
    value &&
    typeof value === "object" &&
    typeof value.status === "string" &&
    typeof value.x_search_used === "boolean" &&
    Array.isArray(value.items) &&
    Array.isArray(value.gaps)
  );
}

let envelope;
try {
  envelope = JSON.parse(input);
} catch {
  envelope = null;
}

let result = null;

if (isIntelResult(envelope)) {
  result = envelope;
} else if (isIntelResult(envelope?.structuredOutput)) {
  result = envelope.structuredOutput;
} else {
  const text = typeof envelope?.text === "string" ? envelope.text : input;
  result = jsonObjects(text).filter(isIntelResult).at(-1) ?? null;
}

if (!result) {
  process.stderr.write(
    "Could not extract a final grok-x JSON result. Raw CLI output follows:\n",
  );
  process.stderr.write(input);
  process.exit(1);
}

const postUrl = /^https:\/\/(?:www\.)?x\.com\/[^/]+\/status\/\d+(?:[/?#].*)?$/;
const invalidUrls = result.items
  .map((item) => item?.url)
  .filter((url) => typeof url !== "string" || !postUrl.test(url));

if (invalidUrls.length > 0) {
  result.status = result.status === "failed" ? "failed" : "partial";
  result.gaps.push(
    `${invalidUrls.length} returned item(s) lacked a valid X status URL and require rejection or repair.`,
  );
}

if (!result.x_search_used && result.items.length > 0) {
  result.status = "failed";
  result.gaps.push(
    "Post-like items were returned without native X search; treat them as untrusted.",
  );
  result.items = [];
}

result._run = {
  model: Object.keys(envelope?.modelUsage ?? {})[0] ?? null,
  turns: envelope?.num_turns ?? null,
  cost_usd: envelope?.total_cost_usd ?? null,
  structured_output_error: envelope?.structuredOutputError ?? null,
  structured_output_recovered:
    !isIntelResult(envelope?.structuredOutput) &&
    typeof envelope?.structuredOutputError === "string",
};

process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
