rm ../prototype/pat/rails-models.zip
if [ -d "/var/www/rails/openstudio/app/models" ]; then
  zip -j ../prototype/pat/rails-models.zip /var/www/rails/openstudio/app/models/*
  zip -j ../prototype/pat/rails-models.zip /var/www/rails/openstudio/config/initializers/inflections.rb
else
  zip -j ../prototype/pat/rails-models.zip ../openstudio-server/app/models/*
  zip -j ../prototype/pat/rails-models.zip ../openstudio-server/config/initializers/inflections.rb
fi


