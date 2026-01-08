# frozen_string_literal: true

module ScopesExtractor
  class DiffEngine
    def initialize
      @db = ScopesExtractor.db
      @notifier = ScopesExtractor.notifier
    end

    def process_program(platform_name, fetched_program)
      program_slug = fetched_program.slug

      # 1. Ensure program exists in DB
      existing_program = @db[:programs].where(slug: program_slug, platform: platform_name).first

      if existing_program.nil?
        # New Program!
        program_id = @db[:programs].insert(
          slug: program_slug,
          platform: platform_name,
          name: fetched_program.name,
          bounty: fetched_program.bounty,
          last_updated: Time.now
        )
        @notifier.notify_new_program(platform_name, fetched_program.name, program_slug)
        log_event(program_id, 'program_added', 'Brand new program discovered')
      else
        program_id = existing_program[:id]
        # Update program if name/bounty changed
        if existing_program[:name] != fetched_program.name || existing_program[:bounty] != fetched_program.bounty
          @db[:programs].where(id: program_id).update(
            name: fetched_program.name,
            bounty: fetched_program.bounty,
            last_updated: Time.now
          )
        end
      end

      # 2. Sync Scopes
      sync_scopes(program_id, fetched_program)
    end

    private

    def sync_scopes(program_id, fetched_program)
      existing_scopes = @db[:scopes].where(program_id: program_id).all
      existing_values = existing_scopes.map { |s| s[:value] }

      # Filter invalid junk scopes (auto-exclude)
      filtered_scopes = filter_invalid_scopes(fetched_program.platform, fetched_program)
      fetched_values = filtered_scopes.map(&:value).uniq

      # Added Scopes
      added = fetched_values - existing_values
      added.each do |val|
        scope_obj = filtered_scopes.find { |s| s.value == val }
        @db[:scopes].insert(
          program_id: program_id,
          value: val,
          type: scope_obj.type,
          is_in_scope: true,
          created_at: Time.now
        )
        @notifier.notify_new_scope(fetched_program.platform, fetched_program.name, val, scope_obj.type)
        log_event(program_id, 'scope_added', val)
      end

      # Removed Scopes (or rather, no longer present in fetch)
      removed = existing_values - fetched_values
      removed.each do |val|
        @db[:scopes].where(program_id: program_id, value: val).delete
        @notifier.notify_removed_scope(fetched_program.platform, fetched_program.name, val)
        log_event(program_id, 'scope_removed', val)
      end
    end

    def filter_invalid_scopes(platform_name, fetched_program)
      valid_scopes = []

      fetched_program.scopes.each do |s|
        unless Validator.valid_web_target?(s.value, s.type)
          handle_ignored_asset(platform_name, fetched_program, s)
          next
        end
        valid_scopes << s
      end

      valid_scopes
    end

    def handle_ignored_asset(platform_name, fetched_program, scope_obj)
      existing = @db[:ignored_assets].where(
        platform: platform_name,
        program_slug: fetched_program.slug,
        value: scope_obj.value
      ).first

      return if existing

      # Get program_id from database
      program = @db[:programs].where(slug: fetched_program.slug, platform: platform_name).first
      return unless program

      @db[:ignored_assets].insert(
        platform: platform_name,
        program_slug: fetched_program.slug,
        value: scope_obj.value,
        reason: 'Invalid format for web scope (missing *. or http/https)',
        created_at: Time.now
      )

      @notifier.notify_ignored_asset(platform_name, fetched_program.name, scope_obj.value, 'Invalid format')
      log_event(program[:id], 'asset_ignored', scope_obj.value)
    end

    def log_event(program_id, type, details)
      @db[:history].insert(
        program_id: program_id,
        event_type: type,
        details: details,
        created_at: Time.now
      )
    end
  end
end
