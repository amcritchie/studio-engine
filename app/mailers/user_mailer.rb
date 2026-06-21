class UserMailer < ApplicationMailer
  # Passwordless sign-in link. `email` is a raw string (the recipient may not
  # have an account yet). Token is a signed MagicLink payload (email + return_to
  # + jti, single-use). Clicking the link logs the recipient in or creates their
  # account. App-name-aware so the same template serves every Studio app.
  #
  # Engine GENERIC base. An app needing richer copy (e.g. turf-monster's
  # contest-aware variant) defines its own UserMailer, which wins.
  def magic_link(email, token)
    @app_name  = Studio.app_name
    @magic_url = magic_link_url_for(token)
    mail(to: email, subject: "Your #{@app_name} sign-in link")
  end

  private

  # Match the emailed URL to Studio.magic_link_store: the short /l/<token> for
  # the :database scheme, the legacy /magic_link/<token> for :signed. The
  # request side (MagicLinksController#issue_magic_link) mints the matching token.
  def magic_link_url_for(token)
    Studio.magic_link_store == :database ? link_url(token: token) : magic_link_url(token: token)
  end
end
