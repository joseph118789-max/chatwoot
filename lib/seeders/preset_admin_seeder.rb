# frozen_string_literal: true

class Seeders::PresetAdminSeeder
  def self.admin_password
    ENV['ADMIN_PASSWORD'].presence || ENV['CHATWOOT_ADMIN_PASSWORD'].presence
  end

  def self.admin_email
    ENV['ADMIN_EMAIL'].presence || ENV['CHATWOOT_ADMIN_EMAIL'].presence || ENV['CHATWOOT_INSTANCE_ADMIN_EMAIL'].presence
  end

  def self.preset_admin_configured?
    admin_password.present? && admin_email.present?
  end

  def self.needs_sync?
    return false unless preset_admin_configured?

    user = User.find_by(email: admin_email)
    return true if user.nil?
    return true unless user.valid_password?(admin_password)
    return true unless user.type == 'SuperAdmin'
    return true unless user.confirmed?

    false
  end

  def self.perform_if_configured
    return unless preset_admin_configured?

    new.perform!
  end

  def initialize
    @email = self.class.admin_email
    @password = self.class.admin_password
    @name = ENV['ADMIN_NAME'].presence || ENV['CHATWOOT_ADMIN_NAME'].presence || 'Admin'
    @company_name = ENV['ADMIN_COMPANY_NAME'].presence || ENV['CHATWOOT_ADMIN_COMPANY_NAME'].presence || 'Chatwoot'
  end

  def perform!
    user, account = find_or_create_admin_and_account
    grant_all_features_and_modules(account)
    configure_installation_defaults
    skip_onboarding_flow
    [user, account]
  end

  private

  def find_or_create_admin_and_account
    user = User.find_by(email: @email)
    if user.nil?
      user = User.new(
        name: @name,
        email: @email,
        password: @password,
        password_confirmation: @password,
        type: 'SuperAdmin'
      )
      user.skip_confirmation!
      user.save!
    else
      user.type = 'SuperAdmin' if user.type != 'SuperAdmin'
      user.password = @password
      user.password_confirmation = @password
      user.skip_confirmation! if user.respond_to?(:skip_confirmation!)
      user.save!
    end

    account = user.accounts.first
    if account.nil?
      account = Account.create!(
        name: @company_name,
        locale: I18n.locale || 'en'
      )
    end

    account_user = AccountUser.find_or_initialize_by(account_id: account.id, user_id: user.id)
    account_user.role = :administrator
    account_user.save!

    [user, account]
  end

  def grant_all_features_and_modules(account)
    account.custom_attributes ||= {}
    account.custom_attributes.delete('onboarding_step')
    account.custom_attributes['plan_name'] = 'Enterprise'

    feature_names = Featurable::FEATURE_LIST.map { |f| f['name'] }
    account.enable_features(*feature_names)
    account.save!
  end

  def configure_installation_defaults
    create_account_config = InstallationConfig.find_or_initialize_by(name: 'CREATE_NEW_ACCOUNT_FROM_DASHBOARD')
    create_account_config.value = true
    create_account_config.save!

    plan_config = InstallationConfig.find_or_initialize_by(name: 'INSTALLATION_PRICING_PLAN')
    plan_config.value = 'enterprise'
    plan_config.save!

    quantity_config = InstallationConfig.find_or_initialize_by(name: 'INSTALLATION_PRICING_PLAN_QUANTITY')
    quantity_config.value = 1000
    quantity_config.save!

    admin_email_config = InstallationConfig.find_or_initialize_by(name: 'CHATWOOT_INSTANCE_ADMIN_EMAIL')
    admin_email_config.value = @email
    admin_email_config.save!

    GlobalConfig.clear_cache
  end

  def skip_onboarding_flow
    ::Redis::Alfred.delete(::Redis::Alfred::CHATWOOT_INSTALLATION_ONBOARDING)
  end
end
