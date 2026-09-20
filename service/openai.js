
import axios from "axios";

const DEFAULT_OPENAI_BASE = "https://api.openai.com/v1";
const DEFAULT_HERMES_BASE = "http://127.0.0.1:8642/v1";
const DEFAULT_DEEPSEEK_BASE = "https://api.deepseek.com";

function providerName() {
    return (process.env.LLM_PROVIDER || "").trim().toLowerCase();
}

export function resolveBaseUrl() {
    const explicit = (process.env.OPENAI_BASE_URL || "").trim();
    if (explicit) {
        return explicit.replace(/\/+$/, "");
    }
    if (providerName() === "hermes") {
        return DEFAULT_HERMES_BASE;
    }
    if (providerName() === "deepseek") {
        return DEFAULT_DEEPSEEK_BASE;
    }
    return DEFAULT_OPENAI_BASE;
}

export function isDeepseek() {
    if (providerName() === "deepseek") {
        return true;
    }
    const base = resolveBaseUrl();
    const model = (process.env.OPENAI_MODEL || "").toLowerCase();
    return /deepseek/i.test(base) || model.startsWith("deepseek");
}

export function resolveModel() {
    if (process.env.OPENAI_MODEL) {
        return process.env.OPENAI_MODEL;
    }
    if (isLocalHermes()) {
        return "hermes-agent";
    }
    if (isDeepseek()) {
        return "deepseek-flash";
    }
    return "gpt-3.5-turbo";
}

export function resolveApiKey() {
    if (isDeepseek()) {
        return process.env.DEEPSEEK_API_KEY || process.env.OPENAI_API_KEY;
    }
    if (isLocalHermes()) {
        return process.env.OPENAI_API_KEY || process.env.API_SERVER_KEY;
    }
    return process.env.OPENAI_API_KEY;
}

export function isLocalHermes() {
    if (providerName() === "hermes") {
        return true;
    }
    const base = resolveBaseUrl();
    return /:8642\b|hermes-agent|\/hermes/i.test(base);
}

export function resolveChatCompletionsUrl() {
    return `${resolveBaseUrl()}/chat/completions`;
}

function requestTimeoutMs() {
    if (process.env.OPENAI_TIMEOUT_MS) {
        return Number(process.env.OPENAI_TIMEOUT_MS);
    }
    return isLocalHermes() ? 180000 : 60000;
}

export class OpenAI {
    async ctChat(context) {
        try {
            const res = await axios.post(
                resolveChatCompletionsUrl(),
                {
                    model: resolveModel(),
                    messages: context
                },
                {
                    headers: {
                        Accept: "application/json",
                        "Content-Type": "application/json",
                        Authorization: `Bearer ${resolveApiKey()}`
                    },
                    timeout: requestTimeoutMs()
                }
            );
            return res;
        } catch (error) {
            console.log("LLM request failed");
            console.log(error?.response?.data || error.message);
        }
    }

    async ctText(question) {
        return this.ctChat([{ role: "user", content: question }]);
    }

    static create() {
    }

    static ctImage() {
    }

    static ctVoice() {
    }
}
