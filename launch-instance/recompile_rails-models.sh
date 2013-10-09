rm ../worker-nodes/rails-models/rails-models.zip
if [ -d "/var/www/rails/openstudio/app/models" ]; then
  zip -j ../worker-nodes/rails-models/rails-models.zip /var/www/rails/openstudio/app/models/*
  zip -j ../worker-nodes/rails-models/rails-models.zip /var/www/rails/openstudio/config/initializers/inflections.rb
else
  zip -j ../worker-nodes/rails-models/rails-models.zip ../openstudio-server/app/models/*
  zip -j ../worker-nodes/rails-models/rails-models.zip ../openstudio-server/config/initializers/inflections.rb
fi


