#!/bin/sh

sudo apt-get autoremove --purge gir1.2-freedesktop -y
sudo apt-get autoremove --purge gir1.2-glib-2.0 -y

sudo apt-get autoremove --purge openjdk-6-jdk -y
sudo apt-get autoremove --purge openjdk-6-jre -y
sudo apt-get autoremove --purge openjdk-6-jre-headless -y
sudo apt-get autoremove --purge openjdk-6-jre-lib -y
sudo apt-get autoremove --purge preview-latex-style -y
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

sudo rm -rf /usr/local/lib/R-3.0.2.tar.gz
sudo rm -rf /usr/local/lib/R-3.0.2/doc
sudo rm -rf /usr/local/lib/R-3.0.2/tests
sudo rm -rf /usr/lib/R/doc
sudo rm -rf /tmp/*.tar.gz
cd /usr/local/lib/R-3.0.2/src/gnuwin32/
sudo make clean

sudo rm -rf /usr/local/EnergyPlus-8-0-0/ExampleFiles/*
sudo rm -rf /usr/local/EnergyPlus-8-0-0/Documentation/*
sudo rm -rf /usr/local/EnergyPlus-8-0-0/DataSets/*
sudo rm -rf /usr/local/lib/ruby/site_ruby/2.0.0/openstudio/sketchup_plugin
sudo rm -rf /usr/local/lib/ruby/site_ruby/2.0.0/openstudio/examples
sudo rm -rf /usr/local/share/openstudio/Ruby/openstudio/sketchup_plugin
sudo rm -rf /usr/local/share/openstudio/Ruby/openstudio/examples
sudo rm -rf /usr/local/share/openstudio/examples
sudo rm -rf /usr/local/share/openstudio/OSApp

sudo apt-get autoclean
sudo apt-get clean

sudo rm -rf /var/cache/apt/archives/*.deb
sudo rm -rf /var/chef/cache/*.tar.gz
sudo rm -rf /var/chef/cache/*.deb

sudo rm -rf /var/lib/mongodb