# Unified create-or-login email magic link (the passwordless email path).
#
#   POST /magic_link        — request a link (email [, return_to])
#   GET  /magic_link/:token — "Confirm sign-in" interstitial (does NOT consume)
#   POST /magic_link/:token — consume it: log in OR create the account
#
# create-or-login: clicking the link IS proof of email ownership, so an email
# that collides with a Google/wallet-only account that was never email-verified
# is safely logged in here and stamped email_verified_at (unlike from_omniauth,
# which refuses that collision precisely because it lacked this proof).
#
# This is the engine's GENERIC base. Apps that need richer post-consume routing
# (e.g. turf-monster's contest landing + picks rehydration + entry-tokens upsell)
# OVERRIDE this controller in the app and reuse the MagicLink service + the
# sign_in_existing / sign_up_new building blocks.
class MagicLinksController < ApplicationController
  include Studio::LinkConsumption

  skip_before_action :require_authentication
  layout false, only: :confirm

  # Respond uniformly for any well-formed email. Under create-or-login every
  # address is "valid" (it logs in or signs up), so there is nothing to
  # enumerate. A malformed email gets the same response with no mail sent.
  def create
    email = params[:email].to_s.strip.downcase
    if email.match?(URI::MailTo::EMAIL_REGEXP)
      token = issue_magic_link(email, safe_path(params[:return_to]))
      Studio::Email.deliver(UserMailer, :magic_link, email, token, to: email)
    end
    respond_to do |format|
      format.json { render json: { success: true } }
      format.html { redirect_to login_path, notice: "Check your inbox — we just emailed you a sign-in link." }
    end
  end

  # GET /magic_link/:token is deliberately inert. Email link scanners and link
  # preview clients frequently prefetch emailed URLs with GET/HEAD; if GET burned
  # the token, the human's first real click could already be invalid. The page
  # renders a CSRF-protected form that a browser auto-POSTs to #consume.
  def confirm
    # strict-origin strips the token-bearing path from subresource Referer
    # headers while preserving a usable Origin header for Rails' CSRF origin
    # check on the consume POST.
    response.set_header("Referrer-Policy", "strict-origin")
    @token = params[:token]
  end

  # POST /magic_link/:token is the authoritative consume. This is the only place
  # the single-use token is burned.
  def consume
    response.set_header("Referrer-Policy", "strict-origin")
    result = MagicLink.consume(params[:token])
    user = User.find_by(email: result.email)
    user ? sign_in_existing(user, result) : sign_up_new(result)
  rescue MagicLink::InvalidToken
    redirect_to login_path, alert: "That sign-in link is invalid or has expired. Request a fresh one below."
  end

  private

  # Mint a token in the configured store. Default :signed keeps the legacy
  # stateless MessageVerifier link (URL: /magic_link/<token>); :database mints a
  # Studio::Link row (URL: /l/<token>) — the short, unified scheme. The mailer
  # builds the matching URL (see UserMailer#magic_link). sign_in_existing /
  # sign_up_new / safe_path come from Studio::LinkConsumption.
  def issue_magic_link(email, return_to)
    if Studio.magic_link_store == :database
      Studio::Link.create_magic_link(email: email, return_to: return_to).token
    else
      MagicLink.generate(email: email, return_to: return_to)
    end
  end
end
