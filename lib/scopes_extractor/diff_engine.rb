# frozen_string_literal: true

module ScopesExtractor
  # rubocop:disable Metrics/ClassLength
  class DiffEngine
    def initialize(notifier: nil)
      @db = ScopesExtractor.db
      @notifier = notifier || Notifiers::Discord.new
    end

    def process_program(platform_name, fetched_program, skip_notifications: false)
      program_slug = fetched_program.slug

      # 1. Ensure program exists in DB
      existing_program = @db[:programs].where(slug: program_slug, platform: platform_name).first

      is_new_program = existing_program.nil?

      if is_new_program
        program_id = insert_new_program(platform_name, fetched_program)
      else
        program_id = existing_program[:id]
        update_program_if_changed(program_id, existing_program, fetched_program)
      end

      # 2. Sync Scopes
      # Skip individual notifications for new programs OR first sync
      skip_scope_notifications = is_new_program || skip_notifications
      scope_stats = sync_scopes(program_id, platform_name, fetched_program,
                                skip_notifications: skip_scope_notifications)

      # 3. Log event and notify about new program
      return unless is_new_program

      # Always log the event for history tracking
      log_event(
        program_id: program_id,
        platform_name: platform_name,
        program_name: fetched_program.name,
        event_type: 'add_program',
        details: 'Brand new program discovered'
      )

      # Only send Discord notification if not skipping notifications
      return if skip_notifications

      @notifier.notify_new_program(
        platform_name,
        fetched_program.name,
        fetched_program.slug,
        scope_stats: scope_stats
      )
    end

    def process_removed_programs(platform_name, fetched_slugs, skip_notifications: false)
      existing_programs = @db[:programs].where(platform: platform_name).all
      existing_slugs = existing_programs.map { |p| p[:slug] }

      removed_slugs = existing_slugs - fetched_slugs

      removed_slugs.each do |slug|
        program = existing_programs.find { |p| p[:slug] == slug }
        next unless program

        scopes_data = build_scopes_data(program[:id])

        # Skip notification if this is the first sync
        @notifier.notify_removed_program(platform_name, program[:name], slug) unless skip_notifications

        log_event(
          program_id: program[:id],
          platform_name: platform_name,
          program_name: program[:name],
          event_type: 'remove_program',
          details: 'Program no longer available',
          extra_data: { slug: slug, scopes: scopes_data }
        )

        @db[:programs].where(id: program[:id]).delete
      end
    end

    private

    def insert_new_program(platform_name, fetched_program)
      @db[:programs].insert(
        slug: fetched_program.slug,
        platform: platform_name,
        name: fetched_program.name,
        bounty: fetched_program.bounty,
        last_updated: Time.now
      )
    end

    def update_program_if_changed(program_id, existing_program, fetched_program)
      return if existing_program[:name] == fetched_program.name && existing_program[:bounty] == fetched_program.bounty

      @db[:programs].where(id: program_id).update(
        name: fetched_program.name,
        bounty: fetched_program.bounty,
        last_updated: Time.now
      )
    end

    def sync_scopes(program_id, platform_name, fetched_program, skip_notifications: false)
      existing_scopes = @db[:scopes].where(program_id: program_id).all
      existing_values = existing_scopes.map { |s| s[:value] }

      # Normalize and validate scopes
      filtered_scopes = filter_and_normalize_scopes(platform_name, fetched_program)
      fetched_values = filtered_scopes.map(&:value).uniq

      scope_stats = process_added_scopes(
        program_id,
        platform_name,
        fetched_program,
        existing_values,
        filtered_scopes,
        skip_notifications: skip_notifications
      )

      process_removed_scopes(program_id, platform_name, fetched_program, existing_values, fetched_values,
                             existing_scopes, skip_notifications: skip_notifications)

      scope_stats
    end

    def filter_and_normalize_scopes(platform_name, fetched_program)
      valid_scopes = []

      fetched_program.scopes.each do |scope|
        # Normalize the scope value
        normalized_values = Normalizer.normalize(platform_name, scope.value)

        normalized_values.each do |normalized_value|
          # Validate
          unless Validator.valid_web_target?(normalized_value, scope.type)
            handle_ignored_asset(platform_name, fetched_program, normalized_value, scope.type)
            next
          end

          # Create normalized scope
          valid_scopes << Models::Scope.new(
            value: normalized_value,
            type: scope.type,
            is_in_scope: scope.is_in_scope
          )
        end
      end

      valid_scopes
    end

    def process_added_scopes(program_id, platform_name, fetched_program, existing_values, filtered_scopes,
                             skip_notifications: false)
      fetched_values = filtered_scopes.map(&:value).uniq
      added = fetched_values - existing_values

      # Count scopes by type for new program notification
      scope_stats = Hash.new(0)

      added.each do |val|
        scope_obj = filtered_scopes.find { |s| s.value == val }
        insert_scope(program_id, scope_obj)

        # Count by type
        scope_stats[scope_obj.type] += 1

        # Skip individual notifications for new programs
        @notifier.notify_new_scope(platform_name, fetched_program.name, val, scope_obj.type) unless skip_notifications

        log_event(
          program_id: program_id,
          platform_name: platform_name,
          program_name: fetched_program.name,
          event_type: 'add_scope',
          details: val,
          scope_type: scope_obj.is_in_scope ? 'in' : 'out',
          category: scope_obj.type
        )
      end

      scope_stats
    end

    def process_removed_scopes(program_id, platform_name, fetched_program, existing_values, fetched_values,
                               existing_scopes, skip_notifications: false)
      removed = existing_values - fetched_values

      removed.each do |val|
        existing_scope = existing_scopes.find { |s| s[:value] == val }
        next unless existing_scope

        delete_scope(program_id, val)
        @notifier.notify_removed_scope(platform_name, fetched_program.name, val) unless skip_notifications

        log_event(
          program_id: program_id,
          platform_name: platform_name,
          program_name: fetched_program.name,
          event_type: 'remove_scope',
          details: val,
          scope_type: existing_scope[:is_in_scope] ? 'in' : 'out',
          category: existing_scope[:type]
        )
      end
    end

    def insert_scope(program_id, scope_obj)
      @db[:scopes].insert(
        program_id: program_id,
        value: scope_obj.value,
        type: scope_obj.type,
        is_in_scope: scope_obj.is_in_scope,
        created_at: Time.now
      )
    end

    def delete_scope(program_id, value)
      @db[:scopes].where(program_id: program_id, value: value).delete
    end

    def handle_ignored_asset(platform_name, fetched_program, value, type)
      existing = @db[:ignored_assets].where(
        platform: platform_name,
        program_slug: fetched_program.slug,
        value: value
      ).first

      return if existing

      # Get program_id from database
      program = @db[:programs].where(slug: fetched_program.slug, platform: platform_name).first
      return unless program

      @db[:ignored_assets].insert(
        platform: platform_name,
        program_slug: fetched_program.slug,
        value: value,
        reason: "Invalid format for #{type} scope",
        created_at: Time.now
      )

      @notifier.notify_ignored_asset(platform_name, fetched_program.name, value, 'Invalid format')

      log_event(
        program_id: program[:id],
        platform_name: platform_name,
        program_name: fetched_program.name,
        event_type: 'asset_ignored',
        details: value
      )
    end

    def build_scopes_data(program_id)
      scopes = @db[:scopes].where(program_id: program_id).all
      return { in: {}, out: {} } if scopes.empty?

      result = { in: {}, out: {} }

      scopes.each do |scope|
        scope_category = scope[:is_in_scope] ? :in : :out
        scope_type = scope[:type]

        result[scope_category][scope_type] ||= []
        result[scope_category][scope_type] << scope[:value]
      end

      result
    end

    def log_event(program_id:, platform_name:, program_name:, event_type:, details:, scope_type: nil, category: nil,
                  extra_data: nil)
      @db[:history].insert(
        program_id: program_id,
        platform_name: platform_name,
        program_name: program_name,
        event_type: event_type,
        details: details,
        scope_type: scope_type,
        category: category,
        extra_data: extra_data&.to_json,
        created_at: Time.now
      )
    end
  end
  # rubocop:enable Metrics/ClassLength
end
