require 'test_helper'

class DelayedJobViewsControllerTest < ActionController::TestCase
  setup do
    @delayed_job_view = delayed_job_views(:one)
  end

  test 'should get index' do
    get :index
    assert_response :success
    assert_not_nil assigns(:delayed_job_views)
  end

  test 'should get new' do
    get :new
    assert_response :success
  end

  test 'should create delayed_job_view' do
    assert_difference('DelayedJobView.count') do
      post :create, delayed_job_view: {}
    end

    assert_redirected_to delayed_job_view_path(assigns(:delayed_job_view))
  end

  test 'should show delayed_job_view' do
    get :show, id: @delayed_job_view
    assert_response :success
  end

  test 'should get edit' do
    get :edit, id: @delayed_job_view
    assert_response :success
  end

  test 'should update delayed_job_view' do
    put :update, id: @delayed_job_view, delayed_job_view: {}
    assert_redirected_to delayed_job_view_path(assigns(:delayed_job_view))
  end

  test 'should destroy delayed_job_view' do
    assert_difference('DelayedJobView.count', -1) do
      delete :destroy, id: @delayed_job_view
    end

    assert_redirected_to delayed_job_views_path
  end
end
