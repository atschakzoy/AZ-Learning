# IT Notes 2 — HTTP, APIs, Azure, LLMs, Python

Deep notes on how the internet actually works, how Azure works under the hood, how LLMs work, and how to use Python to talk to all of it.

---

## HTTP — How Computers Talk Over the Internet

HTTP (HyperText Transfer Protocol) is the language computers use to ask each other for things over the internet.

Every time you:
- Open a webpage
- Run `az group list`
- Run `terraform apply`
- Call an AI model

Your computer sends an HTTP request and receives an HTTP response. That's it. Everything else is built on top of this.

### The structure of an HTTP request

An HTTP request has four parts:

```
METHOD /path HTTP/1.1          ← line 1: method and path
Host: api.example.com          ← headers start here
Authorization: Bearer abc123
Content-Type: application/json
                               ← blank line separates headers from body
{"key": "value"}               ← body (only for POST, PUT, PATCH)
```

**Real example — asking Azure for a list of resource groups:**

```
GET /subscriptions/abc-123/resourcegroups?api-version=2021-04-01 HTTP/1.1
Host: management.azure.com
Authorization: Bearer <token>
```

### The four HTTP methods

| Method | What it does | Example |
|--------|-------------|---------|
| `GET` | Read/retrieve something | List resource groups |
| `POST` | Create something or send data | Create a resource group, send a chat message to an LLM |
| `PUT` | Replace/update something | Update a Terraform resource |
| `DELETE` | Delete something | Delete a resource group |

### The structure of an HTTP response

Every request gets a response back. Same structure:

```
HTTP/1.1 200 OK                ← status line
Content-Type: application/json ← headers
                               ← blank line
{"value": [...]}               ← body (the actual data)
```

### HTTP status codes — what the numbers mean

| Code | Meaning | When you see it |
|------|---------|-----------------|
| `200` | OK — success | Everything worked |
| `201` | Created | POST created something |
| `400` | Bad Request | You sent wrong data |
| `401` | Unauthorized | Missing or bad token |
| `403` | Forbidden | Token is valid but no permission |
| `404` | Not Found | That URL doesn't exist |
| `429` | Too Many Requests | Rate limited (common with LLM APIs) |
| `500` | Internal Server Error | The server broke |

**401 vs 403:** 401 means "I don't know who you are". 403 means "I know who you are, but you're not allowed."

### HTTPS

HTTPS is HTTP + encryption. The request and response are the same — they're just encrypted so nobody in between can read them. Every real API uses HTTPS. The `S` stands for Secure.

---

## URLs — Anatomy of Every Web Address

A URL is the full address of an API endpoint. It has distinct parts:

```
https://management.azure.com/subscriptions/abc-123/resourcegroups?api-version=2021-04-01
│       │                    │                                     │
│       │                    │                                     └── query string
│       │                    └── path
│       └── host (domain)
└── protocol (scheme)
```

| Part | Example | What it is |
|------|---------|------------|
| Protocol | `https://` | How to connect (always https for APIs) |
| Host | `management.azure.com` | Which server to talk to |
| Path | `/subscriptions/abc-123/resourcegroups` | Which resource on that server |
| Query string | `?api-version=2021-04-01` | Extra options, filters, parameters |

**Path parameters** are parts of the path that identify a specific thing:
```
/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}
```
You replace the `{...}` placeholders with real values.

**Query parameters** come after `?` and are key=value pairs joined by `&`:
```
?api-version=2021-04-01&$top=10&$filter=location eq 'westeurope'
```

---

## APIs — The Contract

An API (Application Programming Interface) is a published contract that says:
- Here are the URLs you can call
- Here are the methods to use
- Here are the headers you must include
- Here is the format of the body
- Here is what you get back

Think of it as a menu. The API is the menu. Your HTTP request is the order.

### REST APIs

REST is the most common style of API. It means:
- URLs represent resources (things: users, resource groups, models)
- HTTP methods represent actions (GET = read, POST = create, DELETE = remove)
- Data is exchanged in JSON format

Almost everything in Azure, GitHub, OpenAI, and Anthropic uses REST APIs.

