# frozen_string_literal: true

module Presence
  # Manages real-time presence tracking for notes using Rails cache (backed by SolidCache/Redis)
  # Users are tracked per note, and presence updates are broadcast via Action Cable
  class Manager
    PRESENCE_KEY_PREFIX = "presence:note:"
    PRESENCE_TTL = 30.minutes

    def initialize(note_id)
      @note_id = note_id
      @cache_key = "#{PRESENCE_KEY_PREFIX}#{note_id}"
    end

    # Add a user to the presence set for this note
    # Returns the updated user list
    def add_user(user)
      user_ids = fetch_user_ids
      user_ids << user.id unless user_ids.include?(user.id)
      store_user_ids(user_ids)

      Rails.logger.info "Presence: user #{user.id} joined note #{@note_id}"
      snapshot
    end

    # Remove a user from the presence set
    # Returns the updated user list
    def remove_user(user)
      user_ids = fetch_user_ids
      user_ids.delete(user.id)
      store_user_ids(user_ids)

      Rails.logger.info "Presence: user #{user.id} left note #{@note_id}"
      snapshot
    end

    # Get current presence snapshot with user details
    # Returns array of { id, email, initials }
    def snapshot
      user_ids = fetch_user_ids
      return [] if user_ids.empty?

      users = User.where(id: user_ids).select(:id, :email)
      users.map do |user|
        {
          id: user.id,
          email: user.email,
          initials: generate_initials(user.email)
        }
      end
    end

    # Broadcast presence update to the note's channel
    def broadcast_presence
      ActionCable.server.broadcast(
        "notes:#{@note_id}",
        {
          type: "presence",
          note_id: @note_id,
          users: snapshot
        }
      )
    end

    # Clean up stale presence (can be called periodically)
    def self.cleanup_stale_presence
      # SolidCache handles TTL automatically, so this is a no-op
      # Kept for potential future use with different cache backends
      true
    end

    private

    attr_reader :note_id, :cache_key

    def fetch_user_ids
      Rails.cache.read(cache_key) || []
    end

    def store_user_ids(user_ids)
      if user_ids.empty?
        Rails.cache.delete(cache_key)
      else
        Rails.cache.write(cache_key, user_ids, expires_in: PRESENCE_TTL)
      end
    end

    def generate_initials(email)
      # Extract name part before @ and generate initials
      name = email.split('@').first
      parts = name.split(/[._-]/)

      if parts.length >= 2
        "#{parts[0][0]}#{parts[1][0]}".upcase
      else
        name[0..1].upcase
      end
    end
  end
end
