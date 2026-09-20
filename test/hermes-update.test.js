import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import http from "node:http";
import { createRequire } from "node:module";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

const require = createRequire(import.meta.url);
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

async function loadClient(env) {
    for (const key of [
        "LLM_PROVIDER",
        "OPENAI_BASE_URL",
        "OPENAI_MODEL",
        "OPENAI_API_KEY",
        "OPENAI_TIMEOUT_MS"
    ]) {
        if (env[key] === undefined) {
            delete process.env[key];
        } else {
            process.env[key] = env[key];
        }
    }
    return import(`../service/openai.js?case=${Date.now()}-${Math.random()}`);
}

test("hermes provider points at local gateway", async () => {
    const client = await loadClient({ LLM_PROVIDER: "hermes" });
    assert.equal(client.resolveBaseUrl(), "http://127.0.0.1:8642/v1");
    assert.equal(client.resolveModel(), "hermes-agent");
    assert.equal(client.isLocalHermes(), true);
    assert.equal(client.resolveChatCompletionsUrl(), "http://127.0.0.1:8642/v1/chat/completions");
});

test("explicit OpenAI base URL is preserved", async () => {
    const client = await loadClient({
        OPENAI_BASE_URL: "https://api.openai.com/v1/",
        OPENAI_MODEL: "gpt-4"
    });
    assert.equal(client.resolveBaseUrl(), "https://api.openai.com/v1");
    assert.equal(client.resolveModel(), "gpt-4");
    assert.equal(client.isLocalHermes(), false);
});

test("chat completion posts OpenAI-compatible payload to local Hermes", async () => {
    const received = [];
    const server = http.createServer((req, res) => {
        let body = "";
        req.on("data", (chunk) => { body += chunk; });
        req.on("end", () => {
            received.push({
                url: req.url,
                auth: req.headers.authorization,
                body: JSON.parse(body)
            });
            res.writeHead(200, { "Content-Type": "application/json" });
            res.end(JSON.stringify({
                choices: [{ message: { role: "assistant", content: "pong from hermes" } }]
            }));
        });
    });

    await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
    const { port } = server.address();
    const client = await loadClient({
        LLM_PROVIDER: "hermes",
        OPENAI_BASE_URL: `http://127.0.0.1:${port}/v1`,
        OPENAI_API_KEY: "change-me-local-dev",
        OPENAI_MODEL: "hermes-agent"
    });
    const openai = new client.OpenAI();
    const result = await openai.ctChat([{ role: "user", content: "ping" }]);
    server.close();

    assert.equal(received.length, 1);
    assert.equal(received[0].url, "/v1/chat/completions");
    assert.equal(received[0].auth, "Bearer change-me-local-dev");
    assert.deepEqual(received[0].body, {
        model: "hermes-agent",
        messages: [{ role: "user", content: "ping" }]
    });
    assert.equal(result.data.choices[0].message.content, "pong from hermes");
});

test("update script --check reports latest GitHub tag", async () => {
    const latest = require("child_process")
        .execFileSync("bash", [path.join(root, "scripts/hermes-version.sh")], { encoding: "utf8" })
        .trim();
    assert.match(latest, /^v\d{4}\.\d{1,2}\.\d{1,2}$/);

    const output = await new Promise((resolve, reject) => {
        const child = spawn("bash", [path.join(root, "scripts/update-hermes.sh"), "--check"], {
            cwd: root
        });
        let stdout = "";
        let stderr = "";
        child.stdout.on("data", (chunk) => { stdout += chunk; });
        child.stderr.on("data", (chunk) => { stderr += chunk; });
        child.on("close", (code) => {
            if (code !== 0) {
                reject(new Error(`update --check failed (${code}): ${stderr}`));
                return;
            }
            resolve(stdout);
        });
    });

    assert.match(output, /Latest Hermes Agent release: v\d{4}\./);
    assert.match(output, new RegExp(latest));
});
