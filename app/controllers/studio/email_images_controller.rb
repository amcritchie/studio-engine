module Studio
  # Admin page to manage the banner image on transactional emails (Studio::
  # EmailImage). One managed variant today (magic_link); the registry is the
  # extension point. Shared by every app — surfaced from each app's admin hub.
  class EmailImagesController < ApplicationController
    before_action :require_admin

    MAX_BYTES = 8.megabytes

    def index
      @variants = Studio::EmailImage.variants
    end

    # PATCH /admin/email_images/:variant — upload/replace a banner.
    def update
      variant = params[:variant].to_s
      return head :not_found unless Studio::EmailImage.known?(variant)

      file = params[:image]
      unless valid_image?(file)
        message = file.blank? ? "Choose an image to upload." : "Use a PNG, JPG, or WebP under 8 MB."
        return redirect_to admin_email_images_path, alert: message, status: :see_other
      end

      rescue_and_log do
        Studio::EmailImage.store(variant, io: file, content_type: file.content_type)
        redirect_to admin_email_images_path, notice: "#{Studio::EmailImage.label(variant)} banner updated."
      end
    rescue StandardError
      redirect_to admin_email_images_path, alert: "Couldn't save the image. Please try again.", status: :see_other
    end

    private

    def valid_image?(file)
      file.respond_to?(:content_type) &&
        file.content_type.to_s.start_with?("image/") &&
        file.respond_to?(:size) && file.size.to_i.positive? && file.size <= MAX_BYTES
    end
  end
end
