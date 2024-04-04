jQuery ->
  $(".backtrace").click (e) ->
    e.preventDefault()
    $(this).next().toggle()

  $("ul.failed li").hover ->
    $(this).toggleClass "hover"
