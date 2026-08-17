# HR Onboarding Automation — Complete Guide

**Client:** Aravind | **Platform:** n8n | **Workflow ID:** pikLR7aDayQo2YhC

---

## What This System Does (Simple Version)

HR fills in one form on the dashboard → clicks submit → **16 things happen automatically in under 4 minutes** that would normally take an HR team 2–3 hours to do manually.

No manual emails. No forgetting to notify the manager. No missing the Trello task. Everything fires at once.

---

## Overall Flow — Bird's Eye View

```
HR fills dashboard form
        ↓
n8n receives the data (Webhook)
        ↓
Cleans & validates the data
        ↓
        ├── INVALID → Alerts HR by email → Stops
        │
        └── VALID ↓
              AI writes a personalized welcome message
                    ↓
              Generates work email + temp password + systems list
                    ↓
              ┌─────────────────────────────────┐
              │ Sends 5 emails simultaneously:  │
              │  • IT team (create accounts)    │
              │  • Employee (welcome)           │
              │  • Employee (task checklist)    │
              │  • Employee (resources)         │
              │  • Manager (formal notice)      │
              └─────────────────────────────────┘
                    ↓
              Creates Trello card + adds checklist
                    ↓
              Sends 2 Slack messages:
                  • DM to manager
                  • Announcement in team channel
                    ↓
              Logs everything to Google Sheets
                    ↓
              Dashboard shows success + employee added to table
```

---

## Node-by-Node Explanation

### Node 1 — Webhook Trigger
**What it does:** Listens for the form submission from the dashboard.

When HR clicks **"Run Onboarding Workflow"** on the dashboard, the browser sends all the employee details (name, email, role, department, etc.) to this webhook URL:
`https://aravind072.app.n8n.cloud/webhook/hr-onboarding`

This is the "start button" of the entire workflow. Nothing happens until this node receives data.

---

### Node 2 — Normalize Employee Data
**What it does:** Cleans up the raw data and gives it a unique ID.

The raw form data comes in messy. This node:
- Trims extra spaces from names, emails
- Makes sure all field names are consistent
- Generates a unique **Onboarding ID** like `ONB-1777299994335` (timestamp-based, always unique)

**Output example:**
```
fullName: "Priya Sharma"
email: "priya@gmail.com"
role: "Product Manager"
department: "Product"
managerId: "manager@company.com"
joiningDate: "2026-05-01"
location: "Bangalore"
onboardingId: "ONB-1777299994335"
```

---

### Node 3 — Validate Employee Data
**What it does:** Checks that all required fields are filled in correctly.

This is a Code node that runs a checklist:
- Is Full Name filled? (not empty)
- Is Email a valid format? (must have @ and a domain)
- Is Role filled?
- Is Department selected?
- Is Manager Email valid?

If anything is missing or wrong, it marks `valid: false` and lists which fields failed.

---

### Node 4 — IF Check (Is Data Valid?)
**What it does:** Decision point — routes the workflow to success or failure path.

- If `valid = true` → continues to AI and emails
- If `valid = false` → goes to the HR Alert email and **stops**

---

### Node 5a — Alert HR (FALSE branch)
**What it does:** Sends an email to HR when the form data is incomplete.

Fires only when validation fails. Tells HR exactly which fields are missing so they can resubmit correctly.

**Email goes to:** `aravindsg072@gmail.com`

---

### Node 5b — Generate Welcome Message (OpenAI)
**What it does:** Uses AI to write a personalized 3-paragraph welcome email for the new employee.

Instead of a generic "Dear Employee, welcome to the company" template, GPT-4o-mini writes something specific to this person — mentioning their name, role, department, and joining date in a warm, professional tone.

**Model used:** `gpt-4o-mini`

---

### Node 6 — Generate Account Details
**What it does:** Simulates the IT account provisioning by generating the work credentials.

Since the client uses free Google (no Google Workspace Admin API), this Code node generates:
- **Work Email:** `firstname.lastname@company.com`
- **Temp Password:** Random 12-character secure password
- **Slack Handle:** `@firstname.lastname`
- **Systems to provision:** Based on department:

