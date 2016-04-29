class ComputeNodesController < ApplicationController
  # GET /compute_nodes
  # GET /compute_nodes.json
  def index
    @nodes = ComputeNode.all

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @nodes }
    end
  end

  # GET /compute_nodes/new.json
  def new
    @compute_node = ComputeNode.new

    respond_to do |format|
      format.json { render json: @compute_node }
    end
  end

  # GET /data_points/1/edit
  def edit
    @compute_node = ComputeNode.find(params[:id])
  end

  # POST /data_points.json
  def create
    params = compute_node_params
    @compute_node = ComputeNode.new(params)

    respond_to do |format|
      if @compute_node.save!
        format.json { render json: @compute_node, status: :created, location: @compute_node }
      else
        format.json { render json: @compute_node.errors, status: :unprocessable_entity }
      end
    end
  end

  def compute_node_params
    params.require(:compute_node).permit!
  end

end
