jQuery ->
  poll_interval = 2

  poll_start = (el) ->
    href = el.attr("href")
    el.parent().text "Starting..."
    $("#main").addClass "polling"
    setInterval (->
      $.ajax
        dataType: "text"
        type: "get"
        url: href
        success: (data) ->
          $("#main").html data
          $("#main .time").relativeDate()
    ), poll_interval * 1000
    location.hash = "#poll"

  # auto start if hash is poll
  poll_start $("a[rel=poll]")  if location.hash == "#poll"

  # start when click on link
  $("a[rel=poll]").click (e) ->
    e.preventDefault()
    poll_start $(this)