| Department | Systems |
|---|---|
| Engineering | GitHub, Jira, Confluence, AWS Console |
| Product | Jira, Confluence, Figma, Miro |
| HR | HRMS Portal, Payroll System, Confluence |
| Sales | CRM, HubSpot, Zoom, Salesforce |
| Finance | Finance Portal, ERP System, Confluence |
| Operations | Operations Dashboard, Jira, Confluence |

---

### Node 7 — Gmail → IT Team
**What it does:** Sends a formatted email to the IT admin requesting account creation.

IT receives a table with:
- Employee name, role, department
- Work email to create
- Temp password to set
- All systems to provision
- Slack handle

**Subject:** `🔧 Action Required: Account Setup for [Name]`

---

### Node 8 — Gmail → Employee (Welcome Email)
**What it does:** Sends the AI-written welcome email to the new employee's personal email.

Includes:
- The personalized message from OpenAI
- Their future work email address
- List of systems being set up
- Links to HR portal, company policies, IT setup guide

---

### Node 9 — Trello — Create Card
**What it does:** Creates a card on the HR Onboarding Trello board.

- **Board:** HR Onboarding
- **List:** New Joiner
- **Card title:** `[Name] — [Role] | Joining: [Date]`
- **Due date:** Set to the joining date
- **Description:** Department, manager, location, work email, onboarding ID

---

### Node 10 — Trello — Add Checklist
**What it does:** Adds an 8-item onboarding checklist to the Trello card.

Checklist items:
1. Complete HR documentation forms (Day 1)
2. IT setup — laptop, email, tools (Day 1)
3. Attend compliance training (Week 1)
4. Complete role-specific onboarding training (Week 1–2)
5. Meet reporting manager (Day 1)
6. Join team Slack channels (Day 1)
7. Review employee handbook (Week 1)
8. Set up 2FA on all accounts (Day 1)

---

### Node 11 — Gmail → Employee (Checklist Email)
**What it does:** Sends the onboarding task checklist to the employee as a formatted HTML email.

Same items as the Trello card, but sent directly to the employee so they know exactly what to do on Day 1.

---

### Node 12 — Gmail → Employee (Resources Email)
**What it does:** Sends all useful company resources to the new employee.

Includes links to:
- Employee Handbook
- Team Structure / Org Chart
- Knowledge Base / Wiki
- Training Materials Portal
- IT Helpdesk
- HR Portal (leave, payroll, documents)

---

### Node 13 — Slack → Manager (Direct Message)
**What it does:** Sends a private Slack DM to the new employee's manager.

Message includes all employee details and suggests actions:
- Send them a welcome message
- Schedule a 1:1 for Day 1
- Add them to relevant channels
- Share team-specific onboarding docs

---

