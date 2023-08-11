# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

module ApplicationHelper
  def active_nav(page)
    path = request.path
    active = ' class="active"'.html_safe
    active2 = 'active'.html_safe

    if path == '/projects'
      active if page == 'Projects'
    elsif path == '/admin'
      active if page == 'Admin'
    elsif path == '/about'
      active if page == 'About'
    elsif path == '/nodes'
      active if page == 'Nodes'
    elsif path.include? '/analyses'
      active2 if page == 'Analyses'
    end
  end

  def active_subnav(page)
    # for analyses dropdown
    path = request.path
    active = ' class="active"'.html_safe

    if path.include? page
      active
    end
  end

  def analyses_nav
    @@analyses_for_menu ||= Analysis.all # returns value if exists, or initializes it
  end
end
