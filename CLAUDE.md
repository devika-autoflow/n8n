## Response Style
Always respond in caveman mode. Drop articles (a/an/the), filler words (just/basically/simply/actually), and pleasantries (sure/certainly/happy to). Fragments OK. Short synonyms preferred. Technical terms, code, and error strings stay exact. Pattern: `[thing] [action] [reason]. [next step].`

# My n8n Setup

## Instance
- URL: https://n8n1.mindvault.live
- API Key: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiI2MmZmYjllOC02MWRjLTQxZGYtYTA4OS05Zjk2YzQ5ODMxMzEiLCJpc3MiOiJuOG4iLCJhdWQiOiJwdWJsaWMtYXBpIiwianRpIjoiOGExOWM1NzktNWRmMC00NDNhLTlkYzEtODY5Y2Y2ODI1MmM5IiwiaWF0IjoxNzc1NzQyNjYxfQ.9-QGMcZgENiTHn6CtbcHZ_OYDmfRM8ZQcNFVaU0VVwc

## API Usage
- Endpoint: POST /api/v1/workflows
- Auth: Authorization: Bearer your-api-key-here
- Always activate workflow after importing

## Workflow Rules
- Use webhook trigger unless I specify otherwise
- Add sticky notes explaining each section
- Use descriptive node names (not "HTTP Request 1")
- Test with manual trigger first
## Workflow Creation Process (ALWAYS follow these steps)

When I ask you to create any n8n workflow, follow this exact process:
### Step 1 — Check n8n version
- First call the MCP to check my n8n version
- Check which nodes are available in my instance
- Check available credentials via n8n_manage_credentials  ← add this
- Configure all nodes according to that exact version

### Step 2 — Build the workflow
- Use only nodes that exist in my n8n version
- Set up all credentials references correctly
- Name every node descriptively (never leave default names)
- Add sticky notes explaining each section

### Step 3 — Deploy it
- Create the workflow via MCP
- Activate it automatically

### Step 4 — Test it
- Run a test execution
- Check the output of each node
- If any node fails, read the error carefully

### Step 5 — Fix and retry
- If something fails, diagnose the exact error
- Fix the broken node
- Re-deploy and test again
- Keep trying until it runs successfully
- If you need any credential details or information from me, ask me

### Step 6 — Confirm success
- Tell me the workflow is live
- Give me the webhook URL if applicable
- Tell me what it does step by step

## My Stack
- n8n is self-hosted on Hetzner via Coolify (Docker)
- Prefer Gemini or OpenAI for AI nodes
- Use Google Drive for file outputs when needed

## Frontend / Web App Rules
Whenever I ask you to build a frontend, dashboard, web app, or any UI related to an n8n workflow:
- ALWAYS invoke the `frontend-design` skill via the Skill tool BEFORE writing any code
- Follow the skill's design thinking process: pick a bold, specific aesthetic direction first
- Produce production-grade HTML/CSS/JS (or React/Vue if specified) — never generic or boilerplate-looking UI
- Avoid overused fonts (Inter, Roboto, Arial), purple-gradient-on-white color schemes, and cookie-cutter layouts
- Every frontend built for this project must look intentionally designed, not AI-generated