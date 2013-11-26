# Core functions for analysis
module Analysis::Core

  # Take the samples and add in the pivots.  Each pivot variable
  # will get a full set of samples
  # take p = [{p1: 1}, {p1: 2}]
  # with s = [{a: 1, b: 4}, {a: 2, b: 5}, {a: 3, b: 6}]
  # make s' = [{p1: 1, a: 1, b: 4}, {p1: 2, a: 1, b: 4}, {p1: 1, a: 2, b: 5},  {p1: 2, a: 2, b: 5}]
  def add_pivots(samples, pivots)
    new_samples = []
    if pivots.size > 0
      pivots.each do |pivot|
        samples.each do |sample|
          new_samples << pivot.merge(sample)
        end
      end
      samples = new_samples
    end

    new_samples.empty? ? samples : new_samples
  end

  # static array of hash 
  # take static = [{a: 1, b: 2}]
  # with samples = [{c: 3}, {d: 4}]
  # results is [{a:1, b:2, c:3}, {a:1, b:2, d:4}]
  def add_static_variables(samples, statics)
    # Need to test the performance of this
    if statics.size > 0
      samples.each do |sample|
        statics.each do |st|
          sample.merge!(st)
        end
      end
    end

    samples
  end

  def flip_around_array()
    
  end
end

