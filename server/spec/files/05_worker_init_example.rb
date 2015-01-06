class WorkerInitExample
  def initialize
    # do nothing in this example
  end

  def run(*args)
    puts args

    args
  end

  def finalize
    # do nothing
  end
end
