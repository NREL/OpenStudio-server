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

  # For sampling take hashes of array values and makes them arrays of hashes set to 
  # each value in the array index
  def hash_of_array_to_array_of_hash(hash_array)
    # This takes
    # {a: [1,2,3], b:[4,5,6]} 
    # and makes:
    # [{a: 1, b: 4}, {a: 2, b: 5}, {a: 3, b: 6}]
    result = hash_array.map { |k, v| [k].product(v) }.transpose.map { |ps| Hash[ps] }
  end

  module_function :hash_of_array_to_array_of_hash # export this function for use outside of class extension

  # return the single dimension samples of the array.  This also runs a dedupe method.
  def hash_of_array_to_array_of_hash_non_combined(hash_array)
    # This takes
    # h = {a: [1, 2, 3], b: ["4", "5", "6"], c: [true, false, false]}
    # and makes
    # [{a:1}, {a:2}, {a:3}, {b:"4"}, ... {c: true}, {c: false}] 
    result = hash_array.map { |k, v| v.map { |value| {:"#{k}" => value} } }.flatten.uniq
  end

  module_function :hash_of_array_to_array_of_hash_non_combined # export this function for use outside of class extension

  # Grouped hash of hash of arrays with static array
  def grouped_hash_of_array_to_array_of_hash(hash_array, static_array)
    # This takes
    # h = {a: {x: [1, 2, 3]}, b: {y: ["4", "5", "6"], z: [true, false, false]}
    # s = {a: {w: [true]}}
    # and makes
    # h' = [{x: 1, w: true}, {y: "4", z: true} ]

    # first go through and expand the length of s[measure_id] to the same length as the h[measure_id]
    hash_array.each do |k, v|
      if static_array.has_key?(k)
        # get the length of the hash variable arrays -- these should always be equal
        max = v.map {|ks,vs| vs.size}.max 
        
        # expand the static array to have the same lengths
        static_array[k].each do |ks, vs|
          #puts "expanding static array from #{static_array}"
          static_array[k][ks] = vs * max
          #puts "to static array of #{static_array}"
        end
      end
    end

    #puts "Static array is now #{static_array}"
    merged = hash_array.deep_merge(static_array)
    
    #puts "Merged array is now #{merged}"
    # for each measure combine the results
    merged.each do |k,v|
      merged[k] = hash_of_array_to_array_of_hash(v)
    end
    #puts "New hash array is #{merged}"
    
    # now merge this down to an array
    merged = merged.map{|_,v| v}.flatten

    merged
  end
  module_function :grouped_hash_of_array_to_array_of_hash # export this function for use outside of class extension


  # The module method will take continuous variables and discretize the values and save them into the 
  # values hash (with weights if applicable) in order to be used with discrete algorithms
  def discretize_variables()

  end

  # I put this here expecting to put the child download process here... need to move it eventually
  module BackgroundTasks

  end
end

