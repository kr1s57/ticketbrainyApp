# TicketBrainy — Keycloak SSO Step-by-Step Guide

Keycloak lets your users log in with **Single Sign-On (SSO)** — one login for all your company's apps. This guide walks you through everything, assuming you've never used Keycloak before.

> **Don't need SSO?** Skip this guide. TicketBrainy works with local accounts (email + password) out of the box.

---

## Table of Contents

1. [What is Keycloak?](#1-what-is-keycloak)
2. [Access the Keycloak admin console](#2-access-the-keycloak-admin-console)
3. [Understand realms, clients, and users](#3-understand-realms-clients-and-users)
4. [Create your first user](#4-create-your-first-user)
5. [Connect to Active Directory (optional)](#5-connect-to-active-directory-optional)
6. [Log in to TicketBrainy with your Keycloak user](#6-log-in-to-ticketbrainy-with-your-keycloak-user)
7. [Activate users in TicketBrainy](#7-activate-users-in-ticketbrainy)
8. [Customize the login theme](#8-customize-the-login-theme)
9. [Troubleshooting](#9-troubleshooting)

---

## 1. What is Keycloak?

Keycloak is an **identity provider** — it stores your users and passwords in one central place. Instead of creating accounts in every application, your users log in once via Keycloak and can access all connected apps.

**Without Keycloak:**
- Each user has a separate account in TicketBrainy
- Passwords managed in TicketBrainy
- No connection to your company directory

**With Keycloak:**
- Users defined once in Keycloak
- Keycloak can connect to Active Directory / LDAP / Google Workspace / etc.
- TicketBrainy trusts Keycloak to verify the user's identity
- You can plug other apps (GitLab, Grafana, etc.) into the same Keycloak later

---

## 2. Access the Keycloak admin console

After running the installer with Keycloak enabled, the Keycloak admin console is available at:

```
http://YOUR_SERVER_IP:8180
```

(Or `https://auth.yourcompany.com` if you configured a public domain in Mode B.)

### Login credentials

| Field | Value |
|-------|-------|
| **Username** | `admin` |
| **Password** | The `KC_ADMIN_PASSWORD` shown at the end of the installer |

If you forgot the password, it's in your `.env` file:

```bash
cd ticketbrainyApp
grep KC_ADMIN_PASSWORD .env
```

### First screen

You should see:
- A sidebar on the left with "Manage realms", "Clients", "Users", etc.
- A dropdown at the top left showing the current realm (probably "master")

---

## 3. Understand realms, clients, and users

Keycloak has three key concepts:

| Concept | What it is | Example |
|---------|------------|---------|
| **Realm** | A container for users and apps. Think of it as a separate Keycloak instance. | `ticketbrainy` |
| **Client** | An application that uses Keycloak for authentication. | `ticketbrainy-web` |
| **User** | A person who can log in. | `alice@yourcompany.com` |

### Switch to the TicketBrainy realm

At the top left, click the **realm dropdown** (currently "master") and select **`ticketbrainy`**.

You're now in the realm where your TicketBrainy users will live.

### Verify the client is configured

In the left sidebar:
1. Click **Clients**
2. You should see `ticketbrainy-web` in the list
3. Click on it to see its configuration

This client was created automatically by the TicketBrainy installer. You don't need to modify it.

---

## 4. Create your first user

Let's create a test user to verify everything works.

### 4.1 Add a user

1. In the left sidebar, click **Users**
2. Click **Add user**
3. Fill in:
   - **Username**: `alice@yourcompany.com` (or just `alice`)
   - **Email**: `alice@yourcompany.com`
   - **First name**: Alice
   - **Last name**: Smith
   - **Email verified**: Toggle ON
   - **Enabled**: Toggle ON
4. Click **Create**

### 4.2 Set a password

1. On the user's detail page, click the **Credentials** tab
2. Click **Set password**
3. Enter a password (e.g., `TestPass123!`)
4. Toggle **Temporary** OFF (otherwise the user will be forced to change it on first login)
5. Click **Save**

Your first Keycloak user is ready.

---

## 5. Connect to Active Directory (optional)

If you already have Active Directory (or LDAP), you can sync your existing users instead of creating them manually.

### 5.1 Add LDAP provider

1. In the left sidebar, click **User federation**
2. Click **Add provider**
3. Select **LDAP** (or **Kerberos** for Kerberos-only setups)
4. Fill in:

| Field | Value (example) |
|-------|-----------------|
| **Console display name** | `Company AD` |
| **Vendor** | `Active Directory` |
| **Connection URL** | `ldap://ad.yourcompany.com:389` (or `ldaps://...:636`) |
| **Bind type** | `simple` |
| **Bind DN** | `CN=Keycloak Service,OU=Service Accounts,DC=yourcompany,DC=com` |
| **Bind credentials** | Password of the bind user |
| **Edit mode** | `READ_ONLY` (so Keycloak doesn't modify AD) |
| **Users DN** | `OU=Users,DC=yourcompany,DC=com` |
| **Username LDAP attribute** | `sAMAccountName` |
| **User object classes** | `person, organizationalPerson, user` |

5. Click **Test connection** — should say "Success"
6. Click **Test authentication** — should say "Success"
7. Click **Save**

### 5.2 Sync users

1. On the LDAP provider page, scroll to the bottom
2. Click **Synchronize all users**
3. Wait for the confirmation (e.g., "Sync of users finished successfully: 42 users synchronized")

Your AD users are now in Keycloak. They can log in with their AD credentials.

### Microsoft Entra ID / Azure AD

If you use Microsoft Entra ID (formerly Azure AD), use the **Identity Providers** feature instead of LDAP:
1. In the left sidebar, click **Identity providers**
2. Click **Add provider → OpenID Connect v1.0**
3. Configure with your Entra ID app registration
4. Users from Entra ID can then log in via "Sign in with Microsoft"

---

## 6. Log in to TicketBrainy with your Keycloak user

Now test the integration.

1. Open TicketBrainy in your browser (e.g., `http://YOUR_SERVER_IP:4000`)
2. On the login page, click **Sign in with Keycloak**
3. You're redirected to the Keycloak login page
4. Enter your Keycloak credentials (e.g., `alice@yourcompany.com` / `TestPass123!`)
5. You're redirected back to TicketBrainy

**First login:** The user is created in TicketBrainy as an **inactive AGENT**. You need to activate them before they can access the app.

---

## 7. Activate users in TicketBrainy

New Keycloak users need admin approval in TicketBrainy before they can log in.

### As the TicketBrainy admin

1. Log in to TicketBrainy with the local admin account (`admin@ticketbrainy.local`)
2. Go to **Settings > Team**
3. You should see the new user (`alice@yourcompany.com`) with status **Inactive**
4. Click the toggle to activate them
5. Optionally change their role from **AGENT** to **SUPERVISOR** or **ADMIN**

### Bulk sync all Keycloak users

Instead of waiting for users to log in one by one, you can pre-import them:

1. In TicketBrainy, go to **Settings > Team**
2. Click **Sync Keycloak Users**
3. All users from your Keycloak realm are imported (as inactive)
4. Activate the ones who should have access

**Core plan limit:** Maximum 3 active users. Upgrade to **Enterprise Pack** for unlimited users.

---

## 8. Customize the login theme

TicketBrainy ships with a custom Keycloak theme that matches your brand.

### Enable the theme

1. In Keycloak admin, switch to the `ticketbrainy` realm (if not already)
2. In the left sidebar, click **Realm settings**
3. Click the **Themes** tab
4. Set **Login theme** to `ticketbrainy`
5. Click **Save**

Now when users access the Keycloak login page, they see the TicketBrainy branding instead of the default Keycloak look.

---

## 9. Troubleshooting

### "Sign in with Keycloak" button doesn't appear

The button only shows on the login page if Keycloak is configured in `.env`:

```bash
grep KEYCLOAK_URL .env
```

If empty, either:
- Run `bash install.sh` again and enable Keycloak
- Or manually edit `.env` and set `KEYCLOAK_URL`, then `docker compose restart web`

### Keycloak login page shows but redirect fails

The redirect URI must match exactly. Check in Keycloak:
1. **Clients > ticketbrainy-web > Settings**
2. **Valid redirect URIs** should include your TicketBrainy URL + `/api/auth/callback/keycloak`

Example: `http://192.168.1.50:4000/api/auth/callback/keycloak`

### "Invalid redirect URI" error

Same as above — the URI in Keycloak doesn't match the one TicketBrainy is sending.

Check in Keycloak:
- **Clients > ticketbrainy-web > Settings > Valid redirect URIs**

Add both URIs:
- `http://YOUR_SERVER_IP:4000/api/auth/callback/keycloak` (LAN access)
- `https://support.yourcompany.com/api/auth/callback/keycloak` (public access)

### User can log in to Keycloak but is blocked in TicketBrainy

The user is **inactive** in TicketBrainy. An admin must activate them in **Settings > Team**.

### Admin forgot the Keycloak admin password

```bash
cd ticketbrainyApp
grep KC_ADMIN_PASSWORD .env
```

If the password is empty or unknown, you can reset it by recreating the Keycloak container:

```bash
# WARNING: This wipes Keycloak data including users
docker compose rm -f keycloak
docker volume rm ticketbrainyapp_pg-data  # Only if you want a full reset
# Regenerate a new KC_ADMIN_PASSWORD in .env, then:
docker compose up -d keycloak
```

### View Keycloak logs

```bash
docker compose logs -f keycloak
```

Common errors:
- **Database connection refused**: PostgreSQL not ready. Wait 30s and restart Keycloak.
- **Schema not found**: The `keycloak` schema wasn't created. Verify `keycloak/init-schema.sql` mounted correctly in the db container.
- **Bootstrap admin password missing**: `KC_ADMIN_PASSWORD` is empty in `.env`.

---

## Next steps

- **Customize the login page** — see the `keycloak/themes/ticketbrainy/` directory in the install kit
- **Add more identity providers** — Google, GitHub, Entra ID, SAML (Keycloak admin → Identity providers)
- **Configure MFA** — Keycloak admin → Authentication → Flows → Browser (add OTP)
- **Audit logs** — Keycloak admin → Events → Config → enable events

For more advanced Keycloak configuration, see the [official Keycloak documentation](https://www.keycloak.org/documentation).
