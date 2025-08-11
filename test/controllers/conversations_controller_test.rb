require "test_helper"

class ConversationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "show" do
    get conversation_path
    assert_response :success
  end
end
