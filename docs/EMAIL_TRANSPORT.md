# Email Transport

`Studio::MailTransport` is the shared transactional email selector for Studio
apps. It keeps McRitchie Studio, Turf Monster, and future apps on one
ActionMailer transport contract.

`Studio::Email.deliver(...)` is the shared delivery entry point. It records a
durable outbox row before enqueueing delivery when the host app has either:

- an existing app-level `EmailDelivery` model, or
- the engine-provided `Studio::EmailDelivery` table installed.

If no durable adapter is available, it falls back to normal ActionMailer
`deliver_later` so apps can adopt the API before installing the outbox table.

## App Initializer

```ruby
# config/initializers/studio_mail_transport.rb
Studio::MailTransport.configure!
```

The app still owns `Studio.mailer_from` in `config/initializers/studio.rb`.
`MAILER_FROM` must belong to a domain verified by the selected provider.

## Selection Rules

| Env | Delivery method | Notes |
|-----|-----------------|-------|
| `MAIL_TRANSPORT=ses` plus `SES_SMTP_USERNAME` and `SES_SMTP_PASSWORD` | `:smtp` | Target transport. Uses AWS SES SMTP. |
| `MAIL_TRANSPORT=ses` without SES SMTP credentials | fallback | Logs a warning and continues to fallback. |
| `RESEND_API_KEY` with SES inactive | `:resend` | Rollback transport. |
| no transport env | existing default | Useful in dev/test shells that do not send real mail. |

Tests are intentionally skipped so app test suites can keep `:test` delivery.

## Required Env

```env
MAIL_TRANSPORT=ses
SES_REGION=us-east-2
SES_SMTP_USERNAME=...
SES_SMTP_PASSWORD=...
SES_SMTP_HOST=                 # optional, defaults from SES_REGION
SES_SMTP_PORT=587
RESEND_API_KEY=...             # rollback only
MAILER_FROM=noreply@example.com
```

## SES Tasks

Consumer apps get shared SES helper tasks through the engine:

```bash
bin/rails ses:check
bin/rails "ses:verify_domain[example.com]"
```

The tasks use `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and `SES_REGION` to
query SES account status and print DKIM records.

## Durable Delivery

New apps should install the engine migration before relying on durable delivery:

```bash
bin/rails railties:install:migrations
bin/rails db:migrate
```

The table is `studio_email_deliveries`; the model is `Studio::EmailDelivery`.
Use the facade from app code:

```ruby
Studio::Email.deliver(UserMailer, :magic_link, email, token, to: email, user: user)
```

`Studio::EmailDelivery.resend_unsent!` re-enqueues any unsent rows after a
provider or worker outage. Apps with an older top-level `EmailDelivery` model can
keep it during migration; `Studio::Email.deliver` will use that adapter first.
