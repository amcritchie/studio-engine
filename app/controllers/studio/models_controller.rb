# frozen_string_literal: true

module Studio
  # Serves the model-page protocol (see Studio::ModelPage). Admin-only: raw record
  # JSON can carry internal fields, so this is an operator/debug surface, not a
  # public one. require_authentication is inherited from the host app's
  # ApplicationController (Studio::ErrorHandling); require_admin gates on top.
  class ModelsController < ApplicationController
    before_action :require_admin
    before_action :load_page

    # GET /models/:model/:id — one record as JSON + a copy/paste console command.
    def show
      head :not_found unless @page.record
    end

    # GET /models/:model/random — bounce to a random record's page (fresh sample).
    def random
      record = @page.random_record
      return head(:not_found) unless record

      redirect_to studio_model_path(@page.model_key, @page.identifier_for(record))
    end

    private

    def load_page
      @page = Studio::ModelPage.new(params[:model], params[:id])
    rescue Studio::ModelPage::UnknownModel
      head :not_found
    end
  end
end
