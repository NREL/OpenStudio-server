require 'test_helper'

class AlgorithmsControllerTest < ActionController::TestCase
  setup do
    @algorithm = algorithms(:one)
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:algorithms)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create algorithm" do
    assert_difference('Algorithm.count') do
      post :create, algorithm: {  }
    end

    assert_redirected_to algorithm_path(assigns(:algorithm))
  end

  test "should show algorithm" do
    get :show, id: @algorithm
    assert_response :success
  end

  test "should get edit" do
    get :edit, id: @algorithm
    assert_response :success
  end

  test "should update algorithm" do
    put :update, id: @algorithm, algorithm: {  }
    assert_redirected_to algorithm_path(assigns(:algorithm))
  end

  test "should destroy algorithm" do
    assert_difference('Algorithm.count', -1) do
      delete :destroy, id: @algorithm
    end

    assert_redirected_to algorithms_path
  end
end
