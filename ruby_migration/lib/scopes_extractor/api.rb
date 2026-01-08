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
      query = ScopesExtractor.db[:history]
                             .left_join(:programs, Sequel[:programs][:id] => Sequel[:history][:program_id])
                             .select(
                               Sequel[:history][:created_at],
                               Sequel[:programs][:platform],
                               Sequel[:programs][:name].as(:program_name),
                               Sequel[:history][:event_type],
                               Sequel[:history][:scope_type],
                               Sequel[:history][:category],
                               Sequel[:history][:details]
                             )
                             .order(Sequel.desc(Sequel[:history][:created_at]))

      # Filter by hours
      if params[:hours]
        hours = params[:hours].to_i
        query = query.where(Sequel[:history][:created_at] > Time.now - (hours * 3600))
      end

      # Filter by platform
      query = query.where(Sequel.ilike(Sequel[:programs][:platform], params[:platform])) if params[:platform]

      # Filter by event type
      query = query.where(Sequel[:history][:event_type] => params[:type]) if params[:type]

      # Limit to 100 by default if no time filter
      query = query.limit(100) unless params[:hours]

      # Transform to match original format
      results = query.all.map do |row|
        result = {
          timestamp: row[:created_at]&.iso8601,
          platform: row[:platform]&.capitalize,
          program: row[:program_name],
          change_type: row[:event_type],
          scope_type: row[:scope_type],
          category: row[:category],
          value: row[:details]
        }
        
        # For remove_program, parse scopes from details JSON
        if row[:event_type] == 'remove_program' && row[:details]
          begin
            scopes_data = JSON.parse(row[:details])
            result[:scopes] = scopes_data
            result[:value] = row[:program_name] # Use program name as value
          rescue JSON::ParserError
            # If parsing fails, keep details as-is
          end
        end
        
        result
      end

      results.to_json
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
