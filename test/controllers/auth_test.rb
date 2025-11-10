require "test_helper"

class AuthTest < ActionDispatch::IntegrationTest
  def setup
    @test_email = "test@example.com"
    @test_password = "password123"
    @test_name = "Test User"
  end

  def teardown
    # Clean up any created accounts
    Account.where(email: @test_email).delete_all
  end

  test "account creation sends verification email" do
    assert_emails 1 do
      post "/auth/create-account",
           params: {
             name: @test_name,
             email: @test_email,
             password: @test_password,
             "password-confirm": @test_password
           },
           as: :json
    end

    assert_response :success
    json_response = JSON.parse(response.body)
    assert json_response["success"].include?("email has been sent")

    # Verify account was created
    account = Account.find_by(email: @test_email)
    assert_not_nil account
    assert_equal @test_name, account.name
    assert_equal "unverified", account.status
  end

  test "account creation with missing fields returns error" do
    post "/auth/create-account",
         params: {
           email: @test_email,
           password: @test_password
         },
         as: :json

    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert json_response["error"].present?
  end

  test "account creation with duplicate email returns error" do
    # Create first account
    post "/auth/create-account",
         params: {
           name: @test_name,
           email: @test_email,
           password: @test_password,
           "password-confirm": @test_password
         },
         as: :json

    assert_response :success

    # Try to create another account with same email
    post "/auth/create-account",
         params: {
           name: "Another User",
           email: @test_email,
           password: "different_password",
           "password-confirm": "different_password"
         },
         as: :json

    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert json_response["error"].present?
  end

  test "verification with POST request verifies account" do
    # Create account first
    account = create_test_account

    # Get verification key from database
    verification_key = get_verification_key(account.id)

    # Verify account using POST
    post "/auth/verify-account",
         params: { key: verification_key },
         as: :json

    assert_response :success
    json_response = JSON.parse(response.body)
    assert json_response["success"].include?("verified")

    # Check account status is now verified
    account.reload
    assert_equal "verified", account.status
  end

  test "verification with invalid key returns error" do
    post "/auth/verify-account",
         params: { key: "invalid_key" },
         as: :json

    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert json_response["error"].present?
  end

  test "login with unverified account returns error" do
    account = create_test_account

    post "/auth/login",
         params: {
           email: @test_email,
           password: @test_password
         },
         as: :json

    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert json_response["error"].present?
  end

  test "login with verified account succeeds" do
    account = create_and_verify_account

    post "/auth/login",
         params: {
           email: @test_email,
           password: @test_password
         },
         as: :json

    assert_response :success
    json_response = JSON.parse(response.body)
    assert json_response["success"].present?
  end

  test "login with wrong password returns error" do
    account = create_and_verify_account

    post "/auth/login",
         params: {
           email: @test_email,
           password: "wrong_password"
         },
         as: :json

    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert json_response["error"].present?
  end

  test "complete registration and verification flow" do
    # Step 1: Create account
    assert_emails 1 do
      post "/auth/create-account",
           params: {
             name: @test_name,
             email: @test_email,
             password: @test_password,
             "password-confirm": @test_password
           },
           as: :json
    end
    assert_response :success

    # Step 2: Verify account was created with correct status
    account = Account.find_by(email: @test_email)
    assert_not_nil account
    assert_equal "unverified", account.status

    # Step 3: Get verification key and verify account
    verification_key = get_verification_key(account.id)
    post "/auth/verify-account",
         params: { key: verification_key },
         as: :json
    assert_response :success

    # Step 4: Check account is now verified
    account.reload
    assert_equal "verified", account.status

    # Step 5: Login should now work
    post "/auth/login",
         params: {
           email: @test_email,
           password: @test_password
         },
         as: :json
    assert_response :success

    # Step 6: Access protected resource
    get "/dashboard", as: :json
    assert_response :success
  end

  private

  def create_test_account
    post "/auth/create-account",
         params: {
           name: @test_name,
           email: @test_email,
           password: @test_password,
           "password-confirm": @test_password
         },
         as: :json

    Account.find_by(email: @test_email)
  end

  def create_and_verify_account
    account = create_test_account
    verification_key = get_verification_key(account.id)

    post "/auth/verify-account",
         params: { key: verification_key },
         as: :json

    account.reload
    account
  end

  def get_verification_key(account_id)
    # For testing, we'll simulate getting the key from the email
    # In a real test, you'd parse the email content
    # For now, let's use the last email sent which contains the verification URL
    last_email = ActionMailer::Base.deliveries.last
    return nil unless last_email

    # Extract key from email body
    body = last_email.body.to_s
    match = body.match(/key=([^\\s]+)/)
    match ? match[1].strip : nil
  end
end