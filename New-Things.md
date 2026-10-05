# Things to Learn Later

Topics I want to explore but haven't covered yet.

---

## 1. OIDC Token

How OIDC (OpenID Connect) authentication works — specifically how GitHub Actions requests a short-lived token from GitHub's identity provider to authenticate to Azure without storing client secrets. Covers the trust relationship between GitHub and Azure AD (Entra ID), federated credentials, and how `id-token: write` permission enables it.

---

## 2. Flask

**What it is:** A minimal Python web framework. You define routes (URLs) and write the logic that runs when someone hits them. Nothing more, nothing less — you add everything else yourself.

**Where it's used:**
- Internal tools and dashboards
- Simple REST APIs
- Prototypes and demos
- Older Azure and Microsoft sample apps

**Core idea:**

```python
from flask import Flask, request, jsonify

app = Flask(__name__)

@app.route("/chat", methods=["POST"])
def chat():
    data = request.get_json()
    message = data["message"]
    # call Azure OpenAI here
    return jsonify({"reply": "..."})

app.run(debug=True)
```

Every route is a Python function. Flask calls that function when a request hits that URL.

**What Flask does NOT include out of the box:**
- Input validation — you check it yourself
- Auto-generated API docs — you write them manually
- Async support — needs extra setup
- Database — you add SQLAlchemy or similar

**What to learn:**
1. Routes and HTTP methods (`@app.route`, GET vs POST)
2. Reading request data (`request.json`, `request.args`)
3. Returning JSON responses (`jsonify`)
4. Error handling (`@app.errorhandler`)
5. Blueprints — splitting a large app into modules
6. Connecting to a database with SQLAlchemy
7. Deploying to Azure App Service

**Best resource:** Official Flask docs — `flask.palletsprojects.com`

**When to use Flask vs FastAPI:** Flask for simple scripts and learning. FastAPI for anything you're building seriously today.

---

## 3. FastAPI

**What it is:** A modern Python web framework for building APIs — same idea as Flask (define routes, handle HTTP requests) but faster, cleaner, and production-ready out of the box.

**Where it's used:**
- AI backends (the standard choice for Azure OpenAI apps)
- Production REST APIs
- Anything that needs to handle many requests fast
- Microsoft's own Azure AI sample apps

**How it differs from Flask:**

| Flask | FastAPI |
|-------|---------|
| Manual input validation | Automatic — rejects bad requests by schema |
| No built-in docs | Auto-generates interactive docs at `/docs` |
| No type hints required | Type hints required — makes code explicit |
| Sync only by default | Native async support |
| Good for learning/small apps | Better for production APIs |

**Core idea:**

```python
from fastapi import FastAPI
from pydantic import BaseModel

app = FastAPI()

class ChatRequest(BaseModel):
    prompt: str

@app.post("/chat")
def chat(body: ChatRequest):
    # body.prompt is already validated as a string
    ...
```

- `BaseModel` (from pydantic) defines the shape of the request — FastAPI validates it automatically
- If someone sends `{"prompt": 123}` instead of a string, FastAPI rejects it with a clear error
- Go to `http://localhost:8000/docs` to get a UI to test endpoints without curl

