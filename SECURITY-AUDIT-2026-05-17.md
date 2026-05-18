# Security Audit — studio-engine

**Date:** 2026-05-17 (pre-publication)
**Scope:** Full code review + `gitleaks` git-history scan + `bundle-audit` dependency check
**Verdict:** **NEEDS FIXES before public RubyGems publication**

## TL;DR

3 HIGH-severity issues + 5 MEDIUM-severity issues + 2 LOW + a fistful of dev-env CVE noise. None are immediate exploits in the McRitchie production deployment (the consuming apps are private + trusted), but all matter once strangers can `gem install studio-engine`. Total estimated fix effort: **~2-4 hours**.

## Scan results

| Tool | Result |
|------|--------|
| `gitleaks` (full history, 141 commits) | ✅ No leaks found |
| `bundle-audit` (engine's own Gemfile.lock) | ⚠️ nokogiri 1.18.10 has 1 HIGH + 2 MEDIUM CVEs. **Dev-env only** — nokogiri isn't a runtime dep of this gem; comes via Rails in consumer apps. Fix: `bundle update nokogiri` in this repo's `Gemfile.lock`. |

## Findings

| # | Severity | Location | Issue | Recommendation |
|---|----------|----------|-------|----------------|
| 1 | HIGH | `lib/studio.rb:30` | Hardcoded S3 bucket prefix default `"mcritchie-studio"` — strangers install + auto-target McRitchie's buckets. | Require explicit `s3_bucket_prefix` config, no default. Raise at first S3 call if unset. |
| 2 | HIGH | `lib/studio.rb` (UserContractError message) | Hardcoded `github.com/amcritchie/studio` URL inside an error message that ships to all consumers. | Use the repo's own URL (`/amcritchie/studio-engine` post-rename) or a generic doc anchor that doesn't tie to a personal handle. |
| 3 | HIGH | `lib/studio/image_cache.rb` (`cache!` source-URL fetch) | SSRF: `URI.open(source_url)` with no validation. Attacker can pass `file://`, `gopher://`, internal IPs, link-local addrs, AWS instance metadata (`169.254.169.254`). | Whitelist `http://`/`https://` only; reject private IP ranges (10/8, 172.16/12, 192.168/16, 127/8, 169.254/16, ::1, fe80::/10). Use `Addressable::URI` + a SSRF guard or hand-roll a 30-line validator. |
| 4 | MEDIUM | `lib/studio/image_cache.rb` (ImageMagick path) | No `content_type` allowlist + no MiniMagick resource limits → decompression-bomb DoS. | Validate MIME against `image/{jpeg,png,webp,gif}`. Set `MiniMagick.cli_prefix = "convert -limit memory 100MB -limit map 200MB"` or equivalent. Optionally re-check magic bytes with `FastImage` post-download. |
| 5 | MEDIUM | `lib/studio.rb:30-31` | No validation that `s3_bucket_prefix` / `s3_region` are set before S3 calls. Silent deferral to first prod hit. | Validate in `Engine#after_initialize`. Fail loudly if either is unset/invalid. |
| 6 | MEDIUM | `app/models/error_log.rb` (`ErrorLog.capture!`) | Stores `exception.inspect` — which on some exceptions includes local-variable dumps containing API keys, passwords, tokens. Then this lands in DB *and* fans out to Sentry. | Strip `exception.inspect` to just the class + message, drop local-var dumps. Add doc warning in README. Recommend Sentry PII scrubbing rules. |
| 7 | MEDIUM | `studio-engine.gemspec` | `spec.email = ["alex@mcritchie.studio"]` — personal email exposed for spam once gem is public. | Use a public-facing alias (e.g. `studio-engine@noreply.mcritchie.studio`) or a GitHub-routed email. |
| 8 | MEDIUM | repo root | No `LICENSE` file. Gemspec declares MIT but the file is missing — RubyGems will accept the upload but external users see "no license file." | Add LICENSE (MIT text), commit, include in `spec.files`. |
| 9 | LOW | `lib/studio.rb` (`validate_user_contract!`) | Checks `respond_to?(:authenticate)` but not arity. A no-arg `authenticate` method passes validation then NoMethodErrors at runtime. | Add `instance_method(:authenticate).arity >= 1` check, with a clear error message. |
| 10 | LOW | `app/controllers/theme_settings_controller.rb` | No hex-color format validation on accepted params. Garbage input gets stored + breaks CSS. | Add `validates :primary, format: { with: /\A#[0-9a-fA-F]{6}\z/ }` (etc.) on `ThemeSetting`. |
| 11 | INFO | `app/controllers/error_logs_controller.rb` | ILIKE search is properly parameterized — no SQL injection. But docs should call out: error logs may contain PII; restrict admin access carefully. | Add a paragraph to README + `SECURITY.md`. |

## Pre-publish checklist

Block the RubyGems publish on these:

- [ ] **Fix HIGH 1**: remove `s3_bucket_prefix` default + add config-time validation
- [ ] **Fix HIGH 2**: rewrite UserContractError URL or use a runtime-derived path
- [ ] **Fix HIGH 3**: add SSRF guard to `ImageCache#cache!`
- [ ] **Fix MEDIUM 4**: MIME allowlist + MiniMagick resource limits
- [ ] **Fix MEDIUM 6**: scrub `exception.inspect` to drop locals
- [ ] **Fix MEDIUM 7**: gemspec email change
- [ ] **Fix MEDIUM 8**: add `LICENSE` file
- [ ] **Address bundle-audit**: `bundle update nokogiri` in this repo's Gemfile.lock

OK to defer (do post-publish):
- LOW 9 (arity check) — additive, no breaking change
- LOW 10 (hex color validator) — admin-only path, low blast radius
- INFO 11 (PII docs) — write into README naturally on next pass

## What the audit did NOT cover

- Static taint analysis (we don't have a Rails-aware tool installed)
- Brakeman scan — recommend running `brakeman` in the studio-engine dummy-app context if you add one
- 3rd-party security review

## Re-audit cadence

Re-run on every minor version bump, or before any release that touches `lib/studio/s3.rb`, `lib/studio/image_cache.rb`, `app/controllers/`, or `app/models/error_log.rb`.
