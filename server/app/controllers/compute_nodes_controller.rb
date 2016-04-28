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
end
