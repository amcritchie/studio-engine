# Environment Variables Setup

All McRitchie apps share a single `.env` file at the project root for local development.

## File Location

```
/Users/alex/projects/.env
```

All apps use `dotenv-rails` which walks up the directory tree, so a `.env` at the parent level is loaded by every app in a subdirectory.

## Variables

| Variable | Used By | Source | How to Recreate |
|----------|---------|--------|-----------------|
| `SECRET_KEY_BASE` | All apps | `rails secret` | Run `rails secret` once, share across all apps. Must be identical for SSO shared cookies to work across `*.mcritchie.studio`. |
| `GOOGLE_CLIENT_ID` | All apps | Google Cloud Console | See [GOOGLE_AUTH_SETUP.md](GOOGLE_AUTH_SETUP.md). Go to [APIs & Services > Credentials](https://console.cloud.google.com/apis/credentials), create/find the OAuth 2.0 Client ID. |
| `GOOGLE_CLIENT_SECRET` | All apps | Google Cloud Console | Same location as Client ID — click the OAuth client to reveal the secret. |
| `MAIL_TRANSPORT` | Apps that send mail | `.env` / hosting config | `ses` for AWS SES, `resend` or unset for Resend rollback. |
| `SES_REGION` | Apps that send mail | AWS SES | Region for SES SMTP/API, currently `us-east-2`. |
| `SES_SMTP_USERNAME` | Apps that send mail | AWS SES SMTP credentials | Create SMTP credentials in SES for the verified sending domain. |
| `SES_SMTP_PASSWORD` | Apps that send mail | AWS SES SMTP credentials | Pair for `SES_SMTP_USERNAME`. |
| `RESEND_API_KEY` | Apps that send mail | Resend dashboard | Rollback transport while Resend remains available. |
| `MAILER_FROM` | Apps that send mail | Verified sending domain | Must belong to a domain verified by the active transport. |
| `ANTHROPIC_API_KEY` | Tax Studio | Anthropic Console | Go to [console.anthropic.com/settings/keys](https://console.anthropic.com/settings/keys), create an API key. Used for AI expense classification. |
| `SOLANA_ADMIN_KEY` | Turf Monster | Solana CLI | The base58-encoded keypair for the admin wallet (`F6f8h5y...`). Export with `solana config get keypair` then `cat` the file contents. See [SOLANA docs](../../turf-monster/docs/SOLANA.md). |

## Recreating From Scratch

### 1. Create the file

```bash
touch /Users/alex/projects/.env
```

### 2. SECRET_KEY_BASE

```bash
cd /Users/alex/projects/mcritchie-studio  # any Rails app
echo "SECRET_KEY_BASE=$(bin/rails secret)" >> /Users/alex/projects/.env
```

**Critical**: All apps must share the same `SECRET_KEY_BASE` for the shared session cookie (`_studio_session`) to work across `*.mcritchie.studio`. This enables SSO between apps.

### 3. Google OAuth

1. Go to [Google Cloud Console](https://console.cloud.google.com/apis/credentials)
2. Create a project (or use existing)
3. Create an OAuth 2.0 Client ID (Web application)
4. Add authorized redirect URIs for each app (see [GOOGLE_AUTH_SETUP.md](GOOGLE_AUTH_SETUP.md))
5. Copy Client ID and Client Secret into `.env`:

```env
GOOGLE_CLIENT_ID=your-client-id.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=GOCSPX-your-secret
```

### 4. Shared Email Transport

Apps call `Studio::MailTransport.configure!` from
`config/initializers/studio_mail_transport.rb`.

```env
MAIL_TRANSPORT=ses
SES_REGION=us-east-2
SES_SMTP_USERNAME=...
SES_SMTP_PASSWORD=...
MAILER_FROM=noreply@example.com
RESEND_API_KEY=... # rollback only
```

SES must be out of sandbox and the `MAILER_FROM` domain must be verified. Use
`bin/rails ses:check` and `bin/rails "ses:verify_domain[example.com]"` in a
consumer app.

### 5. Anthropic API Key

1. Go to [console.anthropic.com](https://console.anthropic.com/settings/keys)
2. Create an API key
3. Add to `.env`:

```env
ANTHROPIC_API_KEY=sk-ant-...
```

### 6. Solana Admin Key (Turf Monster only)

1. Generate or locate the admin keypair file
2. The key is the base58-encoded private key for wallet `F6f8h5yynbnkgWvU5abQx3RJxJpe8EoQmeFBuNKdKzhZ`
3. Add to `.env`:

```env
SOLANA_ADMIN_KEY=base58-encoded-keypair
```

## Production (Heroku)

Each Heroku app needs its own config vars. Set them per-app:

```bash
# Shared across all apps
heroku config:set SECRET_KEY_BASE=... --app mcritchie-studio
heroku config:set SECRET_KEY_BASE=... --app turf-monster

# Google OAuth (all apps that use it)
heroku config:set GOOGLE_CLIENT_ID=... GOOGLE_CLIENT_SECRET=... --app mcritchie-studio
heroku config:set GOOGLE_CLIENT_ID=... GOOGLE_CLIENT_SECRET=... --app turf-monster

# App-specific
heroku config:set ANTHROPIC_API_KEY=... --app tax-studio-app
heroku config:set SOLANA_ADMIN_KEY=... SOLANA_RPC_URL=... --app turf-monster
```

`DATABASE_URL` and `REDIS_URL` are set automatically by Heroku addons.

## Security Notes

- `.env` is gitignored — never committed to any repo
- The shared file approach means all apps on this machine have access to all keys
- Rotate `SECRET_KEY_BASE` = all users get logged out of all apps (session cookies invalidated)
- Rotate `GOOGLE_CLIENT_SECRET` = regenerate in Google Cloud Console, update `.env` and all Heroku apps
