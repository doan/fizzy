require "test_helper"

class Conversations::MessagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "index" do
    get conversation_messages_path
    assert_response :success
  end

  test "paginated index" do
    get conversation_messages_path(before: conversation_messages(:kevins_question))
    assert_response :success

    get conversation_messages_path(before: conversation_messages(:kevins_answer))
    assert_response :success
  end

  test "create" do
    post conversation_messages_path, params: { conversation_message: { content: "Hello!" } }
    assert_response :success
  end
end