### JSON — the data format

APIs talk in JSON. It's just structured text:

```json
{
  "name": "rg-dev",
  "location": "westeurope",
  "tags": {
    "environment": "dev",
    "owner": "reza"
  },
  "properties": {
    "provisioningState": "Succeeded"
  }
}
```

Key rules:
- Keys are always in double quotes
- Values can be: strings, numbers, booleans (`true`/`false`), arrays `[]`, objects `{}`
- No trailing commas
- Everything is case-sensitive

### API authentication

APIs need to know who you are. Three main methods:

**1. API key** — a static secret string
```
api-key: sk-abc123...
```
Simple. Used by OpenAI, Azure Cognitive Services.

**2. Bearer token** — a short-lived token you get by authenticating first
```
Authorization: Bearer eyJhbGci...
```
Used by Azure Resource Manager, Microsoft Graph. The token expires (usually in 1 hour) and you get a new one.

**3. Basic auth** — username:password base64 encoded
```
Authorization: Basic dXNlcjpwYXNz
```
Older style, less common now.

---

## How Azure Works Under the Hood

Azure is not magic. It's a giant REST API called **Azure Resource Manager (ARM)**.

### Azure Resource Manager

Every single thing you do in Azure is an ARM API call:

```
az group create --name rg-dev --location westeurope
```

Azure CLI translates this to:

```
PUT /subscriptions/abc-123/resourceGroups/rg-dev?api-version=2021-04-01 HTTP/1.1
Host: management.azure.com
Authorization: Bearer <token>
Content-Type: application/json

{
  "location": "westeurope"
}
```

Terraform does the same thing. The Azure portal does the same thing. They're all just HTTP clients sending requests to `management.azure.com`.

### How Azure authentication works (the token flow)

To call Azure APIs you need a Bearer token. Here's how you get one:

```
1. You have a service principal (an identity with a client_id and client_secret)
   OR you log in with az login (uses your user identity)

2. You call Microsoft Entra ID (formerly Azure AD):
   POST https://login.microsoftonline.com/{tenant_id}/oauth2/v2.0/token
   Body: grant_type=client_credentials&client_id=...&client_secret=...&scope=https://management.azure.com/.default

3. Entra ID returns a token:
   {"access_token": "eyJhbGci...", "expires_in": 3599}

4. You put that token in every Azure API call:
   Authorization: Bearer eyJhbGci...

5. After ~1 hour the token expires and you repeat from step 2
```

This is called **OAuth 2.0 Client Credentials flow**. Azure SDKs and Terraform handle this automatically. But this is what's happening underneath.

### Azure resource hierarchy

```
Tenant (your organization)
└── Subscription (billing boundary, like an account)
    └── Resource Group (logical container)
        └── Resources (VMs, storage, AI services, etc.)
```

Every ARM URL follows this pattern:
```
/subscriptions/{subId}/resourceGroups/{rgName}/providers/{provider}/{resourceType}/{resourceName}
```

Example:
```
/subscriptions/abc/resourceGroups/rg-dev/providers/Microsoft.CognitiveServices/accounts/my-openai
```

### Azure service endpoints

Different Azure services use different base URLs:

| Service | Base URL |
|---------|----------|
| Azure Resource Manager | `management.azure.com` |
| Azure OpenAI | `{your-endpoint}.openai.azure.com` |
| Microsoft Graph | `graph.microsoft.com` |
| Azure Blob Storage | `{account}.blob.core.windows.net` |
| Azure Key Vault | `{vault}.vault.azure.net` |

### How Terraform talks to Azure

When you run `terraform apply`, Terraform:
1. Reads your `.tf` files
2. Authenticates to Azure (using `ARM_CLIENT_ID`, `ARM_CLIENT_SECRET`, etc.)
3. Gets a token from Entra ID
4. Calls ARM REST API to create/update/delete resources
5. Saves the result in `terraform.tfstate`

Terraform is just a very smart HTTP client that knows the Azure API.

---

## How LLMs Work

