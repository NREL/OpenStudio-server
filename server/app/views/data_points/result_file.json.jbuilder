json.set! :id, @rf.id.to_s
json.set! :data_point_id, @data_point.id.to_s
json.extract! @rf, :display_name, :type, :created_at, :updated_at