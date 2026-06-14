# Environment Variables Setup

`studio-engine` is a shared Rails engine. It does not own a global `.env` file
and should not document live secret values. Each consuming app owns its local
`.env` and production config vars. McRitchie Studio owns the cross-repo
credential inventory and 1Password item naming.

Start with:

- McRitchie Studio: `docs/agents/modules/credentials.md`
- McRitchie Studio: `docs/agents/modules/credential-inventory.md`
- McRitchie Studio: `docs/agents/system/house-burn-down.md`

## Local File Locations

Use per-app env files:

```text
/Users/alex/projects/mcritchie-studio/.env
/Users/alex/projects/turf-monster/.env
```

A parent `/Users/alex/projects/.env` may exist as legacy/bootstrap context, but
new docs and scripts should prefer app-local files unless a value is truly
cross-app and intentionally shared.

## Engine-Level Variables

The engine reads these values only through consumer apps.

| Variable | Used by | Notes |
| --- | --- | --- |
| `SECRET_KEY_BASE` or `RAILS_MASTER_KEY` | Rails session/cookie encryption | Apps that participate in shared SSO need compatible session secrets. Turf Monster intentionally isolates its money-app cookie. |
| `GOOGLE_CLIENT_ID` | Google OAuth consumers | Register each app callback URL in Google Cloud Console. |
| `GOOGLE_CLIENT_SECRET` | Google OAuth consumers | Keep per environment; never commit. |
| `MAIL_TRANSPORT` | Apps that send mail | `ses` is the target default; Resend remains rollback. |
| `SES_REGION` | SES transport | Defaults by app/provider convention if absent. |
| `SES_SMTP_USERNAME` | SES transport | From AWS SES SMTP credentials. |
| `SES_SMTP_PASSWORD` | SES transport | Pair for `SES_SMTP_USERNAME`. |
| `SES_AWS_ACCESS_KEY_ID` | SES helper tasks | SES-scoped IAM access key for `ses:check` and `ses:verify_domain`; keep separate from S3 `AWS_ACCESS_KEY_ID`. |
| `SES_AWS_SECRET_ACCESS_KEY` | SES helper tasks | Pair for `SES_AWS_ACCESS_KEY_ID`; never print the value. |
| `RESEND_API_KEY` | Resend rollback | Used only when SES is inactive or unavailable. |
| `MAILER_FROM` | Apps that send mail | Must belong to a domain verified by the selected provider. |

App-specific variables such as `SOLANA_ADMIN_KEY`, RPC URLs, AWS bucket names,
or product API keys belong in the owning app's docs and McRitchie Studio's
credential inventory. Do not copy wallet addresses or private key material into
engine docs.

## Example Consumer App `.env`

```env
RAILS_MASTER_KEY=...
GOOGLE_CLIENT_ID=...
GOOGLE_CLIENT_SECRET=...

MAIL_TRANSPORT=ses
SES_REGION=us-east-2
SES_SMTP_USERNAME=...
SES_SMTP_PASSWORD=...
SES_AWS_ACCESS_KEY_ID=...     # SES API checks only
SES_AWS_SECRET_ACCESS_KEY=... # SES API checks only
RESEND_API_KEY=... # rollback only
MAILER_FROM="My App <team@example.com>"
```

Turf Monster also needs Solana and wallet-encryption variables. Use its
`README.md`, `docs/LOCAL_STACK.md`, and McRitchie Studio credential inventory
for the current item names.

## Production

Set config vars per deployed app. Do not assume all apps share every credential.

```bash
heroku config:set GOOGLE_CLIENT_ID=... GOOGLE_CLIENT_SECRET=... --app mcritchie-studio
heroku config:set GOOGLE_CLIENT_ID=... GOOGLE_CLIENT_SECRET=... --app turf-monster-mainnet
heroku config:set MAIL_TRANSPORT=ses SES_REGION=us-east-2 --app mcritchie-studio
heroku config:set MAIL_TRANSPORT=ses SES_REGION=us-east-2 --app turf-monster-mainnet
```

Do not reuse an app's S3/ImageCache `AWS_ACCESS_KEY_ID` for SES verification
unless that credential was deliberately granted SES permissions. Prefer
`SES_AWS_ACCESS_KEY_ID` / `SES_AWS_SECRET_ACCESS_KEY` for SES helper tasks.

Use McRitchie Studio's recovery scripts to hydrate local env files from Heroku
and 1Password during a fresh-machine rebuild.

## Email Transport

Consumer apps should call:

```ruby
# config/initializers/studio_mail_transport.rb
Studio::MailTransport.configure!
```

See [`EMAIL_TRANSPORT.md`](EMAIL_TRANSPORT.md) for SES/Resend selection rules
and SES helper tasks.

## Security Notes

- `.env` files are gitignored and must never be committed.
- Use 1Password item names in docs and handoffs, not secret values.
- Keep app-specific secrets app-local unless a shared value is intentional.
- Rotating Rails session secrets logs users out; coordinate across apps that
  still rely on shared SSO behavior.
