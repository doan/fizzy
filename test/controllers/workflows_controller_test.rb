require "test_helper"

class WorkflowsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "index" do
    get workflows_path
    assert_in_body workflows(:on_call).name
  end

  test "create" do
    get new_workflow_path
    assert_response :success

    assert_difference -> { Workflow.count }, +1 do
      post workflows_path, params: { workflow: { name: "My new workflow!" } }
      assert_redirected_to workflows_path
    end
  end

  test "show" do
    get workflow_path(workflows(:on_call))
    assert_in_body workflows(:on_call).name
  end

  test "update" do
    get edit_workflow_path(workflows(:on_call))
    assert_response :success

    put workflow_path(workflows(:on_call)), params: { workflow: { name: "Monkeyflow!" } }
    follow_redirect!
    assert_in_body "Monkeyflow!"
  end

  test "destroy" do
    assert_difference -> { Workflow.count }, -1 do
      delete workflow_path(workflows(:on_call))
      assert_redirected_to workflows_path
    end
  end
end
