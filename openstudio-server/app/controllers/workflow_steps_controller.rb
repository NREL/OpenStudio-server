class WorkflowStepsController < ApplicationController
  # GET /workflow_steps
  # GET /workflow_steps.json
  def index
    @workflow_steps = WorkflowStep.all

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @workflow_steps }
    end
  end

  # GET /workflow_steps/1
  # GET /workflow_steps/1.json
  def show
    @workflow_step = WorkflowStep.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @workflow_step }
    end
  end

  # GET /workflow_steps/new
  # GET /workflow_steps/new.json
  def new
    @workflow_step = WorkflowStep.new

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @workflow_step }
    end
  end

  # GET /workflow_steps/1/edit
  def edit
    @workflow_step = WorkflowStep.find(params[:id])
  end

  # POST /workflow_steps
  # POST /workflow_steps.json
  def create
    @workflow_step = WorkflowStep.new(params[:workflow_step])

    respond_to do |format|
      if @workflow_step.save
        format.html { redirect_to @workflow_step, notice: 'Workflow step was successfully created.' }
        format.json { render json: @workflow_step, status: :created, location: @workflow_step }
      else
        format.html { render action: "new" }
        format.json { render json: @workflow_step.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /workflow_steps/1
  # PUT /workflow_steps/1.json
  def update
    @workflow_step = WorkflowStep.find(params[:id])

    respond_to do |format|
      if @workflow_step.update_attributes(params[:workflow_step])
        format.html { redirect_to @workflow_step, notice: 'Workflow step was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @workflow_step.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /workflow_steps/1
  # DELETE /workflow_steps/1.json
  def destroy
    @workflow_step = WorkflowStep.find(params[:id])
    @workflow_step.destroy

    respond_to do |format|
      format.html { redirect_to workflow_steps_url }
      format.json { head :no_content }
    end
  end
end
