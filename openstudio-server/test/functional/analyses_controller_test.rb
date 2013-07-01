require 'test_helper'

class AnalysesControllerTest < ActionController::TestCase
  setup do
    @analysis = analyses(:one)
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:analyses)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create analysis" do
    assert_difference('Analysis.count') do
      post :create, analysis: {  }
    end

    assert_redirected_to analysis_path(assigns(:analysis))
  end

  test "should show analysis" do
    get :show, id: @analysis
    assert_response :success
  end

  test "should get edit" do
    get :edit, id: @analysis
    assert_response :success
  end

  test "should update analysis" do
    put :update, id: @analysis, analysis: {  }
    assert_redirected_to analysis_path(assigns(:analysis))
  end

  test "should destroy analysis" do
    assert_difference('Analysis.count', -1) do
      delete :destroy, id: @analysis
    end

    assert_redirected_to analyses_path
  end
end
