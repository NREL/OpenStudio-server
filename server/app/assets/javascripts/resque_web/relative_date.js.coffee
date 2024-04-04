jQuery ->
  relatizer = ->
    dt = $(this).text()
    $(this).relativeDate()
    relatized = $(this).text()
    if $(this).parents("a").length > 0 || $(this).is("a")
      $(this).relativeDate()
      $(this).attr("title", dt) unless $(this).attr("title")
    else
      $(this).html """
        <a href='#'' class='toggle_format' title='#{dt}'>
          <span class='date_time'>#{dt}</span>
          <span class='relatized_time'>#{relatized}</span>
        </a>
      """

  format_toggler = (e) ->
    e.preventDefault()
    $(".time a.toggle_format span").toggle()
    $(this).attr "title", $("span:hidden", this).text()

  # changed html when doom is ready
  $(".time").each relatizer
  $(".time a.toggle_format .date_time").hide()

  # add event on click in relative time to show date_time
  $(".time").on "click", "a.toggle_format", format_toggler
