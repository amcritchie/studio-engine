# Changelog

The format is [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). This project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html) — `MAJOR.MINOR.PATCH`. Consumer Rails apps install the released RubyGems package with `gem "studio-engine", "~> 0.6"`; bumping the gem version and updating consumer lockfiles is a release.

## Unreleased

## v0.6.0 (2026-06-16)

### Changed
- Require `tailwindcss-rails ~> 4.5` so Studio apps can move onto the
  Tailwind CSS v4 build chain together.

## v0.5.10 (2026-06-15)

### Added
- **`Studio::AdminModels`** shared controller concern plus shared admin model
  index/show shells and teams/arenas table partials. Consumer apps define their
  model registry and scopes locally, while shared pagination, team sorting,
  sport emoji display, team JSON modal payloads, and model page framing live in
  the engine.
- **Shared operator primitives** under `studio/banners/*` for non-production
  environment banners, the shared banner button, Dev Mode controls, email
  connector status, and admin impersonation banners. Consumers can render
  `studio/banners/environment` and `studio/banners/impersonation`.
- **`Studio::Impersonation`** opt-in concern for Act As session conventions:
  `true_user`, `impersonated_user`, `impersonating?`,
  `start_impersonation_session`, and `clear_impersonation_session`. Consumer
  apps still own authorization, audit logging, routes, and app-specific safety
  rules.
- **`StudioEmailDeliveryHelper#email_delivery_banner_details`** returns the
  structured connector, provider icon, send/capture state, and tooltip used by
  the shared email status button.

## v0.5.9 (2026-06-14)

### Added
- **`bin/rails "email:smoke[to@example.com]"`** — shared provider smoke-test
  task that sends one direct ActionMailer message through the current transport
  and prints the app, sender, transport, delivery method, `perform_deliveries`,
  external-send status, and message id. It refuses capture/test/file modes by
  default so agents do not mistake swallowed mail for a provider proof.

## v0.5.8 (2026-06-14)

### Added
- **`StudioEmailDeliveryHelper#email_delivery_banner_status`** — shared
  non-production banner status text for whether the current process sends
  external email and which transport is active (`resend`, `ses`, `capture`, or
  the ActionMailer delivery method).

## v0.5.7 (2026-06-14)

### Added
- **`Studio.mailer_from_for_transport` / `Studio.marketing_from_for_transport`** —
  provider-aware sender helpers. SES-ready apps use app/domain-specific
  `MAILER_FROM` and `MARKETING_MAILER_FROM`; Resend fallback uses
  `RESEND_MAILER_FROM`, defaulting to `McRitchie Studio <team@mcritchie.studio>`
  so new apps can send during SES sandbox/presetup without verifying a second
  Resend domain.

### Fixed
- **`ses:check` / `ses:verify_domain` credential selection** now prefers
  `SES_AWS_ACCESS_KEY_ID` / `SES_AWS_SECRET_ACCESS_KEY` before falling back to
  generic `AWS_*` credentials, keeping SES account checks separate from
  consumer app S3/ImageCache IAM users.
- **`ses:verify_domain` existing identity handling** now accepts AWS SES's
  `already exist` response wording and falls back to reading the existing
  identity.

## v0.5.6 (2026-06-14)

### Added
- **`Studio.wallet_address_method` / `Studio.user_wallet_address(user)`** —
  shared wallet-address adapter for SSO/session awareness. Defaults support
  `wallet_address` and `solana_address`; apps can configure another method.

## v0.5.5 (2026-06-14)

### Added
- **Local email inbox** at `/_studio/local_emails` for non-production localhost requests. It lists recent outbox rows and exposes local proof links for magic-link, email-verification, wallet-export, and email-change emails.
- **`Studio.local_email_capture?`** — shared capture switch for local/worktree stacks. `LOCAL_EMAIL_CAPTURE=1` or `AGENT_WORKTREE=1` records delivery rows without enqueueing external sends.

