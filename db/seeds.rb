# Guard against accidental deletion in production
return unless Rails.env.development? || Rails.env.test?

# Clear existing data
puts "Cleaning up database..."
KeyTransferLog.delete_all
Key.delete_all
AccessToken.delete_all
Reservation.delete_all
Room.delete_all
User.delete_all

# Create Rooms
puts "Creating Rooms..."
room1 = Room.create!(name: "第１部室", room_number: "322")
room2 = Room.create!(name: "第２部室", room_number: "321")
room3 = Room.create!(name: "第３部室", room_number: "224")

# Create Users
puts "Creating Users..."
user1 = User.create!(
  username: "test_user1",
  display_name: "テストユーザー1"
)
user2 = User.create!(
  username: "test_user2",
  display_name: "テストユーザー2"
)

puts "Done! Created #{Room.count} rooms and #{User.count} users."
