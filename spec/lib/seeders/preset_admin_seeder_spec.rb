# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Seeders::PresetAdminSeeder do
  let(:email) { 'custom_admin@example.com' }
  let(:password) { 'CustomPass123!#Secure' }

  describe '.preset_admin_configured?' do
    it 'returns false when environment variables are not set' do
      with_modified_env ADMIN_EMAIL: nil, ADMIN_PASSWORD: nil, CHATWOOT_ADMIN_EMAIL: nil, CHATWOOT_ADMIN_PASSWORD: nil do
        expect(described_class.preset_admin_configured?).to be(false)
      end
    end

    it 'returns true when ADMIN_EMAIL and ADMIN_PASSWORD are set' do
      with_modified_env ADMIN_EMAIL: email, ADMIN_PASSWORD: password do
        expect(described_class.preset_admin_configured?).to be(true)
      end
    end
  end

  describe '#perform!' do
    it 'creates super admin user, account with all features enabled, and removes onboarding flag' do
      Redis::Alfred.set(Redis::Alfred::CHATWOOT_INSTALLATION_ONBOARDING, true)

      with_modified_env ADMIN_EMAIL: email, ADMIN_PASSWORD: password, ADMIN_NAME: 'Boss', ADMIN_COMPANY_NAME: 'Acme Global' do
        user, account = described_class.new.perform!

        expect(user).to be_persisted
        expect(user.type).to eq('SuperAdmin')
        expect(user.email).to eq(email)
        expect(user.name).to eq('Boss')
        expect(user.valid_password?(password)).to be(true)
        expect(user.confirmed?).to be(true)

        expect(account).to be_persisted
        expect(account.name).to eq('Acme Global')
        expect(account.custom_attributes['plan_name']).to eq('Enterprise')
        expect(account.custom_attributes['onboarding_step']).to be_nil

        account_user = user.account_users.first
        expect(account_user.role).to eq('administrator')

        # Check all features enabled
        feature_names = Featurable::FEATURE_LIST.map { |f| f['name'] }
        feature_names.each do |feature|
          expect(account.feature_enabled?(feature)).to be(true)
        end

        expect(Redis::Alfred.get(Redis::Alfred::CHATWOOT_INSTALLATION_ONBOARDING)).to be_nil
        expect(InstallationConfig.find_by(name: 'INSTALLATION_PRICING_PLAN').value).to eq('enterprise')
      end
    end
  end
end
