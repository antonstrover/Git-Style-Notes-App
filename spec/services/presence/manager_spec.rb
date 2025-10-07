# frozen_string_literal: true

require "rails_helper"

RSpec.describe Presence::Manager do
  let(:note) { create(:note) }
  let(:alice) { create(:user, email: "alice@example.com") }
  let(:bob) { create(:user, email: "bob@example.com") }
  let(:manager) { described_class.new(note.id) }

  before do
    # Clear cache before each test
    Rails.cache.clear
  end

  describe "#add_user" do
    it "adds user to presence set" do
      result = manager.add_user(alice)

      expect(result).to include(hash_including(id: alice.id, email: alice.email))
    end

    it "does not duplicate user" do
      manager.add_user(alice)
      manager.add_user(alice)

      snapshot = manager.snapshot
      expect(snapshot.count { |u| u[:id] == alice.id }).to eq(1)
    end

    it "adds multiple users" do
      manager.add_user(alice)
      manager.add_user(bob)

      snapshot = manager.snapshot
      expect(snapshot.length).to eq(2)
      expect(snapshot.map { |u| u[:id] }).to contain_exactly(alice.id, bob.id)
    end

    it "generates initials for users" do
      result = manager.add_user(alice)

      expect(result.first[:initials]).to eq("AL")
    end

    it "logs user join" do
      expect(Rails.logger).to receive(:info).with("Presence: user #{alice.id} joined note #{note.id}")

      manager.add_user(alice)
    end
  end

  describe "#remove_user" do
    before do
      manager.add_user(alice)
      manager.add_user(bob)
    end

    it "removes user from presence set" do
      manager.remove_user(alice)

      snapshot = manager.snapshot
      expect(snapshot.length).to eq(1)
      expect(snapshot.first[:id]).to eq(bob.id)
    end

    it "handles removing non-existent user" do
      charlie = create(:user, email: "charlie@example.com")

      expect { manager.remove_user(charlie) }.not_to raise_error

      snapshot = manager.snapshot
      expect(snapshot.length).to eq(2)
    end

    it "logs user leave" do
      expect(Rails.logger).to receive(:info).with("Presence: user #{alice.id} left note #{note.id}")

      manager.remove_user(alice)
    end
  end

  describe "#snapshot" do
    context "when no users present" do
      it "returns empty array" do
        expect(manager.snapshot).to eq([])
      end
    end

    context "when users are present" do
      before do
        manager.add_user(alice)
        manager.add_user(bob)
      end

      it "returns array of user details" do
        snapshot = manager.snapshot

        expect(snapshot.length).to eq(2)
        expect(snapshot).to all(have_key(:id))
        expect(snapshot).to all(have_key(:email))
        expect(snapshot).to all(have_key(:initials))
      end

      it "includes correct user data" do
        snapshot = manager.snapshot
        alice_data = snapshot.find { |u| u[:id] == alice.id }

        expect(alice_data[:email]).to eq(alice.email)
        expect(alice_data[:initials]).to eq("AL")
      end
    end

    context "with different email formats" do
      let(:user1) { create(:user, email: "john.doe@example.com") }
      let(:user2) { create(:user, email: "jane_smith@example.com") }
      let(:user3) { create(:user, email: "bob-jones@example.com") }

      it "generates initials correctly" do
        manager.add_user(user1)
        manager.add_user(user2)
        manager.add_user(user3)

        snapshot = manager.snapshot

        expect(snapshot.find { |u| u[:id] == user1.id }[:initials]).to eq("JD")
        expect(snapshot.find { |u| u[:id] == user2.id }[:initials]).to eq("JS")
        expect(snapshot.find { |u| u[:id] == user3.id }[:initials]).to eq("BJ")
      end
    end
  end

  describe "#broadcast_presence" do
    before do
      manager.add_user(alice)
    end

    it "broadcasts presence event to note channel" do
      expect(ActionCable.server).to receive(:broadcast).with(
        "notes:#{note.id}",
        hash_including(
          type: "presence",
          note_id: note.id,
          users: array_including(
            hash_including(id: alice.id, email: alice.email, initials: "AL")
          )
        )
      )

      manager.broadcast_presence
    end
  end

  describe ".cleanup_stale_presence" do
    it "returns true (no-op with SolidCache TTL)" do
      expect(described_class.cleanup_stale_presence).to be true
    end
  end
end
