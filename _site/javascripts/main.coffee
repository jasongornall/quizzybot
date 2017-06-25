timeouts = []
intervals = []

showError = (err = 'Error Occued') ->
  $('#popup').html teacup.render ->
    div '.modal', ->
      div '.modal-content', ->
        div '.header', -> 'Error Occured'
        div -> err
handleLink = ->
  $('#popup').on 'click', ->
    $('#popup').empty()
  $('a').off('click').on 'click', (e) ->
    $el = $ e.currentTarget
    href = $el.attr 'href'
    return if href[0] isnt '/'
    e.preventDefault();
    path = url 'path', href
    route_url(path or '/')
    return false

getProfileData = ->
  user = firebase.auth().currentUser
  image = user.photoURL or "/images/profile.jpg"
  name = user.displayName or "Quizzer-#{Math.floor Math.random() * 1000}"
  uid = firebase.auth().currentUser.uid
  return {
    name
    image
    uid
  }
cleanup = ->
  while timeouts.length
    clearTimeout timeouts.pop()
  while intervals.length
    clearInterval intervals.pop()

calculatePonts = (ts) ->
  base = 1
  base += Math.floor (Date.now() - ts) / 1000

handleAuth = (next) ->
  new_user = false
  firebase.auth().onAuthStateChanged (user) ->
    if user
      if user.isAnonymous
        $('html').addClass 'logged-out'
        if new_user
          user.updateProfile({
            displayName: "Quizzer-#{Math.floor Math.random() * 1000}"
            photoURL: "/images/profile.jpg"
          }).then next
        else
          next()
      else
        $('html').addClass 'logged-in'
        next()
    else
      new_user = true
      firebase.auth().signInAnonymously()

      next()

handleRoute = (route, $el) ->
  # kill all listeners
  firebase.database().ref().off()

  switch route

    when '/login'
      user = firebase.auth().currentUser
      if user?.isAnonymous is false
        firebase.database().ref("users/#{user.uid}").on 'value', (data)->
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
            div '.logins', ->
              div '.basic', ->
                div '.router-header', -> 'Login'
                div -> 'email'
                input '.email', type: 'text', placeholder: 'email'
                div -> 'password'
                input '.password', type: 'password', placeholder: 'password'
                div '.login', 'data-login': 'login',  -> "Login with your account"
              div '.basic', ->
                div '.router-header', -> 'Signup'
                div -> 'email'
                input '.email', type: 'text', placeholder: 'email'
                div -> 'password'
                input '.password', type: 'password', placeholder: 'password'
                div -> 'password (again)'
                input '.password-again', type: 'password', placeholder: 'password (again):'
                div '.login', 'data-login': 'signup',  -> "Signup with your email"
        $el.find('[data-login]').off('click').on 'click', (e) ->
          auth = $(e.currentTarget).data 'login'
          switch auth

            when 'google'
              provider = new firebase.auth.GoogleAuthProvider();
              firebase.auth().signInWithRedirect(provider)

            when 'signup'
              $el = $ e.currentTarget
              password = $el.siblings('.password').val()
              password_two = $el.siblings('.password-again').val()
              if password isnt password_two
                showError 'Password do not match!'

              email = $el.siblings('.email').val()
              firebase.auth().createUserWithEmailAndPassword(email, password).catch (error) ->
                showError error.message if error

            when 'login'
              $el = $ e.currentTarget
              password = $el.siblings('.password').val()
              email = $el.siblings('.email').val()
              firebase.auth().signInWithEmailAndPassword(email, password).catch (error) ->
                showError error.message if error

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
        correct = "#{data.child('correct').val()}"
        $guesses.append teacup.render ->
          div '.guess', ->
            div '.profile', ->
              img src: data.child('owner/image').val()

            div '.attempt', 'data-correct': correct, ->
              span '.username', -> data.child('owner/name').val()
              span '.name', -> data.child('answer').val()
            hr()

        out = $guesses[0]

        # stay scrolled to bottom
        isScrolledToBottom = out.scrollHeight - out.clientHeight <= out.scrollTop + 70
        if isScrolledToBottom
          out.scrollTop = out.scrollHeight - out.clientHeight;

        # slcie as needed
        $guesses.find('.guess').slice(0, 0 - 100).remove()

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
              'owner': firebase.auth().currentUser.uid
            }, (err) ->
              next null, not err?

          (correct, next) ->
            firebase.database().ref("guesses").push {
              'answer': answer
              'correct': correct
              'owner': getProfileData()
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



