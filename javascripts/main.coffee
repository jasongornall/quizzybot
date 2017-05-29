handleLink = ->
  $('a').off('click').on 'click', (e) ->
    $el = $ e.currentTarget
    href = $el.attr 'href'
    return if href[0] isnt '/'
    e.preventDefault();
    path = url 'path', href
    route_url(path or '/')
    return false

timeouts = []
turnOnFireflies = ->
  return if window.fireflies_on
  initialize()
  setInterval(draw,rint);
  $(window).off('resize').on('resize', initialize);
  window.fireflies_on = true

handlePath = (path, $base_el) ->
  while timeouts.length
    clearTimeout timeouts.pop()

  switch path
    when '/'
      $el = $base_el.find('.rewrite')
      $base_el.find('.additions').remove()
      $el.lettering()
      $spans = $el.find('> span')
      async.eachLimit $spans, 2, ((char, next) ->
        $char = $ char
        width = window.innerWidth / 3
        height = window.innerHeight / 3
        x = Math.random() * width  - width / 2
        y = Math.random() * height - height / 2
        $char.attr {
          'style': "left: #{x}px; top: #{y}px;"
        }
        timeouts.push setTimeout (->
          $char.addClass 'show'
          next()
        ), 400
      ), ->
        $sub = $('<div class = "additions"> Welcome to Our Wedding Website </div>')
        $base_el.append $sub
        timeouts.push setTimeout ( ->
          $sub.fadeIn 'slow', ->

            # turn on fireflies
            turnOnFireflies()
        ), 1000
    else

      # turn on fireflies
      turnOnFireflies()


route_url = (path) ->
  $('#body').attr('class','')
  path = path || url 'path'

  data = path.split('/')
  history.replaceState(null, null, path);

  new_path = "/#{data[1] or ''}"
  $("[data-route]").hide()
  $el = $("[data-route='#{new_path}']")
  handlePath new_path, $el
  $el.fadeIn()

  $link = $("#navigation a[href='#{new_path}']")
  $link.addClass 'active'
  $link.siblings().removeClass 'active'

handleLink()
$(window).load ->
  route_url()