LLM stands for Large Language Model. GPT-4o, Claude, Gemini — they're all LLMs.

### What an LLM actually does

An LLM takes text in and produces text out. More precisely:
- It takes a list of messages (conversation history)
- It predicts the next most likely tokens (word pieces)
- It returns the generated text

### Tokens — the unit of text

LLMs don't work with words, they work with **tokens**. A token is roughly:
- 1 short word = 1 token (`cat`, `run`, `the`)
- 1 long word = 2–3 tokens (`understanding` = `under` + `standing`)
- 1 character of code often = 1 token

Why this matters:
- You pay per token (input tokens + output tokens)
- Every model has a max context window (e.g. 128k tokens = ~96k words)
- Longer conversations cost more money

### The chat completions API

Every LLM API (OpenAI, Azure OpenAI, Anthropic) follows basically the same pattern:

**Request:**
```json
{
  "model": "gpt-4o-mini",
  "messages": [
    {"role": "system", "content": "You are a helpful assistant."},
    {"role": "user", "content": "What is a resource group?"},
    {"role": "assistant", "content": "A resource group is a container..."},
    {"role": "user", "content": "How do I create one with Terraform?"}
  ],
  "temperature": 0.7,
  "max_tokens": 1000
}
```

**Response:**
```json
{
  "id": "chatcmpl-abc123",
  "choices": [
    {
      "message": {
        "role": "assistant",
        "content": "To create a resource group in Terraform..."
      },
      "finish_reason": "stop"
    }
  ],
  "usage": {
    "prompt_tokens": 87,
    "completion_tokens": 142,
    "total_tokens": 229
  }
}
```

### The three message roles

| Role | What it is | Who sets it |
|------|-----------|-------------|
| `system` | Instructions for how the model should behave | You (developer) |
| `user` | The human's message | User input |
| `assistant` | The model's reply | Model output (or you, to set conversation history) |

The model sees the entire conversation every time. It has no memory — you send the full history each call.

### Key parameters

| Parameter | What it does | Range |
|-----------|-------------|-------|
| `temperature` | Randomness/creativity. 0 = deterministic, 2 = very random | 0–2 |
| `max_tokens` | Max length of the response | Depends on model |
| `top_p` | Alternative to temperature. Controls diversity | 0–1 |
| `stream` | Stream the response token by token instead of waiting | true/false |

### Azure OpenAI vs OpenAI API

Azure OpenAI is the same models (GPT-4o, GPT-4o-mini) but hosted in Azure. Differences:

| | OpenAI | Azure OpenAI |
|--|--------|-------------|
| Auth | API key | API key OR Entra ID token |
| URL | `api.openai.com` | `{your-endpoint}.openai.azure.com` |
| Model name in request | `gpt-4o` | Your deployment name (e.g. `my-gpt4o`) |
| Data residency | US | Your chosen Azure region |

**Azure OpenAI URL pattern:**
```
https://{endpoint}.openai.azure.com/openai/deployments/{deployment}/chat/completions?api-version=2024-06-01
```

---

## Python — Talking to APIs and LLMs

Python is the dominant language for working with APIs and AI models. Here are the libraries you need to know.

### `requests` — raw HTTP requests

The standard library for making HTTP requests in Python. If you want to call any API without a dedicated SDK, use this.

```python
import requests

response = requests.get(
    "https://management.azure.com/subscriptions/abc-123/resourcegroups",
    headers={
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    },
    params={"api-version": "2021-04-01"}
)

print(response.status_code)   # 200
print(response.json())        # parsed JSON as Python dict
```

POST request with a body:
```python
response = requests.post(
    "https://api.example.com/v1/resource",
    headers={"Authorization": f"Bearer {token}"},
    json={"name": "rg-dev", "location": "westeurope"}  # json= auto-sets Content-Type
)
```

```bash
pip install requests
```

### `httpx` — async HTTP (modern alternative to requests)

Same as `requests` but supports `async/await`. Use this when you're building apps that need to call multiple APIs at the same time without waiting.

