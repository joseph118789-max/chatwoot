# frozen_string_literal: true

namespace :db do
  namespace :seed do
    desc 'Seeds or updates preset admin user from environment variables'
    task preset_admin: :environment do
      if Seeders::PresetAdminSeeder.preset_admin_configured?
        user, account = Seeders::PresetAdminSeeder.new.perform!
        puts "Preset admin configured: #{user.email} (Account: #{account.name})"
      else
        puts 'ADMIN_PASSWORD and ADMIN_EMAIL environment variables are required.'
      end
    end
  end
end