**What to learn:**
1. Routes, path parameters, query parameters
2. Request and response models with Pydantic
3. Async endpoints (`async def`)
4. Dependency injection (FastAPI's way of sharing logic between routes)
5. Error handling and HTTP exceptions
6. Middleware (runs code before/after every request)
7. Connecting to Azure OpenAI and azure-identity
8. Containerizing with Docker and deploying to Azure Container Apps

**Best resource:** Official FastAPI docs — `fastapi.tiangolo.com` — best written docs of any Python framework, do the tutorial top to bottom.

---

## 4. Django

**What it is:** A full-featured Python web framework — the opposite of Flask. Where Flask gives you nothing and you build everything yourself, Django gives you everything built in. It's batteries-included.

**Where it's used:**
- Full web applications with user accounts and databases
- Content platforms, e-commerce, admin panels
- Anywhere you need auth, database, admin UI fast
- Instagram, Pinterest, and Disqus were built on Django

**What Django includes out of the box:**

| Feature | Description |
|---------|-------------|
| ORM | Talk to databases without writing SQL |
| Admin panel | Auto-generated UI to manage your database |
| Auth system | User accounts, login, passwords, sessions |
| Forms | HTML form handling and validation |
| Template engine | Generate HTML pages |
| Security | CSRF protection, XSS protection built in |

**Core idea:**

```python
# models.py — defines database tables as Python classes
from django.db import models

class Conversation(models.Model):
    user_message = models.TextField()
    ai_reply = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)
```

```python
# views.py — handles requests
from django.http import JsonResponse

def chat(request):
    # call Azure OpenAI
    return JsonResponse({"reply": "..."})
```

```python
# urls.py — connects URLs to views
from django.urls import path
from . import views

urlpatterns = [
    path("chat/", views.chat),
]
```

**Flask vs FastAPI vs Django — when to use which:**

| Situation | Use |
|-----------|-----|
| Building an AI API backend | FastAPI |
| Quick prototype or small tool | Flask |
| Full web app with database, users, admin | Django |
| Learning Python web frameworks | Flask first, then FastAPI |

**What to learn:**
1. Models and the ORM (`models.py`, migrations, querying)
2. Views and URLs (`views.py`, `urls.py`)
3. Django admin — auto-generated management interface
4. Templates — generating HTML from Python
5. Django REST Framework (DRF) — turns Django into an API server, widely used
6. Auth — Django's built-in user system
7. Deploying to Azure App Service

**Best resource:** Official Django docs — `docs.djangoproject.com` — start with "Writing your first Django app"

---

## 5. JavaScript and TypeScript

**What they are:**

**JavaScript** is the only language that runs natively inside every web browser. It's what makes websites interactive — buttons, forms, animations, live updates. It also runs on the server (Node.js).

**TypeScript** is JavaScript with types added. It catches mistakes before you run the code. Most serious projects use TypeScript today.

```javascript
// JavaScript
function greet(name) {
    return "Hello " + name
}
```

```typescript
// TypeScript — same thing but name must be a string
function greet(name: string): string {
    return "Hello " + name
}
```

TypeScript compiles down to JavaScript — browsers still run JavaScript underneath.

**Why JavaScript/TypeScript matters for your path:**
- Frontends are almost always JavaScript
- When someone builds a full-stack AI app (frontend + backend) the frontend is React (JavaScript/TypeScript)
- Node.js lets you run JavaScript on the server — so one language for everything

---

## 6. Express.js

**What it is:** The Flask of JavaScript. A minimal web framework that runs on Node.js (JavaScript on the server). The most widely used backend framework in the JavaScript world.

**Where it's used:**
- REST APIs
- Backend services for web and mobile apps
- Anywhere a team wants JavaScript on the server instead of Python

**Core idea — same concept as Flask, different language:**

```javascript
const express = require("express")
const app = express()

app.use(express.json())  // parse JSON bodies

app.post("/chat", async (req, res) => {
    const { message } = req.body
    // call Azure OpenAI here
    res.json({ reply: "..." })
})

app.listen(3000)
```

**Express vs Flask:**

| | Express (JS) | Flask (Python) |
|--|-------------|----------------|
| Language | JavaScript | Python |
| Style | Minimal, add what you need | Minimal, add what you need |
| AI/Azure libraries | Fewer, less mature | More, better supported |
| Frontend integration | Easy (same language as frontend) | Separate language from frontend |

**What to learn:**
1. Routes and middleware
2. Reading request body, params, query strings
3. Returning JSON responses
4. Error handling middleware
5. Connecting to databases (Mongoose for MongoDB, Prisma for SQL)
6. Calling Azure OpenAI from Node.js (`openai` npm package works in JS too)
7. Deploying to Azure App Service or Azure Container Apps

**Install:**
```bash
npm install express
```

---

## 7. NestJS

**What it is:** The Django or FastAPI of JavaScript — a structured, production-ready backend framework built on top of Express. Uses TypeScript by default. Made by a team that was influenced by Angular (Google's frontend framework).

**Where it's used:**
- Large-scale production APIs
- Enterprise applications
- Teams that want strong structure and TypeScript across the whole stack
- Companies that already use Angular on the frontend

**How it differs from Express:**

| Express | NestJS |
|---------|--------|
| Minimal — you structure it yourself | Opinionated — enforces structure |
| No TypeScript by default | TypeScript by default |
| Small apps and quick APIs | Large, complex production apps |
| Flexible | Consistent across teams |

**Core idea — structured with decorators:**

```typescript
import { Controller, Post, Body } from "@nestjs/common"

@Controller("chat")
export class ChatController {
    @Post()
    async chat(@Body() body: { message: string }) {
        // call Azure OpenAI
        return { reply: "..." }
    }
}
```

Decorators (`@Controller`, `@Post`, `@Body`) are NestJS's way of declaring what each class and method does — similar in concept to FastAPI's type hints.

**What to learn:**
1. Modules, Controllers, Services (NestJS's three building blocks)
2. Decorators and how they work
3. Dependency injection
4. Connecting to databases with TypeORM or Prisma
5. Guards — protecting routes (auth)
6. Interceptors and pipes — transforming requests and responses
7. Deploying to Azure

**Best resource:** Official NestJS docs — `docs.nestjs.com`

---

## Summary — Which Backend Framework to Learn

| Goal | Framework | Language |
|------|-----------|----------|
| AI apps + Azure (start here) | FastAPI | Python |
| Full web app with database and users | Django | Python |
| JavaScript backend, small/medium | Express | JavaScript/TypeScript |
| JavaScript backend, large/enterprise | NestJS | TypeScript |
| Quick learning of web concepts | Flask | Python |
