# Python Notes — Stage 5 (AI App)

---

## Theory: What Are We Building?

A small Python web server that:
1. Listens for HTTP POST requests on a URL (`/chat`)
2. Takes a prompt (a question) from the request body
3. Sends it to Azure OpenAI
4. Returns the AI response as JSON

```
You (browser/terminal)
        ↓  POST /chat  {"prompt": "what is azure?"}
    Python app (Flask)
        ↓
    Azure OpenAI (gpt-4.1-mini in swedencentral)
        ↓
    {"response": "Azure is Microsoft's cloud platform..."}
```

**Why Flask?** — Flask is a Python library that lets you create a web server and define URLs (called routes) in just a few lines. No complex setup needed.

**Why the OpenAI SDK?** — Instead of writing raw HTTP requests to the Azure OpenAI API yourself, the SDK gives you a simple Python function that handles it.

**Why `.env`?** — Secrets (API key, endpoint) should never be hardcoded in code. The `.env` file stores them locally, and `python-dotenv` reads them into environment variables at startup. `.env` is already in `.gitignore` so it never gets committed.

---

## App File: `App/main.py`

### Block 1 — Imports

```python
from flask import Flask, request, jsonify
from openai import AzureOpenAI
from dotenv import load_dotenv
import os
```

| Import | What it does |
|---|---|
| `Flask` | Creates the web server |
| `request` | Reads data from the incoming HTTP request |
| `jsonify` | Converts a Python dict into a proper JSON HTTP response |
| `AzureOpenAI` | The SDK client — handles all communication with Azure OpenAI |
| `load_dotenv` | Reads the `.env` file and loads values into environment variables |
| `os` | Standard Python library — used here to read env vars with `os.getenv()` |

> `AzureOpenAI` is different from the standard `OpenAI` client — it takes an `azure_endpoint` and an `api_version`, which are Azure-specific requirements.

---

### Block 2 — Load `.env` and create the Flask app

```python
load_dotenv()

app = Flask(__name__)
```

- `load_dotenv()` — reads `App/.env` and makes the three values available as environment variables
- `app = Flask(__name__)` — creates the web server instance. `__name__` is a Python built-in for the current file's name — Flask uses it internally to know where to look for things

---

### Block 3 — Create the Azure OpenAI client

```python
client = AzureOpenAI(
    api_key=os.getenv("AZURE_OPENAI_KEY"),
    api_version="2024-12-01-preview",
    azure_endpoint=os.getenv("AZURE_OPENAI_ENDPOINT")
)
```

- `AzureOpenAI(...)` — creates the client that handles all communication with your Azure OpenAI resource
- `os.getenv("AZURE_OPENAI_KEY")` — reads the key from `.env` at runtime, never hardcoded
- `api_version` — Azure OpenAI requires you to specify which version of the API you're calling. `2024-12-01-preview` is the latest stable one
- `azure_endpoint` — reads your endpoint URL from `.env`

This client is created once at startup and reused for every request.

---

### Block 4 — The route (the endpoint)

```python
@app.route("/chat", methods=["POST"])
def chat():
    data = request.get_json()
    prompt = data.get("prompt")

    response = client.chat.completions.create(
        model=os.getenv("AZURE_OPENAI_DEPLOYMENT"),
        messages=[{"role": "user", "content": prompt}]
    )

    return jsonify({"response": response.choices[0].message.content})
```

- `@app.route("/chat", methods=["POST"])` — a decorator. Tells Flask: when a POST request hits `/chat`, run the function below it
- `def chat():` — the function that handles that request
- `request.get_json()` — reads the JSON body from the incoming request (e.g. `{"prompt": "what is azure?"}`)
- `data.get("prompt")` — pulls the `prompt` value out of that JSON
- `client.chat.completions.create(...)` — sends the prompt to Azure OpenAI and waits for a response
- `model=os.getenv("AZURE_OPENAI_DEPLOYMENT")` — reads `gpt-4-1-mini` from `.env`. This is your deployment name, not an Azure built-in — Azure matches it to the deployment you created via Terraform
- `messages=[{"role": "user", "content": prompt}]` — chat models expect a list of messages with a role and content. Role can be `user`, `assistant`, or `system`
- `response.choices[0].message.content` — digs into the response object to extract the actual text the model returned
- `jsonify(...)` — wraps the result in a proper JSON HTTP response

---

### Block 5 — Run the server

```python
if __name__ == "__main__":
    app.run(debug=True)
```

- `if __name__ == "__main__":` — Python only runs this block when you execute the file directly (`python main.py`). If the file is imported by another file, this block is skipped
- `app.run(debug=True)` — starts the Flask web server on `http://localhost:5000`
- `debug=True` — shows full error messages in the terminal if something breaks. Never use this in production

---

## Running the App

### Start the Flask server

```bash
cd /Users/rezanazari/Desktop/AZ-Learning/App
python main.py
```

You should see:
```
 * Serving Flask app 'main'
 * Debug mode: on
 * Running on http://127.0.0.1:5000
```

Flask is now listening on port 5000 on your local machine. Keep this terminal open — the server runs in the foreground.

### Test it with curl

Open a second terminal tab and run:

```bash
curl -X POST http://127.0.0.1:5000/chat \
  -H "Content-Type: application/json" \
  -d '{"prompt": "what is azure in one sentence"}'
```

- `-X POST` — send a POST request
- `-H "Content-Type: application/json"` — tell the server the body is JSON
- `-d '{"prompt": "..."}'` — the request body with your prompt

