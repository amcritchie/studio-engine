# Email Transport

`Studio::MailTransport` is the shared transactional email selector for Studio
apps. It keeps McRitchie Studio, Turf Monster, and future apps on one
ActionMailer transport contract.

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
