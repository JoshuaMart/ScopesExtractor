# frozen_string_literal: true

require 'sinatra/base'
require 'json'

module ScopesExtractor
  # REST API for querying scopes data
  class API < Sinatra::Base
    configure do
      set :bind, Config.api_bind
      set :port, Config.api_port
      set :show_exceptions, false
      set :raise_errors, false
    end

    # Disable protection for test environment
    configure :test do
      disable :protection
    end

    before do
      content_type :json
      # Ensure database is connected
      unless Database.instance_variable_get(:@db)
        Database.connect
        Database.migrate
        Database.cleanup_old_history
      end
    end

    # GET / - List all scopes with optional filters
    # Query params:
    #   - platform: filter by platform name
    #   - type: filter by scope type (web, mobile, etc.)
    #   - bounty: filter by bounty status (true/false)
    #   - slug: filter by program slug
    #   - values_only: return only an array of scope values (true/false)
    get '/' do
      query = ScopesExtractor.db[:programs]
                             .join(:scopes, program_id: :id)
                             .select(
                               Sequel[:programs][:slug],
                               Sequel[:programs][:platform],
                               Sequel[:programs][:name].as(:program_name),
                               Sequel[:programs][:bounty],
                               Sequel[:scopes][:value],
                               Sequel[:scopes][:type],
                               Sequel[:scopes][:is_in_scope]
                             )

      # Apply filters
      query = query.where(Sequel[:programs][:platform] => params[:platform]) if params[:platform]
      query = query.where(Sequel[:scopes][:type] => params[:type]) if params[:type]
      query = query.where(Sequel[:programs][:bounty] => params[:bounty] == 'true') if params[:bounty]
      query = query.where(Sequel[:programs][:slug] => params[:slug]) if params[:slug]

      results = query.all

      # Return only values if requested
      if params[:values_only] == 'true'
        results.map { |r| r[:value] }.to_json
      else
        { scopes: results, count: results.size }.to_json
      end
    rescue StandardError => e
      status 500
      { error: e.message }.to_json
    end

    # GET /changes - Recent changes in history
    # Query params:
    #   - hours: number of hours to look back (default: 24)
    #   - platform: filter by platform name
    #   - type: filter by event type
    get '/changes' do
      hours = (params[:hours] || 24).to_i
      cutoff = Time.now - (hours * 3600)

      query = ScopesExtractor.db[:history]
                             .left_join(:programs, id: :program_id)
                             .where { Sequel[:history][:created_at] >= cutoff }
                             .select_all(:history)
                             .select_append(Sequel[:programs][:slug].as(:program_slug))

      # Apply filters
      query = query.where(Sequel[:history][:platform_name] => params[:platform]) if params[:platform]
      query = query.where(Sequel[:history][:event_type] => params[:type]) if params[:type]

      results = query.order(Sequel.desc(Sequel[:history][:created_at])).all
      { changes: results, count: results.size }.to_json
    rescue StandardError => e
      status 500
      { error: e.message }.to_json
    end

    # GET /wildcards - List all wildcard scopes
    # Query params:
    #   - platform: filter by platform name
    #   - values_only: return only an array of wildcard values (true/false)
    get '/wildcards' do
      query = ScopesExtractor.db[:programs]
                             .join(:scopes, program_id: :id)
                             .select(
                               Sequel[:programs][:slug],
                               Sequel[:programs][:platform],
                               Sequel[:programs][:name].as(:program_name),
                               Sequel[:programs][:bounty],
                               Sequel[:scopes][:value],
                               Sequel[:scopes][:type],
                               Sequel[:scopes][:is_in_scope]
                             )
                             .where(Sequel.like(Sequel[:scopes][:value], '\*%'))

      # Apply platform filter
      query = query.where(Sequel[:programs][:platform] => params[:platform]) if params[:platform]

      results = query.all

      # Return only values if requested
      if params[:values_only] == 'true'
        results.map { |r| r[:value] }.to_json
      else
        { wildcards: results, count: results.size }.to_json
      end
    rescue StandardError => e
      status 500
      { error: e.message }.to_json
    end

    # GET /exclusions - List all excluded/ignored assets
    get '/exclusions' do
      results = ScopesExtractor.db[:ignored_assets].order(Sequel.desc(:created_at)).all
      { exclusions: results, count: results.size }.to_json
    rescue StandardError => e
      status 500
      { error: e.message }.to_json
    end

    # Error handlers
    error 404 do
      content_type :json
      { error: 'Not found' }.to_json
    end

    error do
      content_type :json
      status 500
      { error: 'Internal server error' }.to_json
    end
  end
end