```python
import httpx
import asyncio

async def get_models():
    async with httpx.AsyncClient() as client:
        response = await client.get("https://api.openai.com/v1/models",
                                    headers={"Authorization": f"Bearer {api_key}"})
        return response.json()

asyncio.run(get_models())
```

```bash
pip install httpx
```

### `python-dotenv` — load secrets from `.env` files

Never hardcode API keys. Store them in a `.env` file and load them:

`.env` file:
```
AZURE_OPENAI_ENDPOINT=https://my-endpoint.openai.azure.com
AZURE_OPENAI_KEY=abc123...
AZURE_SUBSCRIPTION_ID=sub-abc-123
```

Python:
```python
from dotenv import load_dotenv
import os

load_dotenv()  # reads .env file and puts values in environment

endpoint = os.getenv("AZURE_OPENAI_ENDPOINT")
api_key = os.getenv("AZURE_OPENAI_KEY")
```

```bash
pip install python-dotenv
```

Always add `.env` to `.gitignore` so secrets never get committed.

---

## What is an SDK?

**SDK = Software Development Kit**

An SDK is a ready-made library (a package you install) that a company builds so you can talk to their service without doing all the hard work yourself.

### The problem without an SDK

Every cloud service (Azure OpenAI, AWS S3, GitHub, etc.) exposes an **API** — a set of HTTP endpoints you can call. You *could* talk to them manually:

```python
import requests

response = requests.post(
    "https://my-endpoint.openai.azure.com/openai/deployments/my-gpt4o/chat/completions?api-version=2024-06-01",
    headers={
        "Content-Type": "application/json",
        "api-key": "abc123..."
    },
    json={
        "messages": [{"role": "user", "content": "Hello"}],
        "temperature": 0.7,
        "max_tokens": 500
    }
)

data = response.json()
print(data["choices"][0]["message"]["content"])
```

This works — but it's verbose, error-prone, and you have to know every URL, header, and JSON field by heart.

### The solution: SDK

The SDK wraps all of that into clean, simple function calls:

```python
from openai import AzureOpenAI

client = AzureOpenAI(endpoint="...", api_key="...")

response = client.chat.completions.create(
    model="my-gpt4o",
    messages=[{"role": "user", "content": "Hello"}]
)

print(response.choices[0].message.content)
```

Same result. But the SDK handles the URL, headers, JSON structure, and error parsing for you.

### API vs SDK — what's the difference?

| | API | SDK |
|---|---|---|
| **What it is** | The interface/endpoints the service exposes | A library that calls those endpoints for you |
| **Format** | HTTP requests (URLs, headers, JSON) | Python/JS/etc. functions and objects |
| **Who makes it** | The service provider | Usually the same provider |
| **You need to know** | Every URL, header, body field | Just the function names |

**Simple analogy:**
- **API** = a restaurant's menu (defines what you can order and how)
- **SDK** = a waiter (takes your order and handles the communication for you)

You end up with the same food either way — but the waiter makes it much easier.

### Why SDKs matter in DevOps/Cloud

In your project you used:
- `openai` SDK → talks to Azure OpenAI API
- `azure-identity` SDK → handles Azure authentication
- `azure.mgmt.resource` SDK → manages Azure resources from Python

Without these SDKs, every one of those interactions would be manual HTTP requests. SDKs are what make working with cloud services practical.

### Key points to remember

- An API is a **contract** — "here's how you can talk to my service"
- An SDK is a **tool** — "here's a library that makes talking to my service easy"
- Every SDK wraps an API under the hood
- You install SDKs via `pip install` (Python) or `npm install` (Node.js)
- SDKs are maintained by the provider, so they stay up to date with API changes

---

### `openai` — OpenAI and Azure OpenAI SDK

The official Python SDK. Works with both OpenAI and Azure OpenAI.

