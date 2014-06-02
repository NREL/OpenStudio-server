# http://stackoverflow.com/questions/17451487/classic-hash-to-dot-notation-hash
def hash_to_dot_notation(object, prefix = nil)
  if object.is_a? Hash
    object.map do |key, value|
      if prefix
        hash_to_dot_notation value, "#{prefix}.#{key}"
      else
        hash_to_dot_notation value, "#{key}"
      end
    end.reduce(&:merge)
  else
    {prefix => object}
  end
end