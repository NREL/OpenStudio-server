require 'test_helper'

class ParetosControllerTest < ActionController::TestCase
  setup do
    @pareto = paretos(:one)
  end

  test 'should get index' do
    get :index
    assert_response :success
    assert_not_nil assigns(:paretos)
  end

  test 'should get new' do
    get :new
    assert_response :success
  end

  test 'should create pareto' do
    assert_difference('Pareto.count') do
      post :create, pareto: {}
    end

    assert_redirected_to pareto_path(assigns(:pareto))
  end

  test 'should show pareto' do
    get :show, id: @pareto
    assert_response :success
  end

  test 'should get edit' do
    get :edit, id: @pareto
    assert_response :success
  end

  test 'should update pareto' do
    put :update, id: @pareto, pareto: {}
    assert_redirected_to pareto_path(assigns(:pareto))
  end

  test 'should destroy pareto' do
    assert_difference('Pareto.count', -1) do
      delete :destroy, id: @pareto
    end

    assert_redirected_to paretos_path
  end
end
