
import axios from "axios";

const DEFAULT_OPENAI_BASE = "https://api.openai.com/v1";
const DEFAULT_HERMES_BASE = "http://127.0.0.1:8642/v1";

export function resolveBaseUrl() {
    const provider = (process.env.LLM_PROVIDER || "").trim().toLowerCase();
    const explicit = (process.env.OPENAI_BASE_URL || "").trim();
    if (explicit) {
        return explicit.replace(/\/+$/, "");
    }
    if (provider === "hermes") {
        return DEFAULT_HERMES_BASE;
    }
    return DEFAULT_OPENAI_BASE;
}

export function resolveModel() {
    if (process.env.OPENAI_MODEL) {
        return process.env.OPENAI_MODEL;
    }
    return isLocalHermes() ? "hermes-agent" : "gpt-3.5-turbo";
}

export function isLocalHermes() {
    const provider = (process.env.LLM_PROVIDER || "").trim().toLowerCase();
    if (provider === "hermes") {
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
                        Authorization: `Bearer ${process.env.OPENAI_API_KEY}`
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
