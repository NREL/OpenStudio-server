# http://stackoverflow.com/questions/17451487/classic-hash-to-dot-notation-hash
def hash_to_dot_notation(object, prefix = nil)
  if object.is_a? Hash
    object.map do |key, value|
      if prefix
        hash_to_dot_notation value, "#{prefix}.#{key}"
      else
        if value.empty?
          # remove any empty result hashes
          object.delete(key)
        else
          hash_to_dot_notation value, key.to_s
        end
      end
    end.reduce(&:merge)
  else
    { prefix => object }
  end
end

class Hash
  def compact(opts = {})
    reduce({}) do |new_hash, (k, v)|
      unless v.nil?
        new_hash[k] = opts[:recurse] && v.class == Hash ? v.compact(opts) : v
      end
      new_hash
    end
  end
end
