module Analysis
  module R
    class DataFrame
      def self.save_dataframe(hash, dataframe_name, savepath)
        FileUtils.rm(savepath) if File.exist?(savepath)

        # force directory
        dir = File.expand_path(File.dirname(savepath))
        FileUtils.mkdir_p(dir)
        filename = File.basename(savepath)

        r = Rserve::Simpler.new
        r.command "setwd('#{File.expand_path(dir)}')"

        save_string = "save('#{dataframe_name}', file = '#{dir}/#{filename}')"
        r.converse(save_string, dataframe_name.to_sym => hash.to_dataframe)
      end

      def self.generate_summaries(dataframe)
        r = Rserve::Simpler.new

        result = r.converse('summary(df)', df: dataframe)
        result = result.each_slice(6).to_a

        hash = OrderedHash.new
        dataframe.colnames.each_index do |i|
          hash[dataframe.colnames[i]] = { raw: result[i].each { |v| v.strip! unless v.nil? } }
        end

        # now clean up the names
        hash.each_key do |key|
          hash[key][:raw].each do |v|
            if v =~ /^Min./
              hash[key][:min] = v.split(':')[1].to_f
            elsif v =~ /^1st Qu./
              hash[key][:first_q] = v.split(':')[1].to_f
            elsif v =~ /^Median./
              hash[key][:median] = v.split(':')[1].to_f
            elsif v =~ /Mean./
              hash[key][:mean] = v.split(':')[1].to_f
            elsif v =~ /3rd Qu./
              hash[key][:third_q] = v.split(':')[1].to_f
            elsif v =~ /Max./
              hash[key][:max] = v.split(':')[1].to_f
            end
          end
        end

        hash
      end
    end
  end
end