## v0.5.4 (2026-06-14)

### Changed
- Engine magic links are now scanner-safe: emailed links land on an inert GET confirmation page, and the token is consumed only by the CSRF-protected POST from that page.
- Added the shared `magic_link_consume_path` route helper for consumer apps using engine-drawn auth routes.

## v0.5.3 (2026-06-14)

### Added
- **`Studio::Email.deliver`** — shared ActionMailer delivery entry point that uses an app-level `EmailDelivery` when present, the engine's namespaced durable outbox when installed, and raw `deliver_later` as a fallback.
- **`Studio::EmailDelivery` / `Studio::EmailDeliveryJob`** — namespaced durable delivery rows for apps that want shared audit, retry, and resend recovery without colliding with an existing top-level `EmailDelivery` model.
- **`studio_email_deliveries` migration template** — installable shared outbox table for new or migrating consumer apps.

### Changed
- Engine magic-link and passwordless signup controllers now send through `Studio::Email.deliver` instead of calling `deliver_later` directly.

## v0.5.2 (2026-06-13)

### Added
- **`Studio::MailTransport`** — shared ActionMailer transport selection for SES SMTP primary and Resend rollback.
- **`ses:check` / `ses:verify_domain`** — shared Rake tasks for SES credential and domain verification checks.
- **`bin/release-check`** — local preflight for Ruby syntax, engine unit tests, and optional gem packaging.

### Changed
- Engine release docs now describe the RubyGems flow and consumer lockfile adoption instead of the legacy git tag pinning flow.
- Runtime dependency ranges are now bounded for cleaner RubyGems releases while preserving the current Rails 7 / Solid Queue 1.x app stack.
- `resend` is declared as an engine runtime dependency so consumer apps can drop direct rollback dependencies after they bundle the release that includes `Studio::MailTransport`.

## v0.5.1 (2026-06-02)

Smooths the turf-monster adoption of the v0.5.0 auth core (turf already ships its own battle-tested auth routes).

### Added
- **`Studio.draw_auth_routes`** (default `true`) — gates the `magic_link` + `solana` route block in `Studio.routes`. An app that already defines those routes (turf-monster) sets it `false` to keep its own routes and avoid a duplicate route-NAME boot crash.

### Changed
- **`MagicLink`** re-exposes `TOKEN_KEY` + `TTL` constants (equal to the config defaults) for back-compat with consumer code/tests that reference them; behavior is still driven by `Studio.magic_link_token_name` / `Studio.magic_link_ttl`.

## v0.5.0 (2026-06-02)

Promotes the **shared authentication core** out of Turf Monster into the engine so every Studio app runs one passwordless-first auth flow. This release is the **backend** half (services, POROs, concern helpers, base controllers, mailer); the shared wallet JS + Connect-Wallet modal land with the first consumer wiring. Turf Monster is **not** on this version yet — it stays on 0.4.x until its incremental migration.

### Added
- **`Studio.auth_methods`** config (default `%i[magic_link google wallet]`; `:password` opt-in) + `Studio.auth_method?(m)`. Login/signup surfaces render a field/button per enabled method. `:password` also re-arms the `User#authenticate` contract check.
- **`Studio.magic_link_ttl`** (15 min), **`Studio.magic_link_token_name`** (`"magic_link_v1"`), **`Studio.mailer_from`** config.
- **`SessionContext`** PORO — canonical guest/web2/web3 viewer state (`mode`, `to_h` camelCase for `Alpine.store('session')`). Wallet predicates are `respond_to?`-guarded so a wallet-less app is safe.
- **`Current`** baseline (`attribute :user`) — apps needing more request-scoped state override the file.
- **`MagicLink`** service — signed, single-use (jti in `Rails.cache`), URL-safe token; token name/TTL from config.
- **`GoogleOauthValidator`** — server-side `tokeninfo` re-check (audience / email_verified / expiry).
- **`Solana::SessionAuth`** concern — Rails-session adapter over `solana-studio`'s `Solana::AuthVerifier` (nonce delete-before-verify + host binding). solana-studio is host-provided; only loaded when wallet sign-in is on.
- **Base controllers** (generic; apps override for richer flows): `MagicLinksController` (create-or-login), `SolanaSessionsController` (nonce/verify), and an upgraded `OmniauthCallbacksController` (now runs `GoogleOauthValidator`).
- **`UserMailer#magic_link`** + `ApplicationMailer` (proc `from:` ← `Studio.mailer_from`) + app-name-aware templates.
- **Routes**: `Studio.routes` now draws `magic_link_request`/`magic_link` (when `:magic_link`) and `solana_nonce`/`solana_verify` (when `:wallet`), gated by `auth_method?`.

