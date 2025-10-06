require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'validations' do
    subject { build(:user) }

    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_uniqueness_of(:email).case_insensitive }
    it { is_expected.to allow_value('user@example.com').for(:email) }
    it { is_expected.not_to allow_value('invalid_email').for(:email) }

    context 'password validation' do
      it 'requires password on create' do
        user = User.new(email: 'test@example.com', password: nil)
        expect(user).not_to be_valid
        expect(user.errors[:password]).to include("can't be blank")
      end

      it 'requires minimum password length' do
        user = build(:user, password: '123', password_confirmation: '123')
        expect(user).not_to be_valid
      end

      it 'accepts valid password' do
        user = build(:user, password: 'validpassword123', password_confirmation: 'validpassword123')
        expect(user).to be_valid
      end
    end
  end

  describe 'associations' do
    it { is_expected.to have_many(:notes).with_foreign_key(:owner_id).dependent(:destroy) }
  end

  describe 'Devise modules' do
    it 'includes database_authenticatable' do
      expect(User.devise_modules).to include(:database_authenticatable)
    end

    it 'includes registerable' do
      expect(User.devise_modules).to include(:registerable)
    end

    it 'includes recoverable' do
      expect(User.devise_modules).to include(:recoverable)
    end

    it 'includes rememberable' do
      expect(User.devise_modules).to include(:rememberable)
    end

    it 'includes validatable' do
      expect(User.devise_modules).to include(:validatable)
    end
  end

  describe 'cascading deletes' do
    it 'deletes associated notes when user is destroyed' do
      user = create(:user)
      note = create(:note, owner: user)

      expect { user.destroy }.to change { Note.count }.by(-1)
    end
  end
end
