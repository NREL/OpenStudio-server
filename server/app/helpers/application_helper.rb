module ApplicationHelper

  def active_nav(page)
    path = request.path
    active = ' class="active"'.html_safe

    case
      when path == '/projects'
        active if page == 'Projects'
      when path == '/admin'
        active if page == 'Admin'
      when path == '/about'
        active if page == 'About'
    end
  end

end

