#!/bin/sh

sudo apt-get autoremove --purge chef -y
sudo rm -rf /opt/

sudo apt-get autoremove --purge gir1.2-freedesktop -y
sudo apt-get autoremove --purge gir1.2-glib-2.0 -y
sudo apt-get autoremove --purge libcairo-script-interpreter2 -y
sudo apt-get autoremove --purge libcairo2-dev -y
sudo apt-get autoremove --purge libfontconfig1-dev -y
sudo apt-get autoremove --purge libfreetype6-dev -y
sudo apt-get autoremove --purge libglib2.0-bin -y
sudo apt-get autoremove --purge libglib2.0-data -y
sudo apt-get autoremove --purge libglib2.0-dev -y
sudo apt-get autoremove --purge libkpathsea5 -y
sudo apt-get autoremove --purge liblzma-dev -y
sudo apt-get autoremove --purge libpango1.0-dev -y
sudo apt-get autoremove --purge libpixman-1-dev -y
sudo apt-get autoremove --purge libpoppler19 -y
sudo apt-get autoremove --purge libtiff4-dev -y
sudo apt-get autoremove --purge libtiffxx0c2 -y
sudo apt-get autoremove --purge libxcb-render0-dev -y
sudo apt-get autoremove --purge libxcb-shm0-dev -y
sudo apt-get autoremove --purge libxext-dev -y
sudo apt-get autoremove --purge libxfont1 -y
sudo apt-get autoremove --purge libxft-dev -y
sudo apt-get autoremove --purge libxkbfile1 -y
sudo apt-get autoremove --purge libxrender-dev -y
sudo apt-get autoremove --purge libxss-dev -y
sudo apt-get autoremove --purge luatex -y
sudo apt-get autoremove --purge openjdk-6-jdk -y
sudo apt-get autoremove --purge openjdk-6-jre -y
sudo apt-get autoremove --purge openjdk-6-jre-headless -y
sudo apt-get autoremove --purge openjdk-6-jre-lib -y
sudo apt-get autoremove --purge preview-latex-style -y
sudo apt-get autoremove --purge tcl8.5-dev -y
sudo apt-get autoremove --purge tex-common -y
sudo apt-get autoremove --purge texi2html -y
sudo apt-get autoremove --purge texinfo -y
sudo apt-get autoremove --purge texlive-base -y
sudo apt-get autoremove --purge texlive-binaries -y
sudo apt-get autoremove --purge texlive-common -y
sudo apt-get autoremove --purge texlive-doc-base -y
sudo apt-get autoremove --purge texlive-extra-utils -y
sudo apt-get autoremove --purge texlive-fonts-extra -y
sudo apt-get autoremove --purge texlive-fonts-recommended -y
sudo apt-get autoremove --purge texlive-generic-recommended -y
sudo apt-get autoremove --purge texlive-latex-base -y
sudo apt-get autoremove --purge texlive-latex-extra -y
sudo apt-get autoremove --purge texlive-latex-recommended -y
sudo apt-get autoremove --purge texlive-pictures -y
sudo apt-get autoremove --purge tk8.5-dev -y
sudo apt-get autoremove --purge x11-xkb-utils -y
sudo apt-get autoremove --purge x11proto-render-dev -y
sudo apt-get autoremove --purge x11proto-scrnsaver-dev -y
sudo apt-get autoremove --purge x11proto-xext-dev -y
sudo apt-get autoremove --purge xfonts-base -y
sudo apt-get autoremove --purge xfonts-encodings -y
sudo apt-get autoremove --purge xfonts-utils -y
sudo apt-get autoremove --purge xserver-common -y
sudo apt-get autoremove --purge xvfb -y

sudo apt-get autoremove --purge libgnome2-0 -y
sudo apt-get autoremove --purge libmail-sendmail-perl -y	
sudo apt-get autoremove --purge libmailtools-perl -y

sudo apt-get autoremove --purge x11-common -y
sudo apt-get autoremove --purge x11-utils -y
sudo apt-get autoremove --purge x11-xserver-utils -y
sudo apt-get autoremove --purge x11proto-core-dev -y
sudo apt-get autoremove --purge x11proto-input-dev -y
sudo apt-get autoremove --purge x11proto-kb-dev -y	

sudo rm -rf /usr/local/lib/R-3.0.2.tar.gz
sudo rm -rf /usr/local/lib/R-3.0.2/doc
sudo rm -rf /usr/local/lib/R-3.0.2/tests
sudo rm -rf /usr/lib/R/doc
sudo rm -rf /tmp/*.tar.gz
cd /usr/local/lib/R-3.0.2/src/gnuwin32/
sudo make clean

sudo rm -rf /usr/local/EnergyPlus-8-0-0/ExampleFiles
sudo rm -rf /usr/local/EnergyPlus-8-0-0/Documentation
sudo rm -rf /usr/local/EnergyPlus-8-0-0/DataSets
sudo rm -rf /usr/local/lib/ruby/site_ruby/2.0.0/openstudio/sketchup_plugin
sudo rm -rf /usr/local/lib/ruby/site_ruby/2.0.0/openstudio/examples
sudo rm -rf /usr/local/share/openstudio/Ruby/openstudio/sketchup_plugin
sudo rm -rf /usr/local/share/openstudio/Ruby/openstudio/examples
sudo rm -rf /usr/local/share/openstudio/examples
sudo rm -rf /usr/local/share/openstudio/OSApp

sudo rm -rf /usr/share/X11
sudo rm -rf /usr/share/gnome

sudo rm -rf /usr/share/doc

sudo apt-get autoclean
sudo apt-get clean

sudo rm -rf /var/cache/apt/archives/*.deb
sudo rm -rf /var/chef/cache/*.tar.gz
sudo rm -rf /var/chef/cache/*.deb

sudo rm -rf /var/lib/mongodb
sudo rm -rf /tmp/*.tar.gz

cd /var/www/rails/openstudio
rake db:purge
rake db:mongoid:create_indexes
sudo rm -rf /mnt/mongodb/data/journal/*

sudo dd if=/dev/zero of=/EMPTY bs=1M
sudo rm -f /EMPTY
sudo dd if=/dev/zero of=/home/EMPTY bs=1M
sudo rm /home/EMPTY
sudo dd if=/dev/zero of=/usr/EMPTY bs=1M
sudo rm /usr/EMPTY
sudo dd if=/dev/zero of=/var/EMPTY bs=1M
sudo rm /var/EMPTY
sudo dd if=/dev/zero of=/lib/EMPTY bs=1M
sudo rm /lib/EMPTY
sudo dd if=/dev/zero of=/boot/EMPTY bs=1M
sudo rm /boot/EMPTY
sudo dd if=/dev/zero of=/bin/EMPTY bs=1M
sudo rm /bin/EMPTY
sudo dd if=/dev/zero of=/etc/EMPTY bs=1M
sudo rm /etc/EMPTY
#exit