# frozen_string_literal: true

require 'sinatra/base'
require 'json'

module ScopesExtractor
  class Api < Sinatra::Base
    set :bind, '0.0.0.0'
    set :port, ENV.fetch('API_PORT', 4567)

    # Cleanup old history on API startup
    configure do
      Database.cleanup_old_history
    end

    before do
      content_type :json
    end

    # Endpoint /: Returns all programs and their scopes
    get '/' do
      programs = ScopesExtractor.db[:programs].all
      scopes = ScopesExtractor.db[:scopes].all.group_by { |s| s[:program_id] }

      result = programs.map do |prog|
        prog_scopes = scopes[prog[:id]] || []
        {
          id: prog[:id],
          slug: prog[:slug],
          platform: prog[:platform],
          name: prog[:name],
          bounty: [1, true].include?(prog[:bounty]),
          last_updated: prog[:last_updated],
          scopes: prog_scopes.map do |s|
            {
              value: s[:value],
              type: s[:type],
              is_in_scope: [1, true].include?(s[:is_in_scope])
            }
          end
        }
      end

      result.to_json
    end

    # Endpoint /changes: Returns implementation history
    get '/changes' do
      query = build_history_query
      results = query.all.map { |row| format_history_row(row) }
      results.to_json
    end

    def build_history_query
      query = ScopesExtractor.db[:history]
                             .select(
                               Sequel[:history][:created_at],
                               Sequel[:history][:platform_name],
                               Sequel[:history][:program_name],
                               Sequel[:history][:event_type],
                               Sequel[:history][:scope_type],
                               Sequel[:history][:category],
                               Sequel[:history][:details]
                             )
                             .order(Sequel.desc(Sequel[:history][:created_at]))

      query = apply_time_filter(query)
      query = apply_platform_filter(query)
      query = apply_type_filter(query)
      apply_default_limit(query)
    end

    def apply_time_filter(query)
      return query unless params[:hours]

      hours = params[:hours].to_i
      query.where(Sequel[:history][:created_at] > Time.now - (hours * 3600))
    end

    def apply_platform_filter(query)
      return query unless params[:platform]

      query.where(Sequel.ilike(Sequel[:history][:platform_name], params[:platform]))
    end

    def apply_type_filter(query)
      return query unless params[:type]

      query.where(Sequel[:history][:event_type] => params[:type])
    end

    def apply_default_limit(query)
      params[:hours] ? query : query.limit(100)
    end

    def format_history_row(row)
      result = {
        timestamp: row[:created_at]&.iso8601,
        platform: row[:platform_name]&.capitalize,
        program: row[:program_name],
        change_type: row[:event_type],
        scope_type: row[:scope_type],
        category: row[:category],
        value: row[:details]
      }

      parse_remove_program_scopes(result, row) if row[:event_type] == 'remove_program'
      result
    end

    def parse_remove_program_scopes(result, row)
      return unless row[:details]

      scopes_data = JSON.parse(row[:details])
      result[:scopes] = scopes_data
      result[:value] = row[:program_name]
    rescue JSON::ParserError
      # Keep details as-is if parsing fails
    end

    # Endpoint /wildcards: Returns unique sorted wildcard domains
    get '/wildcards' do
      query = ScopesExtractor.db[:scopes]
                             .join(:programs, Sequel[:programs][:id] => Sequel[:scopes][:program_id])
                             .where(Sequel[:scopes][:is_in_scope] => true)
                             .where(Sequel.like(Sequel[:scopes][:value], '*%'))

      query = query.where(Sequel.ilike(Sequel[:programs][:platform], params[:platform])) if params[:platform]

      wildcards = query.select(Sequel[:scopes][:value])
                       .distinct
                       .map { |row| row[:value] }
                       .sort

      wildcards.to_json
    end

    # Endpoint /exclusions: Returns ignored assets
    get '/exclusions' do
      exclusions = ScopesExtractor.db[:ignored_assets]
                                  .order(Sequel.desc(:created_at))
                                  .all

      exclusions.to_json
    end

    # Endpoint /assets/web/:platform: Returns unique web assets for a platform
    get '/assets/web/:platform' do
      platform = params[:platform].downcase

      assets = ScopesExtractor.db[:scopes]
                              .join(:programs, Sequel[:programs][:id] => Sequel[:scopes][:program_id])
                              .where(Sequel[:programs][:platform] => platform)
                              .where(Sequel[:scopes][:type] => 'web')
                              .where(Sequel[:scopes][:is_in_scope] => true)
                              .select_map(Sequel[:scopes][:value])
                              .uniq
                              .sort

      assets.to_json
    end

    run! if app_file == $PROGRAM_NAME
  end
end
