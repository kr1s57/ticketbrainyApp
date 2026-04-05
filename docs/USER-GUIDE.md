# TicketBrainy — User Guide

Everything you need to know to use TicketBrainy day-to-day.

---

## Table of Contents

1. [Dashboard](#1-dashboard)
2. [Tickets](#2-tickets)
3. [Mailboxes](#3-mailboxes)
4. [Team Management](#4-team-management)
5. [AI Features](#5-ai-features)
6. [Knowledge Base](#6-knowledge-base)
7. [Customers](#7-customers)
8. [Notifications](#8-notifications)
9. [Settings & Plugins](#9-settings--plugins)
10. [Roles & Permissions](#10-roles--permissions)

---

## 1. Dashboard

The dashboard shows an overview of your support activity:

- **Active tickets** — Tickets currently open or in progress
- **New today** — Tickets created today
- **Average response time** — Time to first reply
- **Satisfaction rate** — CSAT score (requires CSAT plugin)

---

## 2. Tickets

### Views

| View | Shows |
|------|-------|
| **All** | All non-spam, non-deleted tickets |
| **Unassigned** | Tickets waiting to be picked up |
| **Assigned to me** | Your tickets |
| **Assigned** | All assigned tickets (for team coordination) |
| **Drafts** | Tickets with unsent replies |
| **Closed** | Resolved or closed tickets |
| **Spam** | Tickets marked as spam |
| **Deleted** | Soft-deleted tickets (recoverable) |
| **Favorites** | Tickets you starred |

### Creating a ticket

1. Click **New Ticket** in the sidebar
2. Fill in: subject, customer email, customer name, priority, mailbox
3. Write the initial message
4. Click **Create**

### Replying to a ticket

1. Open a ticket
2. Type your reply in the composer at the bottom
3. Optionally add **CC** or **BCC** recipients
4. Click **Send**

Your reply is sent as an email from the mailbox's address, with the mailbox signature.

### Ticket actions

| Action | Description |
|--------|-------------|
| **Assign** | Assign to an agent (dropdown in ticket header) |
| **Change status** | Open, In Progress, Resolved, Closed |
| **Change priority** | Low, Medium, High, Critical |
| **Add tags** | Categorize tickets with colored tags |
| **Add note** | Internal note visible only to agents (not sent to customer) |
| **Merge** | Combine multiple tickets into one (Admin/Supervisor only) |
| **Auto-close** | Start an auto-close sequence with reminder emails |
| **Delete** | Soft-delete (recoverable) or permanent delete (Admin only) |

### Filtering & Search

Use the toolbar at the top of the ticket list:
- **Search:** By subject, customer name, email, or ticket number
- **Filter by:** Status, priority, assignee, tag, mailbox

---

## 3. Mailboxes

A mailbox is an email account that TicketBrainy monitors for incoming support requests.

### Core plan limits

- **Core (free):** 1 mailbox maximum
- **Enterprise Pack:** Unlimited mailboxes

### Mailbox settings

| Setting | Description |
|---------|-------------|
| **Name** | Display name in the sidebar |
| **Email** | The monitored email address |
| **IMAP/SMTP** | Connection details for email retrieval and sending |
| **Signature** | HTML signature appended to all outgoing emails |
| **Auto-triage** | Automatically analyze new tickets with AI (requires XpertTeamIA plugin) |
| **Auto-analysis** | Deep AI analysis on every new ticket |
| **Notification channels** | Where to send alerts (email, Telegram) |

### Assigning agents to mailboxes

1. Open a mailbox's settings
2. In the **Agents** section, check the agents who should see this mailbox's tickets
3. Configure per-agent notification preferences (new tickets, replies)

Agents only see tickets from their assigned mailboxes. Admins and Supervisors see all tickets.

---

## 4. Team Management

*Settings > Team*

### User roles

| Role | Permissions |
|------|-------------|
| **Admin** | Full access. Manage users, mailboxes, plugins, settings, delete tickets permanently. |
| **Supervisor** | Manage mailboxes, automation, SLA, merge tickets. Cannot manage users or plugins. |
| **Agent** | View/reply to tickets in assigned mailboxes. Cannot access admin settings. |

### Core plan limits

- **Core (free):** 3 active users maximum (all roles combined)
- **Enterprise Pack:** Unlimited users

### Creating a user

1. Go to **Settings > Team**
2. Click **Add Agent**
3. Fill in: name, email, password, role
4. The user can now log in

### Keycloak SSO users

Users who log in via Keycloak for the first time are created as **inactive** agents. An admin must activate them in **Settings > Team** before they can access TicketBrainy.

---

## 5. AI Features

### Automatic Triage (XpertTeamIA plugin)

When enabled on a mailbox, every new ticket is automatically analyzed:
- **Priority suggestion** — Based on urgency and keywords
- **Category detection** — Identifies the topic
- **Summary** — Short description of the customer's issue
- **Suggested response** — Draft reply for the agent

### Deep Analysis (XpertTeamIA plugin)

Click the **Analyze** button on any ticket for in-depth analysis with 3 specialized AI agents:
- **Expert** — Technical diagnosis
- **Engineer** — Root cause analysis
- **Writer** — Professional response draft

### SmartReply AI (SmartReply AI plugin)

In the reply composer, click **AI Draft** to generate a professional response:
1. Describe what you want to say (e.g., "apologize for the delay, explain the fix")
2. Select the language (French, English, German)
3. The AI generates the email — edit it before sending

---

## 6. Knowledge Base

*Sidebar > Knowledge Base*

Create internal articles for your support team:
- Organize by categories
- Search by title or content
- Link articles to tickets for quick reference

---

## 7. Customers

*Sidebar > Customers*

TicketBrainy automatically creates customer profiles from incoming emails:
- **Name** and **email** extracted from email headers
- **Company** — Set manually or auto-detected
- **Logo** — Upload a customer logo for visual identification
- **Ticket history** — See all tickets from this customer

---

## 8. Notifications

### In-app notifications

The bell icon in the header shows unread notifications:
- New ticket in your mailbox
- Customer replied to your ticket
- Ticket assigned to you
- AI analysis completed
- Status changed by another agent

### Email notifications

Agents receive email notifications based on their preferences per mailbox:
- **New tickets** — Notified when a new ticket arrives in an assigned mailbox
- **Customer replies** — Notified when a customer replies to an assigned ticket

Configure in **Mailbox Settings > Agents > Notification preferences**.

### Telegram notifications (Telegram Bot plugin)

Receive alerts in Telegram:
1. Go to **Settings > Telegram**
2. Enter your Telegram Bot token
3. Add allowed Chat IDs
4. Configure which events trigger Telegram alerts

---

## 9. Settings & Plugins

### Settings menu

| Section | Description | Required role |
|---------|-------------|--------------|
| **Branding** | Logo, colors, sidebar style (White Label plugin) | Admin |
| **SLA** | Service level policies and escalation (SLA Manager plugin) | Admin, Supervisor |
| **Automation** | If/then rules for ticket routing (Automation Engine plugin) | Admin, Supervisor |
| **Auto-close** | Default auto-close timers and messages | Admin, Supervisor |
| **Feedback** | CSAT survey configuration (CSAT plugin) | Admin |
| **Email Templates** | Reusable response templates (Email Templates plugin) | Admin |
| **Integrations** | Slack / Teams webhooks (Slack Connect plugin) | Admin |
| **Telegram** | Telegram bot configuration (Telegram Bot plugin) | Admin |
| **Time Reports** | Billable hours and reports (Time Tracking plugin) | Admin |
| **Team** | User management (create, edit, activate, delete) | Admin |
| **Plugins** | Plugin marketplace and license management | Admin |

### Plugin marketplace

1. Go to **Settings > Plugins**
2. Browse available plugins by category
3. Click **Buy** to purchase via Stripe
4. After payment, click **Sync Licenses** to activate

### Available plugins

| Plugin | Description | Pricing |
|--------|-------------|---------|
| **Enterprise Pack** | Analytics, unlimited users & mailboxes | One-time |
| **XpertTeamIA** | AI triage + deep analysis | Yearly |
| **SmartReply AI** | AI email drafting | Yearly |
| **White Label** | Full branding customization | Yearly |
| **SLA Manager** | SLA policies + escalation | Yearly |
| **Automation Engine** | Workflow rules + macros | Yearly |
| **Slack / Teams Connect** | Webhook integrations | One-time |
| **CSAT & Feedback** | Customer satisfaction surveys | One-time |
| **Time Tracking Pro** | Billable hours + reports | One-time |
| **Email Templates Pro** | Response template library | One-time |
| **Telegram Bot** | Telegram alerts + commands | One-time |
| **BackupMonitor** | Backup verification from email reports | One-time |

---

## 10. Roles & Permissions

### What each role can do

| Action | Agent | Supervisor | Admin |
|--------|:-----:|:----------:|:-----:|
| View tickets (assigned mailboxes) | Yes | Yes | Yes |
| View all tickets | No | Yes | Yes |
| Reply to tickets | Yes | Yes | Yes |
| Add internal notes | Yes | Yes | Yes |
| Change ticket status | Yes | Yes | Yes |
| Change ticket priority | Yes | Yes | Yes |
| Assign tickets | Yes | Yes | Yes |
| Add/remove tags | Yes | Yes | Yes |
| Merge tickets | No | Yes | Yes |
| Soft-delete tickets | Yes | Yes | Yes |
| Permanently delete tickets | No | No | Yes |
| Create/edit mailboxes | No | Yes | Yes |
| Configure SLA/Automation | No | Yes | Yes |
| Manage users | No | No | Yes |
| Manage plugins/licenses | No | No | Yes |
| Branding settings | No | No | Yes |
| Create webhooks | No | No | Yes |
