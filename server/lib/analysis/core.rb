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
  def hash_of_array_to_array_of_hash_non_combined(hash_array, selected_variables)
    # This takes
    # h = {a: [1, 2, 3], b: ["4", "5", "6"], c: [true, false, false]}
    # and makes
    # [{a:1}, {a:2}, {a:3}, {b:"4"}, ... {c: true}, {c: false}]
    result = hash_array.map { |k, v| v.map { |value| {:"#{k}" => value} } }.flatten.uniq
    # then sets the "static/default" from the other variables
    selected_variables.each do |var|
      result.each_with_index do |r, index|
        unless r.has_key? var._id.to_sym
          result[index][var._id.to_sym] = var.static_value
        end
      end
    end

    result
  end

  module_function :hash_of_array_to_array_of_hash_non_combined # export this function for use outside of class extension

  # The module method will take continuous variables and discretize the values and save them into the
  # values hash (with weights if applicable) in order to be used with discrete algorithms
  def discretize_variables
  end

  # I put this here expecting to put the child download process here... need to move it eventually
  module BackgroundTasks
  end
end