Expected response:
```json
{
  "response": "Azure is Microsoft's cloud computing platform..."
}
```

### What happens end to end

1. `curl` sends POST to `http://127.0.0.1:5000/chat`
2. Flask receives it → `chat()` function runs
3. `request.get_json()` reads `{"prompt": "what is azure in one sentence"}`
4. `data.get("prompt")` pulls out the prompt string
5. SDK sends it to Azure OpenAI (`gpt-4.1-mini` in swedencentral)
6. Azure returns the completion
7. `jsonify(...)` wraps the text in JSON and Flask sends it back

### Common issues

| Error | Cause | Fix |
|---|---|---|
| 401 AuthenticationError | Wrong or stale API key in `.env` | Get fresh key: `az cognitiveservices account keys list --name oai-dev-rn001 --resource-group rg-tfexample-dev-rn --query key1 -o tsv` |
| 401 still after key update | Flask loaded old key at startup | Restart Flask: CTRL+C → `python main.py` |
| ResourceGroupNotFound | Infra was deleted, not recreated | Run `terraform apply -var-file="dev.tfvars" -auto-approve` first |

---

## Step 4: Read API Key from Key Vault

### Why?

Storing the API key in `.env` is fine for local learning but bad practice. In real systems secrets live in Key Vault and the app fetches them at runtime. That way the secret is never in a file, never committed, and access is controlled by Azure RBAC.

### How it works locally

The app uses `DefaultAzureCredential` — an Azure SDK class that automatically tries several authentication methods in order. When running locally, it picks up your Azure CLI login. So the app authenticates to Azure as you, and reads the secret from Key Vault.

```
main.py starts
    ↓
DefaultAzureCredential → uses your az login session
    ↓
SecretClient.get_secret("openai-key") → Key Vault
    ↓
Returns the actual API key value
    ↓
AzureOpenAI client initialized with the key
```

### New packages needed

```bash
pip install azure-identity azure-keyvault-secrets
```

- `azure-identity` — provides `DefaultAzureCredential`
- `azure-keyvault-secrets` — provides `SecretClient` to read secrets from Key Vault

### What goes in Key Vault vs `.env`

**Rule: a secret is something that grants access. If someone has it, they can do damage.**

| Value | Where it lives | Why |
|---|---|---|
| API key | Key Vault | Grants access to a paid service |
| Database connection string | Key Vault | Contains username + password |
| Storage account access key | Key Vault | Full read/write access to storage |
| Service principal secret | Key Vault | Used by apps/pipelines to authenticate to Azure |
| JWT signing key | Key Vault | Used to sign/verify tokens |
| TLS/SSL certificate | Key Vault | Used for HTTPS |
| Endpoint URL | `.env` or config | Just an address, useless without a key |
| Resource names, deployment names | `.env` or config | Not sensitive |
| Region, feature flags, timeouts | `.env` or config | Not sensitive |

**As an Azure admin**, Key Vault also stores:
- Service principal secrets for CI/CD pipelines (ADO service connections)
- Database admin passwords
- Certificates for apps in Entra ID
- Encryption keys for storage/disk encryption
- Credentials for on-premises systems integrating with Azure

---

### RBAC role needed

Key Vault has RBAC enabled (`rbac_authorization_enabled = true` in Terraform). To read secrets, your identity needs the **Key Vault Secrets User** role on the Key Vault. To also store secrets via CLI, you need **Key Vault Secrets Officer**.

Assign yourself the role:
```bash
az role assignment create \
  --role "Key Vault Secrets Officer" \
  --assignee <your-object-id> \
  --scope /subscriptions/<sub-id>/resourcegroups/<rg>/providers/microsoft.keyvault/vaults/<kv-name>
```

Get your object ID: `az ad signed-in-user show --query id -o tsv`  
Check your roles: `az role assignment list --assignee <your-object-id> --output table`

### Store the secret via CLI

```bash
az keyvault secret set \
  --vault-name kv-tfexample001 \
  --name openai-key \
  --value "<your-api-key>"
```

### Add KEY_VAULT_URL to `.env`

```
KEY_VAULT_URL=https://kv-tfexample001.vault.azure.net/
```

The Key Vault URL format is always: `https://<vault-name>.vault.azure.net/`

### Updated `main.py` — Block 1 (new imports)

```python
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient
```

### Updated `main.py` — Block 3 (Key Vault client replaces .env key)

```python
credential = DefaultAzureCredential()
kv_client = SecretClient(
    vault_url=os.getenv("KEY_VAULT_URL"),
    credential=credential
)

api_key = kv_client.get_secret("openai-key").value

client = AzureOpenAI(
    api_key=api_key,
    api_version="2024-12-01-preview",
    azure_endpoint=os.getenv("AZURE_OPENAI_ENDPOINT")
)
```

**What changed vs the old block:**

| Old | New |
|---|---|
| `api_key=os.getenv("AZURE_OPENAI_KEY")` | Key fetched from Key Vault at startup |
| No Azure authentication needed | `DefaultAzureCredential()` uses your `az login` session |
| Secret lived in `.env` file | Secret lives in Key Vault, `.env` only holds the vault URL |

- `DefaultAzureCredential()` — tries several auth methods in order; locally it picks up your `az login` session automatically
- `SecretClient(vault_url=..., credential=...)` — creates the Key Vault SDK client
- `.get_secret("openai-key").value` — fetches the secret by name; `.value` extracts the plain string from the response object
- The `AzureOpenAI` client is identical to before — it still just receives an API key string, it doesn't know or care where it came from

---