### Concern (`Studio::ErrorHandling`)
- `set_app_session` now binds a rotating `session[:session_token]` (OPSEC-045, guarded) and resets the `:onchain` flag; `clear_app_session` wipes both.
- `require_authentication` is now **format-aware** (HTML→redirect, JSON/Turbo→401, was a blind redirect that 406'd AJAX — OPSEC-046).
- New helpers: `set_current_context`, `verify_session_token` (guarded), `onchain_session?`, `wallet_context`, `client_session_payload` (identity-only baseline; apps override to merge balances).

### Breaking / Migration
- **`User.from_omniauth` contract is now `(auth, email_verified:)`** — the engine `OmniauthCallbacksController` passes the `GoogleOauthValidator` result. Consumers using the engine callback must update their `from_omniauth` to accept the kwarg.
- Consumers enabling `:magic_link` / `:wallet` must provide the User class methods the base controllers call (`User.find_by(email:)`, `User.from_solana_wallet(addr)`), the relevant columns (`email`, `email_verified_at`, `solana_address`, optional `session_token`), and `default_url_options` for mailer link generation.

## v0.4.13 (2026-06-02)

Promotes `components/_avatar_cropper` onto the shared crop-photo modal — completing the image-upload extraction started in v0.4.12. The avatar cropper is the **deferred-form-field** counterpart to `imageUploadHost`: it stages a cropped PNG on a hidden file input + shows a round preview, and the enclosing form (signup / profile edit) submits later (vs. `imageUploadHost`, which submits immediately).

### Changed
- **`components/_avatar_cropper`** now drives its crop through the shared `crop-photo` modal (`Alpine.store('modals').open('crop-photo', { imageUrl })`) and renders `studio/cropper_assets`, replacing the old bespoke `z-[110]` overlay + direct cropper.js load + the `avatarCropper()` factory (now `avatarCropperHost()`). The parent gets the cropped Blob back via the `crop-photo-confirmed` window event.

### Integration
Consumers rendering `components/avatar_cropper` now need the v0.4.12 image-upload integration: the `crop-photo` modal registered in the modal-host block (see v0.4.12 → Integration). The partial renders `studio/cropper_assets` itself, so cropper.js + the factories load where it's used.

### Migration
Apps that kept a local override of `components/_avatar_cropper` to route it through the shared modal (Turf Monster) can **delete the override** and use this.

## v0.4.12 (2026-06-02)

Promotes the image crop-and-upload UI out of Turf Monster into the engine: a shared cropper modal, the immediate-save upload host, the loading-card-around-a-Turbo-submit helper, and the generic "saving" card. Any consumer can now add a cropped image upload (avatar, banner, logo, OG image) with one `imageUploadHost(...)` x-data plus the cropper assets partial — no bespoke JS.

### Added
- **`studio/_cropper_assets`** — cropper.js (1.6.2) CSS + JS **and** the three inline factories below. Render it on pages that can open the cropper (avatar field, banner editor); both the library and the behavior load only where an upload trigger exists. The JS rides with the page, **not** the modal host, so it works whether or not an app overrides `studio/modals/_host`.
  - `window.imageUploadHost(opts)` — x-data host for crop-then-immediate-save uploaders. `open()` (modal-as-picker) / `onFileSelected()` (native picker) → `applyCrop()` drops the Blob into a hidden form input and submits with a loading card + toast.
  - `window.submitFormWithProgress(form, opts)` — opens the `saving` card, holds ≥450ms, submits the Turbo form, then closes + toasts on `turbo:submit-end`.
  - `window.cropPhotoModal(opts)` — the crop modal's x-data factory.
- **`studio/modals/_crop_photo`** — the shared image cropper modal. Opens via `Alpine.store('modals').open('crop-photo', { imageUrl?, aspectRatio?, maxWidth?, maxHeight?, transparent?, autoCropArea?, dispatch? })`; hands the cropped Blob back via the `crop-photo-confirmed` window event.
- **`studio/modals/_saving`** — generic loading card (title from `props.title`), opened by `submitFormWithProgress`.

### Integration
Register the two modals in your `studio/modals/host` block + render the assets on each upload page:
```erb
<%# inside the studio/modals/host block %>
<template x-if="$store.modals.current().id === 'crop-photo'"><%= render "studio/modals/crop_photo" %></template>
<template x-if="$store.modals.current().id === 'saving'"><%= render "studio/modals/saving" %></template>

<%# on each page with an image upload %>
<%= render "studio/cropper_assets" %>
<div x-data="imageUploadHost({ aspectRatio: 1, filename: 'avatar.png', saving: 'Saving photo…', dismissible: true, toast: false })"
     @crop-photo-confirmed.window="applyCrop($event.detail.blob)"> … hidden form (x-ref form + fileInput) + trigger … </div>
```
Registrations live in the host **block** (the consumer's `yield` content), so apps that override `studio/modals/_host` — like Turf Monster, which has a substantially diverged host — integrate the same way.

### Migration
For an app that had its own copies (Turf Monster):
1. `bundle update studio-engine`.
2. Delete the local `crop_photo_modal.js` (+ its importmap pin / `application.js` import), the `imageUploadHost` + `submitFormWithProgress` definitions, and `modals/_crop_photo` / `modals/_saving` / `shared/_cropper_assets`.
3. Point the host block's crop-photo / saving registrations at `studio/modals/crop_photo` / `studio/modals/saving`, and the cropper-asset renders at `studio/cropper_assets`.

## v0.4.11 (2026-05-24)

Preserves non-dismissible modals (e.g. pending on-chain TX) across bfcache restore and Turbo snapshot caching. Previously, the modal host's cleanup hooks called `closeAll()` on both `pageshow.persisted` and `turbo:before-cache`, which silently dropped any `dismissible: false` modal — including the processing card a still-in-flight JS promise was expecting to resolve against. The promise's `solanaModal.success()` then no-op'd against an empty stack and the user saw nothing despite their TX landing on-chain.

### Added
- **`Alpine.store('modals').closeAllDismissible()`** — drops every modal in the stack whose `props.dismissible !== false`, leaves locked modals in place.

### Changed
- **bfcache + Turbo snapshot cleanup** now calls `closeAllDismissible()` instead of `closeAll()`. Celebratory modals still clear on return; pending-TX modals survive.

### Migration
None required — celebratory modal behavior is unchanged. Consumers relying on `dismissible: false` (turf-monster's `onchain-tx` modal) gain crash-recovery for free.

## v0.4.10 (2026-05-23)

Lets consumer apps override toast z-indexes without `!important`. Previously, `#toast-container` set `z-index: 60` via an inline `style=` attribute, which forced any consumer override to use `!important`. Same source-order problem for `.toast-page-blur` (z-index in the inline `<style>` block here loaded after the consumer's `application.tailwind.css`). Both now read from CSS custom properties with the previous values as fallback defaults.

### Changed
- **`#toast-container`** z-index moved from inline `style=` to a CSS rule reading `var(--studio-toast-z, 60)`.
- **`.toast-page-blur`** z-index now reads `var(--studio-toast-blur-z, 55)`.

### Migration
None required — defaults preserve existing behavior. Apps that need higher z-indexes (e.g. to stack above a `z-50`/`z-110` sticky navbar) can now set the variables on `:root` in their stylesheet and drop their `!important` workaround:
```css
:root {
  --studio-toast-z: 120;
  --studio-toast-blur-z: 115;
}
```

## v0.4.9 (2026-05-23)

Modal success_card upgrades — canonical "celebration" look for any modal that needs an Entry / Action / Payment confirmed card. All options additive; existing callers unaffected.

### Added
- **`_success_card` — `large_title:`** boolean. Bumps the headline from `text-lg` to `text-3xl` (the celebration look).
- **`_success_card` — `title_key:` / `message_key:`** Alpine-expression locals for live-driven headline + subtitle. Lets a card track a store as labels mutate without re-mounting (paired with the same option on `_processing_card` in v0.4.6).
- **`_success_card` — `tx_solana:`** boolean. Upgrades the tx-signature explorer link from the plain underlined-hash style to a boxed pill with the Solana brand mark (gradient SVG, three diagonal bars) on the left and a launch arrow on the right. Same `tx_signature_key` Alpine expression drives both variants.
- **`_success_card` — `cta_drain:`** boolean. When paired with `auto_redirect_url_key`, the countdown drains as a translucent overlay on the CTA button itself — no separate progress bar / "Redirecting in Xs…" text. The celebration look. Uses the new `@keyframes studio-modal-drain` defined in the host's style block.
- **`_success_card` — yield block.** Callers can pass an inline block; the card renders it below the CTA. Used by turf-monster's onchain-tx modal to slot in the seeds-bar + level-up celebration without forking the partial.

### Migration
None required. Apps that don't set the new options keep the existing default look.

## v0.4.8 (2026-05-23)

Bugfix follow-up to v0.4.7. The v0.4.7 fix removed the ERB-escape example from the doc comment, but the same comment still referenced the bug it had just fixed using literal ERB-tag characters (the words "ERB <%# %> terminates at the first %> sequence" sit inside an ERB comment that uses `%>` as its terminator — recursive footgun). The first inline `%>` ended the outer comment and the rest leaked again.

### Fixed
- **`studio/modals/host` comment leak (v0.4.6 + v0.4.7).** Rewrote the doc comment to contain zero `%` characters; ERB now sees the entire block as a single comment. No API change.

## v0.4.7 (2026-05-23)

Bugfix — modal host doc-comment was leaking into rendered pages.

### Fixed
- **`studio/modals/host` comment block terminated early.** The leading comment in `_host.html.erb` contained a worked example of the consumer render-block syntax using literal ERB escape sequences. ERB scans for the first tag-close to close the comment, and the escape sequences end in one — so the comment terminated mid-escape, leaving the rest as literal output at the bottom of every page. (See v0.4.8 — this v0.4.7 fix was itself incomplete.)

## v0.4.6 (2026-05-23)

Small follow-up to 0.4.5 — modal dismissibility opt-out.

### Added
- **`props.dismissible: false`** on a modal's props now suppresses escape-key + click-outside close. Required for flows that mustn't be interrupted mid-step — on-chain TX while a Phantom signature is pending, multi-stage withdrawals, etc. Defaults to true (existing behavior). Set per-modal:
  ```js
  $store.modals.open('onchain-tx', { state: 'processing', dismissible: false });
  // ...later, when the TX confirms:
  $store.modals.current().props.dismissible = true;  // user can now close
  ```

## v0.4.5 (2026-05-23)

Modal infrastructure — same shape as the toast system from v0.4.0. Apps render `studio/modals/host` once, then open through `Alpine.store('modals')` and compose the shared content blocks. No migration required for v0.4.4 consumers.

### Added
- **`studio/modals/host` partial.** Single shared shell that bundles the scroll-lock CSS, bfcache/Turbo snapshot cleanup, `Alpine.store('modals')` registration (stack-based), `window.StudioModals.holdAtLeast(ms)` helper, and the modal markup (z-[120] backdrop, fade-and-scale transitions, escape/click-outside/ARIA dialog). Consumer renders once in `application.html.erb` with a block that registers their app-specific content partials by id:
  ```erb
  <%= render "studio/modals/host" do %>
    <template x-if="$store.modals.current().id === 'auth'">
      <%= render "modals/auth" %>
    </template>
  <% end %>
  ```
- **`Alpine.store('modals')` stack store.** API: `open(id, props, opts)` (with `opts.replace: true` for flicker-free transitions between steps in a wizard), `close()`, `closeAll()`, `isOpen(id)`, `current()`. Auto-syncs `body.modal-open` for scroll lock. Stack-based so modals can nest (e.g. confirm-on-top-of-form).
- **`window.StudioModals.holdAtLeast(ms)` helper.** Stamps the moment a loading view becomes visible, returns `{ then(callback) }` that delays the callback by the remaining time if the operation finished before the minimum. Replaces ad-hoc `Date.now() - startedAt` arithmetic at every async-success site. Mirrors `_navSpinnerMinMs` from `_head.html.erb`.
- **Four reusable content-block partials in `studio/modals/blocks/`.** Composable building blocks any modal can render to assemble its inner content:
  - `_success_card` — icon (default green check, or any emoji), title, optional sub-text, optional Solana tx-signature explorer link, primary CTA (href or dispatched event), secondary CTA, **self-driven auto-redirect countdown** (progress bar + "Xs…" text, fires `window.location.href` at zero), and **opt-in confetti** burst via `window.fireSuccessConfetti`.
  - `_error_card` — emoji icon (default ⏳, configurable for ⚠️ / 📍 / etc.), title, message (static string or Alpine-expression key for live updates), CTA that can reload the page, dispatch an event, or be omitted.
  - `_processing_card` — spinner (sm/md/lg, three color tokens) + title + optional message. Designed to pair with `holdAtLeast` on the caller side.
  - `_progress_countdown` — standalone progress bar + countdown text. Reads display values from caller-provided Alpine expressions so externally-driven countdowns (board's `setInterval` mutating `$store.modals` props) and internally-driven ones (success card's own timer) can share the same visualization.

### Architecture
- **Content vs. blocks.** Each consumer app owns its modal *content* partials (turf-monster's `modals/auth`, mcritchie-studio's account flows, etc.) because the flows are product-specific. The engine provides the *shell* (host) and the *building blocks* (cards) because those are universal UI vocabulary.
- **Single root requirement** on modal content partials — Alpine's `<template x-if>` clones only the first root element from its content. Top-level `<style>` blocks or stray siblings are silently dropped. Bake the style inside the partial's outer wrapping `<div>` if needed.

## v0.4.4 (2026-05-20)

Sticky-navbar scroll fixes — bounce-free for every consuming app, no migration required.

### Fixed
- **Navbar scroll-collapse bounce.** A `position: sticky` navbar that shrinks on scroll changes layout above the fold; Chrome/Firefox scroll-anchoring then compensates by moving `scrollY`, which re-crosses the collapse threshold and oscillates. `_head.html.erb` now ships `body { overflow-anchor: none }`, so the navbar resize no longer drags `scrollY`. Every app that renders `layouts/studio/head` gets this automatically.
- **Navbar unscroll threshold `20 → 5`** in `_navbar.html.erb` — widens the hysteresis dead zone (5/60) so a height change can't push `scrollY` back across the lower bound.

### Added
- **`--nav-h` CSS variable.** `_head.html.erb` ships a `ResizeObserver` that publishes the page header's live height to `--nav-h` on `:root` — updated on every resize (including the collapse animation) and re-attached after Turbo navigations. Fixed/sticky elements below the navbar can position off `var(--nav-h)` instead of hardcoded px (e.g. `style="top: var(--nav-h)"`). Auto-detects the page `<header>`; no markup changes needed.

## v0.4.3 (2026-05-19)

Tier-3 fix from the turf-monster pre-prod opsec audit (OPSEC-016).

### Fixed (security)
- **`GET /sso_login` no longer mutates the session (OPSEC-016).** The action previously called `authenticate_sso_user!` directly — starting a session on a GET. GETs are not CSRF-covered and are prefetchable (`<img>`, `<link rel=prefetch>`, browser prefetch), so an XSS on any `*.mcritchie.studio` subdomain that wrote `session[:sso_email]` could have a forged `/sso_login` hit silently start a session as that user. `sso_login` now only redirects to the login page; the session mutation happens exclusively through the CSRF-protected `POST /sso_continue` ("Continue as …" button).

### Changed
- The hub's one-click SSO link to a satellite's `/sso_login` now lands the user on the satellite login page with the "Continue as …" button instead of logging them in directly — one extra click, and the GET endpoint is no longer a session-mutation vector.

## v0.4.2 (2026-05-19)

Security follow-up to v0.4.1 — closes a cross-app session-fixation surface.

### Fixed (security)
- **Removed legacy `session[:user_id]` fallback in `Studio::ErrorHandling#current_user`** (OPSEC-042). Previously, if `session[Studio.session_key]` was empty but `session[:user_id]` was present, the engine would look up the user by that ID and silently call `set_app_session(user)` — promoting an arbitrary user ID to logged-in status. Combined with the shared `*.mcritchie.studio` cookie scope, any XSS on any subdomain that wrote `session[:user_id]` became cross-app login-as-anyone. The legacy key was a Devise-era migration carrier; consumer apps no longer write to it. Removing the fallback closes the fixation surface.

### Breaking
- Any user with a stale session that still has `session[:user_id]` set but NOT `session[Studio.session_key]` will be logged out on next request. Practically: nobody, since the engine has been writing `session[Studio.session_key]` since v0.2.x.

## v0.4.1 (2026-05-17)

Pre-public-release security hardening per `SECURITY-AUDIT-2026-05-17.md`.

### Fixed (security)
- **SSRF guard in `Studio::ImageCache.cache!`** — `source_url` is now validated: rejects schemes other than http/https, blocks loopback / private / link-local IPs (incl. AWS metadata 169.254.169.254), and blocks `localhost` / `*.local` / `*.internal` / `*.lan` hostnames. Raises `Studio::ImageCache::InvalidSourceURL`. Does not defend against DNS rebinding.
- **MIME-type allowlist in `Studio::ImageCache.cache!`** — `content_type` must be one of `ALLOWED_CONTENT_TYPES` (image/png|jpeg|jpg|webp|gif). Raises `Studio::ImageCache::UnsupportedContentType`.
- **MiniMagick resource caps per invocation** — every resize runs with `-limit memory 256MB -limit map 512MB -limit width/height 16KP` to prevent decompression-bomb DoS.
- **Remote source size cap** — `MAX_REMOTE_BYTES = 50MB`. Raises `Studio::ImageCache::SourceTooLarge` on overage.
- **`ErrorLog.capture!` no longer stores `exception.inspect`** — Ruby's default inspect for many error subclasses includes ivar dumps that can carry secrets (API keys read into locals, request bodies). Now stores a sanitized `"#<{class}: {message[0,1000]}>"` instead.

### Changed (breaking for misconfigured users only)
- **`Studio.s3_bucket_prefix` no longer defaults to `"mcritchie-studio"`.** Default is `nil`; host apps MUST set explicitly in `config/initializers/studio.rb`. Both current consumer apps already do this — no impact in practice.
- **`Studio.UserContractError` message** now points at the correct repo URL (`amcritchie/studio-engine`, not `amcritchie/studio`).

### Added
- `LICENSE` file (MIT) — gemspec already declared MIT but the file was missing. Required for RubyGems listing.
- Gemspec author email changed from `alex@mcritchie.studio` (personal) to `studio-engine@mcritchie.studio` (project alias).

## v0.4.0 (2026-05-17)

### Changed (breaking)
- **Gem renamed from `studio` to `studio-engine`.** Repo URL is now `github.com/amcritchie/studio-engine` (was `.../studio`). Consumers must update their `Gemfile`:
  ```ruby
  # Before:
  gem "studio", git: "https://github.com/amcritchie/studio.git", tag: "v0.3.1"
  # After:
  gem "studio-engine", git: "https://github.com/amcritchie/studio-engine.git", tag: "v0.4.0"
  ```
- The Ruby `Studio` module name is **unchanged** — all call sites (`Studio.configure`, `Studio::ErrorHandling`, `Studio::ImageCache`, etc.) keep working without code changes.
- Gem entry point at `lib/studio-engine.rb` (a thin `require_relative "studio"` shim) ensures `gem "studio-engine"` auto-requires correctly without a `require:` option in the Gemfile.

### Added
- `LICENSE`, gemspec `metadata` (homepage / source / bugs / changelog URIs), `spec.description`, `spec.required_ruby_version` — getting ready for RubyGems publishing.

## v0.3.1 (2026-05-17)

### Fixed
- `Studio.validate_user_contract!` no longer checks for `User#email` (or any column-style attribute). ActiveRecord defines column accessors lazily, so they don't appear on `.instance_methods` until first record access — leading to false-positive `Studio::UserContractError` raises at boot. Only explicitly-defined methods (`authenticate`, `admin?`, `display_name`, class `find_by`) are validated. DB columns are out of scope; missing columns fail the User table migration instead.

## v0.3.0 (2026-05-17)

### Added
- **Shared stage-* badge palette.** New scheme aliases on `app/views/components/_badge.html.erb`: `stage-fresh` (blue), `stage-shaping` (yellow), `stage-structured` (mint), `stage-refined` (emerald), `stage-cohered` (violet), `stage-shipped` (emerald), `stage-closed` (gray). Consumer apps' News + Content stage helpers can now resolve to a unified palette instead of each picking ad-hoc scheme names per stage. Closes ecosystem-audit Tier 1 #2.
- **`Studio.validate_user_contract!`** + boot-time validator hook in `Engine#after_initialize`. Verifies host's `User` class responds to required methods (`authenticate`, `admin?`, `email`, `display_name`, plus class `find_by`). Raises `Studio::UserContractError` with a clear pointer to `docs/USER_CONTRACT.md` when something's missing — replaces the previous cryptic `NoMethodError` at first request. Opt out per-app with `Studio.validate_user_contract = false`. Closes ecosystem-audit Tier 2 #16.
- **`docs/USER_CONTRACT.md`** — full reference for required + optional User methods, recommended DB columns, and a minimal compliant model example.
- **Sentry fan-out from `ErrorLog.capture!`.** When the host app has loaded `sentry-ruby` (and Sentry is initialized via DSN), every `ErrorLog.capture!` call also sends the exception to Sentry with `error_log_slug` as a tag for cross-reference. Apps without `sentry-ruby` are unaffected — the call is guarded with `defined?(::Sentry)`. Closes ecosystem-audit Tier 2 #15.

### Changed
- Stage badge color schemes are additive — existing `success/danger/warning/info/violet/primary/orange/emerald/gray/neutral` schemes unchanged.

### Notes
- Both current consumer apps (mcritchie-studio, turf-monster) already satisfy the new User contract — validator is a no-op for them.

## v0.2.4 (pre-2026-05-17)

Last release before formal versioning. Consumer apps tracked `git: main` until this point. v0.2.4 is the snapshot at the previous commit `ef738ff` ("Studio::ImageCache.cache! accepts source_path for local files"). Anything before that is in `git log`.
