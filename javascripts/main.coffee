
timeouts = []
intervals = []
handleLink = ->
  $('a').off('click').on 'click', (e) ->
    $el = $ e.currentTarget
    href = $el.attr 'href'
    return if href[0] isnt '/'
    e.preventDefault();
    path = url 'path', href
    route_url(path or '/')
    return false

cleanup = ->
  while timeouts.length
    clearTimeout timeouts.pop()
  while intervals.length
    clearInterval intervals.pop()

calculatePonts = (ts) ->
  base = 1
  base += Math.floor (Date.now() - ts) / 1000 / 60 / 60

handleRoute = (route, $el) ->
  console.log route, '123'
  switch route

    when '/'

      # initial render
      $el.html teacup.render ->
        div '.question'
        div '.guesses'

        form '.answer-form', ->
          input '.guess-field'
          input type: 'submit', value: 'submit'

      # render question
      firebase.database().ref("active_question/public").on 'value', (data) ->
        console.log data.val()
        $el.find('.question').html teacup.render ->
          div -> '''
            Welcome to the Quiz Game!
            Just answer the Current Riddle in a comment on this post and win...
            quizbot points!
            Yeah! You can spend them over in the shop section
          '''

          h1 -> 'Question'
          div '.text', -> "#{data.child('question').val()}"

          h3 -> 'Points'
          div '.points', -> "#{calculatePonts data.child('ts').val()}"


      # render answer
      $guesses = $el.find('> .guesses')
      firebase.database().ref("guesses").limitToFirst(100).on 'child_added', (data) ->
        $guesses.append teacup.render ->
          correct = data.child('correct').val()

          div '.guess', ->
            span '.name', -> data.child('answer').val()
            span '.guess', -> correct


      # form submit
      $form = $('.answer-form')
      $form.submit ->
        $guest = $el.find('form .guess-field')
        answer = $guest.val()
        $guest.val ''

        async.waterfall [
          (next) ->
            firebase.database().ref("active_question/public/user").set {
              'answer': answer
              'owner': 'wakka'
            }, (err) ->
              next null, not err?

          (correct, next) ->
            firebase.database().ref("guesses").push {
              'answer': answer
              'correct': correct
            }, (err) ->
              next err
        ], (err) ->
          console.log err if err
        return false

route_url = (path) ->
  $('#body').attr('class','')
  path = path || url 'path'

  data = path.split('/')
  history.replaceState(null, null, path);

  new_path = "/#{data[1] or ''}"

  $("[data-route]").hide()
  $el = $("[data-route='#{new_path}']")
  handleRoute new_path, $el
  $el.fadeIn()

  $link = $("#navigation a[href='#{new_path}']")
  $link.addClass 'active'
  $link.siblings().removeClass 'active'

handleLink()
$(window).load ->
  route_url()



