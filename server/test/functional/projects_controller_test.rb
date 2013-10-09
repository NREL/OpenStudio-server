require 'test_helper'

class ProjectsControllerTest < ActionController::TestCase
  setup do
    @project = projects(:one)
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:projects)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create models" do
    assert_difference('Project.count') do
      post :create, models: {  }
    end

    assert_redirected_to project_path(assigns(:models))
  end

  test "should show models" do
    get :show, id: @project
    assert_response :success
  end

  test "should get edit" do
    get :edit, id: @project
    assert_response :success
  end

  test "should update models" do
    put :update, id: @project, models: {  }
    assert_redirected_to project_path(assigns(:models))
  end

  test "should destroy models" do
    assert_difference('Project.count', -1) do
      delete :destroy, id: @project
    end

    assert_redirected_to projects_path
  end
end
