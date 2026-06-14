# Studio Engine Release Runbook

This repo publishes the shared `studio-engine` gem. Consumer apps pull released
versions from RubyGems with `gem "studio-engine", "~> 0.5"`.

Do not publish, push tags, deploy consumers, or rotate credentials from an
agent session without explicit approval.

## Current Release

The current published release used by local consumers is `v0.5.8`:

- `Studio::MailTransport` selects SES SMTP or Resend through ActionMailer.
- Shared `ses:check` and `ses:verify_domain` Rake tasks.
- `resend` is now a runtime dependency of the engine so consumers do not need
  to carry it directly after they bundle the release.
- `Studio::Email.deliver`, local email capture, scanner-safe magic links, and
  wallet-address adapters are available for consumers on `0.5.6`.
- `StudioEmailDeliveryHelper#email_delivery_banner_status` provides shared
  non-production mail-state banner text for consumers on `0.5.8`.

If additional engine changes are added before publish, review whether this
should remain a patch release or move to the next minor.

## Preflight

Run this before a release PR is considered ready:

```bash
cd /Users/alex/projects/studio-engine
bin/release-check
```

For a local package sanity check without writing artifacts into the repo:

```bash
bin/release-check --build
```

The build artifact is written to `/tmp/studio-engine-release-check/`.

## Release Checklist

1. Confirm the diff is limited to the intended engine changes.
2. Update `CHANGELOG.md` by moving the relevant `Unreleased` notes under the
   new version heading.
3. Bump `lib/studio/version.rb` to the same version.
4. Run `bin/release-check --build`.
5. Commit the version bump, changelog, and engine code together.
6. Publish the gem only after explicit approval:

```bash
gem push /tmp/studio-engine-release-check/studio-engine-<version>.gem
```

7. Create/push the matching git tag after the gem is published:

```bash
git tag v<version>
git push origin main --tags
```

## Consumer Adoption

Adopt the engine release in consumers after RubyGems shows the new version:

```bash
cd /Users/alex/projects/mcritchie-studio
bundle update studio-engine

cd /Users/alex/projects/turf-monster
bundle update studio-engine
```

Verify each `Gemfile.lock` resolves the published version. For the shared mail
transport release, the apps should resolve at least `studio-engine 0.5.2`.

Then run the consumer smoke checks:

```bash
# McRitchie Studio
cd /Users/alex/projects/mcritchie-studio
bin/rails -T ses
MAIL_TRANSPORT=ses SES_SMTP_USERNAME=user SES_SMTP_PASSWORD=pass SES_REGION=us-east-2 \
  bin/rails runner 'puts({delivery: ActionMailer::Base.delivery_method, host: ActionMailer::Base.smtp_settings[:address]}.inspect)'

# Turf Monster
cd /Users/alex/projects/turf-monster
bin/rails -T ses
SOLANA_SKIP_NETWORK_CHECK=true MAIL_TRANSPORT=ses SES_SMTP_USERNAME=user SES_SMTP_PASSWORD=pass SES_REGION=us-east-2 \
  bin/rails runner 'puts({delivery: ActionMailer::Base.delivery_method, host: ActionMailer::Base.smtp_settings[:address]}.inspect)'
```

Finally, prove the local apps still boot:

- McRitchie Studio: `http://localhost:3000/`
- Turf Monster: `http://localhost:3100/`

## Temporary Fallback Cleanup

Only remove the consumer fallbacks after both apps are bundled with the engine
release that contains `Studio::MailTransport`.

Cleanup candidates:

- Remove the local compatibility branch from each
  `config/initializers/studio_mail_transport.rb`.
- Remove each app's fallback `lib/tasks/ses.rake` once `bin/rails -T ses` shows
  the engine-provided tasks.
- Remove direct app-level `gem "resend"` rollback dependencies once the engine
  dependency is present and the apps no longer need local transport fallback
  code.

Keep `RESEND_API_KEY` available as an operational rollback until SES has proven
stable in production.
