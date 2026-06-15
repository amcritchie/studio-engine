# frozen_string_literal: true

unless Rake::Task.task_defined?("email:smoke")
  namespace :email do
    desc "Send one provider smoke-test email: bin/rails \"email:smoke[to@example.com]\""
    task :smoke, [:to] => :environment do |_task, args|
      require "studio/email_smoke"

      recipient = args[:to] || ENV["EMAIL_SMOKE_TO"] || ENV["TO"]
      abort "Usage: bin/rails \"email:smoke[to@example.com]\" or EMAIL_SMOKE_TO=to@example.com bin/rails email:smoke" if recipient.to_s.strip.empty?

      require_external = !%w[1 true yes on].include?(ENV["EMAIL_SMOKE_ALLOW_NON_EXTERNAL"].to_s.strip.downcase)
      result = Studio::EmailSmoke.deliver(to: recipient, require_external: require_external)
      puts result.report_lines
    rescue Studio::EmailSmoke::NonExternalDeliveryError => e
      puts e.result.report_lines
      abort "Refusing to call this a provider smoke test because mail would not leave the process. Set EMAIL_SMOKE_ALLOW_NON_EXTERNAL=1 only when intentionally proving capture/test mode."
    end
  end
end
