# frozen_string_literal: true

# NotesChannel handles real-time collaboration features for a specific note
#
# Events broadcast from server:
#   - version_created: New version created by any collaborator
#   - presence: Current list of active users on the note
#   - typing: User is typing (ephemeral, 3-5s client display)
#   - conflict_notice: Base version mismatch detected
#
# Client actions:
#   - typing: Signal that user is currently typing (requires editor rights)
#
class NotesChannel < ApplicationCable::Channel
  # Called when client subscribes to this channel
  # Expects params: { note_id: <id> }
  def subscribed
    @note = Note.find_by(id: params[:note_id])

    unless @note
      reject
      return
    end

    # Authorize using Pundit
    unless authorized_to_view?
      reject
      Rails.logger.warn "NotesChannel: unauthorized subscription attempt by user #{current_user.id} for note #{params[:note_id]}"
      return
    end

    # Subscribe to the note's stream
    stream_from "notes:#{@note.id}"

    # Add user to presence and broadcast update
    @presence_manager = Presence::Manager.new(@note.id)
    @presence_manager.add_user(current_user)
    @presence_manager.broadcast_presence

    Rails.logger.info "NotesChannel: user #{current_user.id} subscribed to note #{@note.id}"
  end

  # Called when client unsubscribes or disconnects
  def unsubscribed
    return unless @note && @presence_manager

    # Remove user from presence and broadcast update
    @presence_manager.remove_user(current_user)
    @presence_manager.broadcast_presence

    Rails.logger.info "NotesChannel: user #{current_user.id} unsubscribed from note #{@note.id}"
  end

  # Client action: typing indicator
  # Restricted to users with editor rights
  def typing(data = {})
    return unless @note
    return unless authorized_to_edit?

    # Broadcast ephemeral typing event
    ActionCable.server.broadcast(
      "notes:#{@note.id}",
      {
        type: "typing",
        note_id: @note.id,
        user: {
          id: current_user.id,
          email: current_user.email
        },
        at: Time.current.iso8601
      }
    )
  end

  private

  def authorized_to_view?
    NotePolicy.new(current_user, @note).show?
  end

  def authorized_to_edit?
    # Editors and owners can signal typing
    # Viewers cannot (they're read-only)
    policy = NotePolicy.new(current_user, @note)
    policy.update? || editor?
  end

  def editor?
    @note.collaborators.exists?(user: current_user, role: "editor")
  end
end