**Azure OpenAI:**
```python
from openai import AzureOpenAI
from dotenv import load_dotenv
import os

load_dotenv()

client = AzureOpenAI(
    azure_endpoint=os.getenv("AZURE_OPENAI_ENDPOINT"),
    api_key=os.getenv("AZURE_OPENAI_KEY"),
    api_version="2024-06-01"
)

response = client.chat.completions.create(
    model="my-gpt4o-deployment",   # your deployment name in Azure
    messages=[
        {"role": "system", "content": "You are a helpful assistant."},
        {"role": "user", "content": "What is a resource group?"}
    ],
    temperature=0.7,
    max_tokens=500
)

print(response.choices[0].message.content)
print(f"Tokens used: {response.usage.total_tokens}")
```

**Streaming responses (token by token):**
```python
stream = client.chat.completions.create(
    model="my-gpt4o-deployment",
    messages=[{"role": "user", "content": "Explain Terraform in 3 sentences"}],
    stream=True
)

for chunk in stream:
    if chunk.choices[0].delta.content:
        print(chunk.choices[0].delta.content, end="", flush=True)
```

```bash
pip install openai
```

### `anthropic` — Claude SDK

The official Python SDK for Claude models (Anthropic).

```python
import anthropic

client = anthropic.Anthropic(api_key="your-key")

message = client.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=1024,
    messages=[
        {"role": "user", "content": "Explain how Azure ARM works"}
    ]
)

print(message.content[0].text)
```

```bash
pip install anthropic
```

### `azure-identity` — Azure authentication in Python

Handles getting tokens from Entra ID. You don't have to write the token flow manually.

```python
from azure.identity import DefaultAzureCredential, ClientSecretCredential

# Uses whatever auth is available (env vars, az login, managed identity)
credential = DefaultAzureCredential()

# Or explicitly with a service principal
credential = ClientSecretCredential(
    tenant_id="your-tenant-id",
    client_id="your-client-id",
    client_secret="your-client-secret"
)

# Get a token for a specific Azure service
token = credential.get_token("https://management.azure.com/.default")
print(token.token)  # use this in Authorization: Bearer header
```

**Using Azure identity with Azure OpenAI (no API key needed):**
```python
from azure.identity import DefaultAzureCredential, get_bearer_token_provider
from openai import AzureOpenAI

credential = DefaultAzureCredential()
token_provider = get_bearer_token_provider(credential, "https://cognitiveservices.azure.com/.default")

client = AzureOpenAI(
    azure_endpoint=os.getenv("AZURE_OPENAI_ENDPOINT"),
    azure_ad_token_provider=token_provider,
    api_version="2024-06-01"
)
```

```bash
pip install azure-identity
```

### `azure-mgmt-*` — manage Azure resources from Python

These libraries let you manage Azure resources (create resource groups, deployments, etc.) without calling the raw REST API.

```python
from azure.mgmt.resource import ResourceManagementClient
from azure.identity import DefaultAzureCredential
import os

credential = DefaultAzureCredential()
subscription_id = os.getenv("AZURE_SUBSCRIPTION_ID")

client = ResourceManagementClient(credential, subscription_id)

# List all resource groups
for rg in client.resource_groups.list():
    print(rg.name, rg.location)

# Create a resource group
client.resource_groups.create_or_update(
    "rg-dev",
    {"location": "westeurope"}
)
```

Key `azure-mgmt-*` packages:

| Package | What it manages |
|---------|----------------|
| `azure-mgmt-resource` | Resource groups, deployments, subscriptions |
| `azure-mgmt-compute` | VMs, disks, scale sets |
| `azure-mgmt-network` | VNets, NSGs, load balancers |
| `azure-mgmt-storage` | Storage accounts, blobs |
| `azure-mgmt-cognitiveservices` | Azure OpenAI, Cognitive Services |

```bash
pip install azure-mgmt-resource azure-mgmt-cognitiveservices
```

### `langchain` — LLM orchestration

LangChain is a framework for building applications on top of LLMs. It chains together: prompts, models, tools, memory, retrieval.

```python
from langchain_openai import AzureChatOpenAI
from langchain_core.messages import HumanMessage, SystemMessage

llm = AzureChatOpenAI(
    azure_deployment="my-gpt4o",
    azure_endpoint=os.getenv("AZURE_OPENAI_ENDPOINT"),
    api_key=os.getenv("AZURE_OPENAI_KEY"),
    api_version="2024-06-01"
)

messages = [
    SystemMessage(content="You are a cloud engineer assistant."),
    HumanMessage(content="What is a managed identity?")
]

response = llm.invoke(messages)
print(response.content)
```

