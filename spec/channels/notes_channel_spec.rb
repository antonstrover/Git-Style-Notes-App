# frozen_string_literal: true

require "rails_helper"

RSpec.describe NotesChannel, type: :channel do
  let(:alice) { User.find_by(email: "alice@example.com") || create(:user, email: "alice@example.com") }
  let(:bob) { User.find_by(email: "bob@example.com") || create(:user, email: "bob@example.com") }
  let(:note) { create(:note, owner: alice, visibility: "private") }

  before do
    stub_connection current_user: alice
  end

  describe "#subscribed" do
    context "when user has permission" do
      it "subscribes to the note stream" do
        subscribe note_id: note.id

        expect(subscription).to be_confirmed
        expect(subscription).to have_stream_from("notes:#{note.id}")
      end

      it "adds user to presence" do
        expect_any_instance_of(Presence::Manager).to receive(:add_user).with(alice)
        expect_any_instance_of(Presence::Manager).to receive(:broadcast_presence)

        subscribe note_id: note.id
      end
    end

    context "when user does not have permission" do
      before do
        stub_connection current_user: bob
      end

      it "rejects the subscription" do
        subscribe note_id: note.id

        expect(subscription).to be_rejected
      end

      it "does not add user to presence" do
        expect_any_instance_of(Presence::Manager).not_to receive(:add_user)

        subscribe note_id: note.id
      end
    end

    context "when note does not exist" do
      it "rejects the subscription" do
        subscribe note_id: 99999

        expect(subscription).to be_rejected
      end
    end

    context "when user is an editor" do
      before do
        create(:collaborator, note: note, user: bob, role: "editor")
        stub_connection current_user: bob
      end

      it "allows subscription" do
        subscribe note_id: note.id

        expect(subscription).to be_confirmed
      end
    end

    context "when note is public" do
      let(:note) { create(:note, owner: alice, visibility: "public") }

      before do
        stub_connection current_user: bob
      end

      it "allows subscription" do
        subscribe note_id: note.id

        expect(subscription).to be_confirmed
      end
    end
  end

  describe "#unsubscribed" do
    before do
      subscribe note_id: note.id
    end

    it "removes user from presence" do
      expect_any_instance_of(Presence::Manager).to receive(:remove_user).with(alice)
      expect_any_instance_of(Presence::Manager).to receive(:broadcast_presence)

      unsubscribe
    end
  end

  describe "#typing" do
    before do
      subscribe note_id: note.id
    end

    context "when user is owner" do
      it "broadcasts typing event" do
        expect { perform :typing }.to have_broadcasted_to("notes:#{note.id}").with(
          hash_including(
            type: "typing",
            note_id: note.id,
            user: hash_including(id: alice.id, email: alice.email)
          )
        )
      end
    end

    context "when user is editor" do
      let(:note) { create(:note, owner: alice) }

      before do
        create(:collaborator, note: note, user: bob, role: "editor")
        stub_connection current_user: bob
        subscribe note_id: note.id
      end

      it "broadcasts typing event" do
        expect { perform :typing }.to have_broadcasted_to("notes:#{note.id}").with(
          hash_including(
            type: "typing",
            note_id: note.id,
            user: hash_including(id: bob.id, email: bob.email)
          )
        )
      end
    end

    context "when user is viewer" do
      let(:note) { create(:note, owner: alice) }

      before do
        create(:collaborator, note: note, user: bob, role: "viewer")
        stub_connection current_user: bob
        subscribe note_id: note.id
      end

      it "does not broadcast typing event" do
        expect { perform :typing }.not_to have_broadcasted_to("notes:#{note.id}")
      end
    end

    context "when note is public and user is not owner" do
      let(:note) { create(:note, owner: alice, visibility: "public") }

      before do
        stub_connection current_user: bob
        subscribe note_id: note.id
      end

      it "does not broadcast typing event" do
        expect { perform :typing }.not_to have_broadcasted_to("notes:#{note.id}")
      end
    end
  end
end
