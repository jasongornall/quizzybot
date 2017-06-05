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

handleAuth = (next)->
  firebase.auth().onAuthStateChanged (user) ->
    if firebase.auth().currentUser
      $('html').addClass 'logged-in'
      next()
    else
      firebase.auth().signInAnonymously()
      $('html').addClass 'logged-out'
      next()

handleRoute = (route, $el) ->
  # kill all listeners
  firebase.database().ref().off()

  switch route

    when '/login'
      user = firebase.auth().currentUser
      if user?.isAnonymous is false
        firebase.database().ref("uid/#{user.uid}").on 'value', (data)->
          $el.html teacup.render ->
            div '.profile', ->
              div '.router-header', -> 'My Profile'
              img src: user.photoURL
              span -> 'Display Name '
              input '.name', value: user.displayName
            div '.quizzypoints', -> "#{data.child('points').val() or 0}"
            div '.purchased-items', -> 'TBD'
      else
        $el.html teacup.render ->
          div '.router-header', -> 'Login to save your points!'
          div '.logged-out', ->
            div '.description', -> '''
              This is just to connect the account I won't take any of your creds
              I didn't want to bother with forgot password flow etc.. so just
              riding the back of one of the many social networks that are
              already out there
            '''
            div '.socials', ->
              div '.facebook', 'data-login':'facebook', ->
                'Login with Facebook'
              div '.google', 'data-login': 'google', ->
                'Login with Google'
              div '.twitter', 'data-login': 'twitter', ->
                'Login with Twitter'
        $el.find('.socials [data-login]').off('click').on 'click', (e) ->
          auth = $(e.currentTarget).data 'login'
          console.log auth, '123'
          switch auth
            when 'google'
              provider = new firebase.auth.GoogleAuthProvider();
              firebase.auth().signInWithRedirect(provider)

    when '/store'
      firebase.database().ref("store").on 'value', (data) ->
        $el.html teacup.render ->
          div '.router-header', -> 'Quizzybot store!'
          div '.description', -> 'Spend your knowledge to try to stump the net!'
          div '.store-front', ->
            for item in data.val()
              div '.store-item', 'data-type': item.type, ->
                div '.name', -> item.type
                div '.description', -> item.description
                div '.cost', -> "#{item.cost} QuizzyPoints"

    when '/'

      # initial render
      $el.html teacup.render ->
        div '.router-header', -> 'Quizzybot game!'
        div '.question'
        div '.guesses'

        form '.answer-form', ->
          input '.guess-field'
          input type: 'submit', value: 'submit'

      # render question
      firebase.database().ref("active_question/public").on 'value', (data) ->
        console.log data, 'panda'
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
            span '.guess', -> "#{correct}"

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
  handleAuth ->
    route_url()



