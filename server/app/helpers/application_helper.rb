module ApplicationHelper

  def active_nav(page)
    path = request.path
    active = ' class="active"'.html_safe

    case
      when path == '/'
        active if page == 'home'
      when path == '/start'
        active if page == 'start'
      #when path == '/about'
      #  active if page == 'about'
    end
  end

end
