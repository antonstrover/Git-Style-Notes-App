# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

puts "Seeding database..."

# Clean up existing data (for idempotency in development)
if Rails.env.development?
  puts "Cleaning up existing data..."
  Fork.delete_all
  Collaborator.delete_all
  Version.delete_all
  Note.delete_all
  User.delete_all
  puts "Cleanup complete."
end

# Create sample users
puts "Creating users..."
alice = User.create!(
  email: "alice@example.com",
  password: "password123",
  password_confirmation: "password123"
)

bob = User.create!(
  email: "bob@example.com",
  password: "password123",
  password_confirmation: "password123"
)

charlie = User.create!(
  email: "charlie@example.com",
  password: "password123",
  password_confirmation: "password123"
)

puts "Created #{User.count} users."

# Create notes with version history
puts "Creating notes with versions..."

# Alice's private note with multiple versions
note1 = Note.create!(
  title: "Alice's Research Notes",
  owner: alice,
  visibility: :private
)

v1 = Version.create!(
  note: note1,
  author: alice,
  content: "Initial research findings on versioned note systems.",
  summary: "Initial draft"
)
note1.update!(head_version: v1)

v2 = Version.create!(
  note: note1,
  author: alice,
  parent_version: v1,
  content: "Initial research findings on versioned note systems. Added section on immutability.",
  summary: "Added immutability section"
)
note1.update!(head_version: v2)

v3 = Version.create!(
  note: note1,
  author: alice,
  parent_version: v2,
  content: "Initial research findings on versioned note systems. Added section on immutability and conflict resolution.",
  summary: "Added conflict resolution"
)
note1.update!(head_version: v3)

# Bob's public note
note2 = Note.create!(
  title: "Open Source Best Practices",
  owner: bob,
  visibility: :public
)

v4 = Version.create!(
  note: note2,
  author: bob,
  content: "# Open Source Best Practices\n\n1. Document everything\n2. Write comprehensive tests\n3. Use semantic versioning",
  summary: "Initial version"
)
note2.update!(head_version: v4)

v5 = Version.create!(
  note: note2,
  author: bob,
  parent_version: v4,
  content: "# Open Source Best Practices\n\n1. Document everything\n2. Write comprehensive tests\n3. Use semantic versioning\n4. Respond to issues promptly",
  summary: "Added issue management tip"
)
note2.update!(head_version: v5)

# Charlie's link-visible note
note3 = Note.create!(
  title: "Project Roadmap Q1 2025",
  owner: charlie,
  visibility: :link
)

v6 = Version.create!(
  note: note3,
  author: charlie,
  content: "Q1 Goals:\n- Launch beta\n- Onboard 100 users\n- Achieve 99% uptime",
  summary: "Initial roadmap"
)
note3.update!(head_version: v6)

# Alice's note with revert scenario
note4 = Note.create!(
  title: "Meeting Notes - Jan 15",
  owner: alice,
  visibility: :private
)

v7 = Version.create!(
  note: note4,
  author: alice,
  content: "Attendees: Alice, Bob\nTopics: API design, database schema",
  summary: "Initial notes"
)
note4.update!(head_version: v7)

v8 = Version.create!(
  note: note4,
  author: alice,
  parent_version: v7,
  content: "Attendees: Alice, Bob, Charlie\nTopics: API design, database schema, deployment strategy",
  summary: "Updated attendees and topics"
)
note4.update!(head_version: v8)

# Revert scenario - go back to v7
v9 = Version.create!(
  note: note4,
  author: alice,
  parent_version: v8,
  content: v7.content, # Copied from v7
  summary: "Reverted to version #{v7.id}"
)
note4.update!(head_version: v9)

puts "Created #{Note.count} notes with #{Version.count} versions."

# Add collaborators
puts "Adding collaborators..."

Collaborator.create!(
  note: note1,
  user: bob,
  role: :editor
)

Collaborator.create!(
  note: note1,
  user: charlie,
  role: :viewer
)

Collaborator.create!(
  note: note4,
  user: bob,
  role: :editor
)

puts "Created #{Collaborator.count} collaborators."

# Create fork
puts "Creating fork..."

# Bob forks Alice's public-visible note
forked_note = Note.create!(
  title: "Alice's Research Notes (fork)",
  owner: bob,
  visibility: :private
)

v10 = Version.create!(
  note: forked_note,
  author: bob,
  content: note1.head_version.content,
  summary: "Forked from note #{note1.id}"
)
forked_note.update!(head_version: v10)

Fork.create!(
  source_note: note1,
  target_note: forked_note
)

puts "Created #{Fork.count} fork."

# Summary
puts "\n=== Seed Summary ==="
puts "Users: #{User.count}"
puts "Notes: #{Note.count}"
puts "Versions: #{Version.count}"
puts "Collaborators: #{Collaborator.count}"
puts "Forks: #{Fork.count}"
puts "\n=== Sample Accounts ==="
puts "Alice: alice@example.com / password123"
puts "Bob: bob@example.com / password123"
puts "Charlie: charlie@example.com / password123"
puts "\nSeeding complete!"