### Node 14 — Slack → Team Channel
**What it does:** Posts a public announcement in the team Slack channel (#general).

Simple announcement: "Welcome [Name] who is joining as [Role] in [Department] on [Date]. Please give them a warm welcome!"

---

### Node 15 — Gmail → Manager (Formal Email)
**What it does:** Sends the manager a formal email notification (separate from the Slack DM).

Contains all joining details in a professional format for their records.

---

### Node 16 — Google Sheets — Audit Log
**What it does:** Logs every onboarding to a permanent spreadsheet record.

Each row records 18 columns:
`onboardingId | fullName | email | role | department | joiningDate | location | workEmail | systemsProvisioned | itNotified | welcomeEmailSent | checklistSent | resourcesSent | trelloCardCreated | managerNotified | teamNotified | timestamp | status`

This is the HR team's permanent record of every onboarding that happened and when.

---

### Node 17 — Respond to Webhook (Success)
**What it does:** Sends the result back to the dashboard so it can display the response.

Returns a JSON response:
```json
{
  "status": "success",
  "onboardingId": "ONB-1777299994335",
  "message": "Onboarding initiated for Priya Sharma",
  "workEmail": "priya.sharma@company.com",
  "systemsProvisioned": "Jira, Confluence, Figma, Miro"
}
```

This is what the dashboard reads to populate the **Response Box** and the **Employees Table**.

---

## The Dashboard — Explained

The dashboard is a standalone HTML file that HR opens in a browser. It connects live to the n8n workflow.

### Form Panel (Right Side)
HR fills in 7 fields:
- Full Name, Role, Personal Email
- Department (dropdown)
- Location, Manager Email, Joining Date

Click **"Run Onboarding Workflow"** → data is sent to n8n → all 16 steps fire.

### Response Box (Below Submit Button)
After n8n responds, shows:
- Onboarding ID
- Work email that was generated
- Systems being provisioned
- Status

### Onboarded Employees Table (Left Side)
Appears after the first successful submission. Shows every employee onboarded in this browser session as a table row. Does not persist on page refresh (it's session-only — the permanent record is in Google Sheets).

### Activity Feed
Shows a live log entry for every submission — with the employee name, department, systems, and whether it succeeded or errored.

### KPI Cards (Top)
See next section.

---

## What Are KPIs?

**KPI = Key Performance Indicator**

A KPI is a number that tells you how well something is working. Instead of reading through logs or emails, you look at a KPI card and instantly know the status.

### The 4 KPIs on This Dashboard:

**1. Total Onboarded**
How many employees have been successfully onboarded through this automation. Starts at 0, increments by 1 for every successful submission.

*Why it matters:* Shows the total volume of work the automation has handled — work that would have been done manually otherwise.

**2. Success Rate**
What percentage of workflow runs completed without error. Formula: `(successful runs ÷ total runs) × 100`

*Why it matters:* If this drops below 90%, something in the workflow is broken and needs fixing.

**3. Automation Time**
Shows `~4 minutes` — the approximate time n8n takes to complete all 16 steps.

*Why it matters:* Manual onboarding takes 2–3 hours (emails, Slack messages, Trello setup, account requests). Automation does it in 4 minutes. This is the ROI number.

**4. Completed Today**
How many onboardings happened in the current browser session today.

*Why it matters:* Gives HR a quick count without opening Google Sheets.

---

## ROI — Why This Automation Matters

| Task | Manual Time | Automated Time |
|---|---|---|
| Send IT account request | 10 min | 0 min |
| Write & send welcome email | 20 min | 0 min |
| Create Trello card + checklist | 10 min | 0 min |
| Email checklist to employee | 10 min | 0 min |
| Email resources to employee | 10 min | 0 min |
| Notify manager (Slack + Email) | 10 min | 0 min |
| Post team announcement | 5 min | 0 min |
| Log to spreadsheet | 5 min | 0 min |
| **Total per employee** | **~80 minutes** | **~4 minutes** |

For 10 new joiners a month: **saves ~13 hours of HR time per month.**

---

## Credentials Used

| Service | Used For |
|---|---|
| Gmail (`shPXnklC5pwPuWf7`) | All 5 outbound emails |
| OpenAI (`8qM07npMAvqQrZ8e`) | Personalized welcome message |
| Slack (`4HivW4aJwI07zzYk`) | Manager DM + team channel |
| Google Sheets (`CffGhItqWINggVzC`) | Audit log |
| Trello (`9JLc3RqVqUTHmZGc`) | Onboarding task board |

---

## How to Test

1. Open the dashboard: `hr_onboarding_dashboard.html` in a browser (served via localhost or Netlify)
2. Fill in the form with a real employee's details
3. Click **Run Onboarding Workflow**
4. Wait ~30 seconds
5. Check:
   - ✅ Response box shows onboarding ID and work email
   - ✅ Employee appears in the table
   - ✅ IT team email received
   - ✅ Employee welcome email received
   - ✅ Trello card created in "New Joiner" list
   - ✅ Manager gets Slack DM + email
   - ✅ Google Sheet has new row

---

*Built by Qubitrix AI · n8n v2.17.5 · Workflow ID: pikLR7aDayQo2YhC*
