require "sequel/core"

class RodauthMain < Rodauth::Rails::Auth
  configure do

    def account_id
      Rails.logger.info "DEBUG: account_id called. Session method returns: #{session.inspect}"
      super
    end

    # List of authentication features that are loaded.
    enable :create_account, :verify_account,
      :login, :logout,
      :reset_password, :change_password, :change_login, :verify_login_change,
      :close_account, :omniauth

    # See the Rodauth documentation for the list of available config options:
    # http://rodauth.jeremyevans.net/documentation.html

    # ==> General
    # Initialize Sequel and have it reuse Active Record's database connection.
    db Sequel.postgres(extensions: :activerecord_connection, keep_reference: false)
    # Avoid DB query that checks accounts table schema at boot time.
    convert_token_id_to_integer? { Account.columns_hash["id"].type == :integer }

    # Change prefix of table and foreign key column names from default "account"
    # accounts_table :users
    # verify_account_table :user_verification_keys
    # verify_login_change_table :user_login_change_keys
    # reset_password_table :user_password_reset_keys
    # remember_table :user_remember_keys

    # The secret key used for hashing public-facing tokens for various features.
    # Defaults to Rails `secret_key_base`, but you can use your own secret key.
    # hmac_secret "fa082b599c4212c49b502ce5031096b7c96a04cd72e15c3b7a9181c99ea8502368202339c4f14c129dcbf1f6247ee476aee80232672ad6031916538729bb97c9"

    # Use path prefix for all routes.
    prefix "/auth"

    # Account model
    rails_account_model { Account }

    # Specify the controller used for view rendering, CSRF, and callbacks.
    rails_controller { RodauthController }

    # Make built-in page titles accessible in your views via an instance variable.
    title_instance_variable :@page_title

    # Store account status in an integer column without foreign key constraint.
    account_status_column :status

    # Store password hash in a column instead of a separate table.
    account_password_hash_column :password_hash

    # Set password when creating account instead of when verifying.
    verify_account_set_password? false

    # Auto-verify accounts on GET request when password is already set
    verify_account_autologin? true

    # Change some default param keys.
    login_param "email"
    login_confirm_param "email-confirm"
    # password_confirm_param "confirm_password"

    # Redirect back to originally requested location after authentication.
    # login_return_to_requested_location? true
    # two_factor_auth_return_to_requested_location? true # if using MFA

    # Autologin the user after they have reset their password.
    # reset_password_autologin? true

    # Delete the account record when the user has closed their account.
    # delete_account_on_close? true

    # Redirect to the app from login and registration pages if already logged in.
    # already_logged_in { redirect login_redirect }

    # ==> Emails
    send_email do |email|
      # queue email delivery on the mailer after the transaction commits
      db.after_commit { email.deliver_later }
    end

    # Not sure if I need this, so not gonna happen, sorry Claudio :(
    # Email configuration
    # email_from "[email protected]"
    # email_subject_prefix "[MyApp] "

    # ==> Flash
    # Match flash keys with ones already used in the Rails app.
    # flash_notice_key :success # default is :notice
    # flash_error_key :error # default is :alert

    # Override default flash messages.
    # create_account_notice_flash "Your account has been created. Please verify your account by visiting the confirmation link sent to your email address."
    # require_login_error_flash "Login is required for accessing this page"
    # login_notice_flash nil

    # ==> Validation
    # Override default validation error messages.
    # no_matching_login_message "user with this email address doesn't exist"
    # already_an_account_with_this_login_message "user with this email address already exists"
    # password_too_short_message { "needs to have at least #{password_minimum_length} characters" }
    # login_does_not_meet_requirements_message { "invalid email#{", #{login_requirement_message}" if login_requirement_message}" }

    # Passwords shorter than 8 characters are considered weak according to OWASP.
    password_minimum_length 8
    # bcrypt has a maximum input length of 72 bytes, truncating any extra bytes.
    password_maximum_bytes 72

    # Custom password complexity requirements (alternative to password_complexity feature).
    # password_meets_requirements? do |password|
    #   super(password) && password_complex_enough?(password)
    # end
    # auth_class_eval do
    #   def password_complex_enough?(password)
    #     return true if password.match?(/\d/) && password.match?(/[^a-zA-Z\d]/)
    #     set_password_requirement_error_message(:password_simple, "requires one number and one special character")
    #     false
    #   end
    # end

    # ==> Remember Feature
    # Remember all logged in users.
    # after_login { remember_login }

    # Or only remember users that have ticked a "Remember Me" checkbox on login.
    # after_login { remember_login if param_or_nil("remember") }

    # Extend user's remember period when remembered via a cookie
    # extend_remember_deadline? true

    # ==> Hooks
    # Validate custom fields in the create account form.
    # before_create_account do
    #   throw_error_status(422, "name", "must be present") if param("name").empty?
    # end

    # Add name field handling
    before_create_account do
      throw_error_status(422, "name", "must be present") unless param_or_nil("name")
    end

    # Try overriding methods that are actually called
    auth_class_eval do
      def new_account(login)
        account_hash = super(login)
        account_hash[:name] = param("name")
        account_hash
      end
    end

    # Do additional cleanup after the account is closed.
    # after_close_account do
    #   Profile.find_by!(account_id: account_id).destroy
    # end

    # ==> Redirects
    # Redirect to home page after logout.
    logout_redirect "/"

    # Redirect to wherever login redirects to after account verification.
    # Redirect after login
    login_redirect { "/dashboard" }
    verify_account_redirect { login_redirect }

    # Redirect to login page after password reset.
    reset_password_redirect { login_path }

    # HMAC secret for secure tokens
    hmac_secret Rails.application.credentials.secret_key_base

    # OmniAuth
    omniauth_provider :google_oauth2,
      ENV["GOOGLE_CLIENT_ID"],
      ENV["GOOGLE_CLIENT_SECRET"],
      scope: "email, profile",
      prompt: "select_account"

    before_omniauth_callback_route do
      auth = omniauth_auth
      Rails.logger.info "OmniAuth Auth: #{auth.inspect}"
      Rails.logger.info "Session (Rails): #{session.inspect}"
      Rails.logger.info "Session (Rails): #{session.inspect}"

      if auth.nil? || auth["info"].nil?
        set_redirect_error_flash "Authentication failed: No auth data received from Google."
        redirect login_path
      end

      email = auth["info"]["email"]
      name = auth["info"]["name"]

      unless email
        set_redirect_error_flash "Authentication failed: No email provided by Google."
        redirect login_path
      end

      account = Account.where(email: email).first

      unless account
        account = Account.new(email: email, name: name || "Unknown")
        account.status = 1 # Verified

        unless account.save
          Rails.logger.error "Account save failed: #{account.errors.full_messages}"
          set_redirect_error_flash "Could not create account from Google."
          redirect login_path
        end
      end

      Rails.logger.info "Logging in account: #{account.id}"
      
      # Manually set the account for Rodauth to use
      self.instance_variable_set(:@account, account)
      
      begin
        login("google_oauth2")
      rescue => e
        Rails.logger.error "Login error: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        raise e
      end
      redirect login_redirect
    end

    # ==> Deadlines
    # Change default deadlines for some actions.
    # verify_account_grace_period 3.days.to_i
    # reset_password_deadline_interval Hash[hours: 6]
    # verify_login_change_deadline_interval Hash[days: 2]
    # remember_deadline_interval Hash[days: 30]

    # Enable JSON API support
    enable :json

    # Allow JSON requests
    only_json? false  # Allow both HTML and JSON

    # JSON response configuration
    json_response_success_key :success
    json_response_error_key :error
  end
end
