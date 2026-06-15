module Studio
  module AdminModels
    extend ActiveSupport::Concern

    PREVIEW_LIMIT = 10
    PER_PAGE = 25
    TEAM_SORTS = {
      "team" => "LOWER(teams.name)",
      "sport" => "LOWER(COALESCE(teams.sport, ''))",
      "league" => "LOWER(COALESCE(teams.league, ''))"
    }.freeze
    SHARED_TABLE_KEYS = %w[teams arenas].freeze

    included do
      before_action :set_model_config, only: :show
      helper_method :team_sort_url, :team_sort_indicator, :team_sport_emoji,
                    :team_record_json, :admin_models_table_partial
    end

    def index
      @sections = admin_model_configs.map do |key, config|
        scope = admin_model_scope_for(key)
        {
          key: key,
          label: config.fetch(:label),
          description: config.fetch(:description),
          count: scope.count,
          records: scope.limit(PREVIEW_LIMIT)
        }
      end

      render "studio/admin_models/index"
    end

    def show
      @page = [params[:page].to_i, 1].max
      @total_count = @scope.count
      @total_pages = [(@total_count.to_f / PER_PAGE).ceil, 1].max
      @records = @scope.offset((@page - 1) * PER_PAGE).limit(PER_PAGE)

      render "studio/admin_models/show"
    end

    private

    def set_model_config
      @key = params[:key].to_s
      @config = admin_model_configs.fetch(@key) { raise ActiveRecord::RecordNotFound }
      @scope = admin_model_scope_for(@key)
    end

    def admin_model_configs
      self.class::MODELS
    end

    def admin_model_scope_for(_key)
      raise NotImplementedError, "#{self.class.name} must implement #admin_model_scope_for"
    end

    def team_sort_key
      TEAM_SORTS.key?(params[:sort].to_s) ? params[:sort].to_s : "team"
    end

    def team_sort_direction
      params[:direction].to_s == "desc" ? "desc" : "asc"
    end

    def team_sort_order
      direction = team_sort_direction == "desc" ? "DESC" : "ASC"
      expression = TEAM_SORTS.fetch(team_sort_key)
      Arel.sql("#{expression} #{direction}, LOWER(teams.name) ASC")
    end

    def team_sort_url(key)
      query = request.query_parameters.merge(
        "sort" => key,
        "direction" => team_sort_key == key && team_sort_direction == "asc" ? "desc" : "asc"
      )
      query.delete("page")

      "#{request.path}?#{query.to_query}"
    end

    def team_sort_indicator(key)
      return "" unless team_sort_key == key

      team_sort_direction
    end

    def team_sport_emoji(team)
      case team.sport.to_s
      when "football" then "🏈"
      when "soccer" then "⚽"
      when "basketball" then "🏀"
      when "baseball" then "⚾"
      when "hockey" then "🏒"
      else "•"
      end
    end

    def team_record_json(team)
      payload = team.attributes.merge("mascot" => team.mascot)
      payload["home_arena"] = team.home_arena&.attributes if team.respond_to?(:home_arena)

      JSON.pretty_generate(payload)
    end

    def admin_models_table_partial(key)
      shared_table_keys = if self.class.const_defined?(:SHARED_TABLE_KEYS, false)
        self.class::SHARED_TABLE_KEYS
      else
        SHARED_TABLE_KEYS
      end

      if shared_table_keys.map(&:to_s).include?(key.to_s)
        "studio/admin_models/#{key}_table"
      else
        "admin/models/#{key}_table"
      end
    end
  end
end
