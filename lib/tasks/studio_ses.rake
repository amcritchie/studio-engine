# frozen_string_literal: true

unless Rake::Task.task_defined?("ses:check")
  namespace :ses do
    def studio_ses_env_value(name)
      value = ENV[name]
      return nil if value.nil? || value.to_s.strip.empty?

      value
    end

    def studio_ses_credential(name)
      studio_ses_env_value("SES_#{name}") || studio_ses_env_value(name)
    end

    def studio_ses_credential_source(name)
      return "SES_#{name}" if studio_ses_env_value("SES_#{name}")
      return name if studio_ses_env_value(name)

      "missing"
    end

    def studio_ses_signer(region)
      require "aws-sigv4"

      access_key_id = studio_ses_credential("AWS_ACCESS_KEY_ID")
      secret_access_key = studio_ses_credential("AWS_SECRET_ACCESS_KEY")
      missing = []
      missing << "SES_AWS_ACCESS_KEY_ID or AWS_ACCESS_KEY_ID" unless access_key_id
      missing << "SES_AWS_SECRET_ACCESS_KEY or AWS_SECRET_ACCESS_KEY" unless secret_access_key
      abort "ses:* needs #{missing.join(' and ')}." if missing.any?

      Aws::Sigv4::Signer.new(
        service: "ses",
        region: region,
        access_key_id: access_key_id,
        secret_access_key: secret_access_key
      )
    rescue LoadError
      abort "ses:* needs aws-sigv4; it is usually available through aws-sdk-s3."
    end

    def studio_ses_request(signer, region, method, path, body = nil)
      require "net/http"
      require "json"

      url = "https://email.#{region}.amazonaws.com#{path}"
      headers = body ? { "content-type" => "application/json" } : {}
      sig = signer.sign_request(http_method: method, url: url, body: body, headers: headers)
      uri = URI(url)
      http = Net::HTTP.new(uri.host, 443)
      http.use_ssl = true
      req = Net::HTTP.const_get(method.capitalize).new(uri)
      headers.each { |key, value| req[key] = value }
      sig.headers.each { |key, value| req[key] = value }
      req.body = body if body
      res = http.request(req)
      [res.code.to_i, (JSON.parse(res.body) rescue { "raw" => res.body.to_s[0, 300] })]
    end

    def studio_ses_error(body)
      body["message"] || body["Message"] || body["raw"]
    end

    desc "Check SES account status and verified identities"
    task check: :environment do
      region = ENV.fetch("SES_REGION", "us-east-2")
      signer = studio_ses_signer(region)
      get = ->(path) { studio_ses_request(signer, region, "GET", path) }

      code, account = get.call("/v2/email/account")
      puts "GetAccount (region #{region}) -> HTTP #{code}"
      puts "  CredentialSource=#{studio_ses_credential_source('AWS_ACCESS_KEY_ID')}"
      if code == 200
        puts "  SendingEnabled=#{account['SendingEnabled']} ProductionAccessEnabled=#{account['ProductionAccessEnabled']} Enforcement=#{account['EnforcementStatus']}"
      else
        puts "  ERROR: #{studio_ses_error(account)}"
      end

      code, identities = get.call("/v2/email/identities")
      puts "ListEmailIdentities -> HTTP #{code}"
      if code == 200
        list = identities["EmailIdentities"] || []
        names = list.map { |identity| "#{identity['IdentityName']}(#{identity['VerifiedForSendingStatus'] ? 'verified' : 'pending'})" }
        puts "  identities: #{names.empty? ? '(none yet)' : names.join(', ')}"
      else
        puts "  ERROR: #{studio_ses_error(identities)}"
      end

      transport = ENV.fetch("MAIL_TRANSPORT", "(unset -> resend)")
      puts "Live transport: MAIL_TRANSPORT=#{transport} delivery_method=#{ActionMailer::Base.delivery_method}"
    end

    desc "Create a SES domain identity and print DKIM CNAME records"
    task :verify_domain, [:domain] => :environment do |_task, args|
      abort "Usage: ses:verify_domain[domain]" if args[:domain].blank?

      domain = args[:domain]
      region = ENV.fetch("SES_REGION", "us-east-2")
      signer = studio_ses_signer(region)
      body = { EmailIdentity: domain }.to_json
      code, response = studio_ses_request(signer, region, "POST", "/v2/email/identities", body)
      already_exists = "#{response['message']} #{response['Message']}".match?(/already exist/i)

      if code == 409 || ([400, 409].include?(code) && already_exists)
        code, response = studio_ses_request(signer, region, "GET", "/v2/email/identities/#{domain}")
      end

      if code != 200
        puts "#{domain}: ERROR (HTTP #{code}) #{studio_ses_error(response)}"
        next
      end

      tokens = response.dig("DkimAttributes", "Tokens") || []
      status = response.dig("DkimAttributes", "Status") || response["VerifiedForSendingStatus"]
      puts "== #{domain} (region #{region}, DKIM status: #{status}) =="
      if tokens.empty?
        puts "  (no DKIM tokens returned)"
      else
        puts "  Add these 3 CNAME records to #{domain}'s DNS:"
        tokens.each do |token|
          puts "    NAME:  #{token}._domainkey.#{domain}"
          puts "    TYPE:  CNAME"
          puts "    VALUE: #{token}.dkim.amazonses.com"
          puts ""
        end
      end
    end
  end
end
