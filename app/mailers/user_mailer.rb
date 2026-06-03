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
    @magic_url = magic_link_url(token: token)
    mail(to: email, subject: "Your #{@app_name} sign-in link")
  end
end
