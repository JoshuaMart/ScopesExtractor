# frozen_string_literal: true

require 'sinatra/base'
require 'json'

module ScopesExtractor
  class Api < Sinatra::Base
    set :bind, '0.0.0.0'
    set :port, ENV.fetch('API_PORT', 4567)

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
      query = ScopesExtractor.db[:history]
                             .join(:programs, id: :program_id)
                             .select(
                               Sequel[:history][:id],
                               :program_id,
                               :name,
                               :platform,
                               :event_type,
                               :details,
                               Sequel[:history][:created_at]
                             )
                             .order(Sequel.desc(:created_at))

      # Filter by hours
      if params[:hours]
        hours = params[:hours].to_i
        query = query.where(Sequel[:history][:created_at] > Time.now - (hours * 3600))
      end

      # Filter by platform
      if params[:platform]
        query = query.where(Sequel.ilike(:platform, params[:platform]))
      end

      # Filter by event type
      if params[:type]
        query = query.where(event_type: params[:type])
      end

      # Limit to 100 by default if no time filter
      query = query.limit(100) unless params[:hours]

      query.all.to_json
    end

    # Endpoint /wildcards: Returns unique sorted wildcard domains
    get '/wildcards' do
      query = ScopesExtractor.db[:scopes]
                             .join(:programs, id: :program_id)
                             .where(is_in_scope: true)
                             .where(Sequel.like(:value, '*%'))

      if params[:platform]
        query = query.where(Sequel.ilike(:platform, params[:platform]))
      end

      wildcards = query.select(:value)
                       .distinct
                       .map(:value)
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
                              .join(:programs, id: :program_id)
                              .where(Sequel[:programs][:platform] => platform)
                              .where(Sequel[:scopes][:type] => 'web')
                              .where(is_in_scope: true)
                              .select_map(Sequel[:scopes][:value])
                              .uniq
                              .sort

      assets.to_json
    end

    run! if app_file == $PROGRAM_NAME
  end
end