LangChain shines when you need:
- Retrieval Augmented Generation (RAG) — search your own documents, then answer
- Chains — pipe the output of one step into the next
- Agents — let the LLM decide what tools to call
- Memory — maintain conversation state

```bash
pip install langchain langchain-openai
```

### `semantic-kernel` — Microsoft's LLM framework (Python + C#)

Microsoft's alternative to LangChain. More structured, deeply integrated with Azure.

```python
import asyncio
import semantic_kernel as sk
from semantic_kernel.connectors.ai.open_ai import AzureChatCompletion

kernel = sk.Kernel()

kernel.add_service(
    AzureChatCompletion(
        deployment_name="my-gpt4o",
        endpoint=os.getenv("AZURE_OPENAI_ENDPOINT"),
        api_key=os.getenv("AZURE_OPENAI_KEY")
    )
)

# Define a prompt function
summarize = kernel.create_function_from_prompt(
    "Summarize this in one sentence: {{$input}}"
)

result = asyncio.run(kernel.invoke(summarize, input="Long text here..."))
print(result)
```

```bash
pip install semantic-kernel
```

---

## Most Used Python Libraries — Summary

| Library | What it's for | Install |
|---------|--------------|---------|
| `requests` | Raw HTTP calls to any API | `pip install requests` |
| `httpx` | Async HTTP calls | `pip install httpx` |
| `python-dotenv` | Load secrets from `.env` files | `pip install python-dotenv` |
| `openai` | OpenAI and Azure OpenAI | `pip install openai` |
| `anthropic` | Claude (Anthropic) | `pip install anthropic` |
| `azure-identity` | Azure authentication | `pip install azure-identity` |
| `azure-mgmt-resource` | Manage Azure resources | `pip install azure-mgmt-resource` |
| `langchain` | LLM app framework | `pip install langchain langchain-openai` |
| `semantic-kernel` | Microsoft's LLM framework | `pip install semantic-kernel` |

---

## How Everything Connects

```
Your Python Script
├── reads secrets from .env (python-dotenv)
├── authenticates to Azure (azure-identity → gets token from Entra ID)
│
├── calls Azure Resource Manager (requests or azure-mgmt-*)
│   └── creates resource groups, AI services, storage
│
├── calls Azure OpenAI (openai SDK)
│   └── sends messages → gets LLM responses
│       └── under the hood: POST https://{endpoint}.openai.azure.com/openai/deployments/{model}/chat/completions
│
└── (optionally) uses LangChain or Semantic Kernel
    └── adds RAG, agents, memory on top of the base LLM calls
```

Every one of those arrows is an HTTP request with:
- a URL
- a method
- an Authorization header with a token
- a JSON body

That's the whole stack.

---

## Practical: Using curl to Test APIs

Before writing Python, test APIs directly with curl:

```bash
# Get an Azure token (using service principal)
TOKEN=$(curl -s -X POST \
  "https://login.microsoftonline.com/${TENANT_ID}/oauth2/v2.0/token" \
  -d "grant_type=client_credentials&client_id=${CLIENT_ID}&client_secret=${CLIENT_SECRET}&scope=https://management.azure.com/.default" \
  | jq -r '.access_token')

# Use the token to list resource groups
curl -X GET \
  "https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/resourcegroups?api-version=2021-04-01" \
  -H "Authorization: Bearer $TOKEN" \
  | jq '.'
```

```bash
# Call Azure OpenAI directly
curl -X POST \
  "https://${ENDPOINT}.openai.azure.com/openai/deployments/${DEPLOYMENT}/chat/completions?api-version=2024-06-01" \
  -H "api-key: ${AZURE_OPENAI_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [{"role": "user", "content": "Hello"}],
    "max_tokens": 100
  }' \
  | jq '.'
```

If you can do it with curl, you can do it with Python. curl is the fastest way to learn and debug APIs.
