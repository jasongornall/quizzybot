timeouts = []
intervals = []
MY_user_data = null
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

getProfileData = (next) ->
  user = firebase.auth().currentUser
  getData = (next) ->
    console.log MY_user_data
    return next MY_user_data if MY_user_data
    firebase.database().ref("users/#{user.uid}").once 'value', (data) =>
      MY_user_data = data
      console.log MY_user_data, 'wtf'
      next MY_user_data
  getData (data) ->
    next {
      name: data.child('displayName').val()
      image: data.child('photoURL').val()
      uid: user.uid

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
          firebase.database().ref("users/#{user.uid}").set {
            displayName: "Quizzer-#{Math.floor Math.random() * 1000}"
            photoURL: "/images/profile.jpg"
          }, next
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
  user = firebase.auth().currentUser
  switch route

    when '/login'
      if user?.isAnonymous is false
        firebase.database().ref("users/#{user.uid}").once 'value', (profile_doc)->
          $el.html teacup.render ->
            div '.header.profile', ->
              div '.router-header', -> 'My Profile'
              img '.profile', src: profile_doc.child('photoURL').val()
              input '.profile', type: 'file', accept: "image/*"
              span -> 'Display Name '
              input '.name', value: profile_doc.child('displayName').val()

              div '.save', -> 'Save Changes'
            div '.quizzypoints', -> "#{profile_doc.child('points').val() or 0}"
            div '.purchased-items', -> 'TBD'

          $el.find('input.name').change ->
            $el.find('.header').addClass 'pending-save'
          $el.find('input.profile').change ->
            if (this.files && this.files[0])
              reader = new FileReader();
              my_file = this.files[0]
              reader.onload = (e) ->
                $image_profile = $el.find('img.profile')
                $image_profile.load ->
                  $image_profile.data 'file', my_file
                  $el.find('.header').addClass 'pending-save'
                $image_profile.attr 'src', e.target.result
              reader.readAsDataURL(my_file);

          $el.find('.save').off('click').on 'click', (e) ->
            console.log 'inside'
            async.parallel [
              (next) =>
                profile_doc.child('displayName').ref.set $el.find('input.name').val(), next

              (next) =>
                file = $el.find('img.profile').data 'file'
                return done_profile unless file
                storageRef = firebase.storage().ref("users/#{user.uid}/profile")
                upload_task = storageRef.put(file)

                upload_task.on 'state_changed', ((snapshot) ->
                ), ((error) ->

                  # Handle unsuccessful uploads
                  return next 'error occured'
                ), ->

                  # Handle successful uploads on complete
                  # For instance, get the download URL: https://firebasestorage.googleapis.com/...
                  new_url = "https://images.infernalscoop.com/users/#{user.uid}/profile?_=#{Date.now()}"
                  profile_doc.child('photoURL').ref.set new_url, next
            ], (err) ->
              console.log err, '123'

      else
        firebase.database().ref("users/#{user.uid}").once 'value', (data) ->
          $el.html teacup.render ->
            div '.error', -> ''
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
                  'Login'
                div '.google', 'data-login': 'google', ->
                  'Login'
                div '.twitter', 'data-login': 'twitter', ->
                  'Login'
              if data.child('points').val()
                div '.description', -> '''
                  It looks like you have already gotten some quizzypoints Good Job!
                  Click below to convert into a permanent account!
                '''
                div '.social-connect', ->
                  div '.facebook', 'data-login':'facebook', ->
                    'Connect Points'
                  div '.google', 'data-login': 'google', ->
                    'Connect Points'
                  div '.twitter', 'data-login': 'twitter', ->
                    'Connect Points'


          $el.find('.social-connect [data-login]').off('click').on 'click', (e) ->
            console.log e, '123'
            auth = $(e.currentTarget).data 'login'
            switch auth

              when 'google'
                firebase.auth().currentUser.linkWithPopup(new firebase.auth.GoogleAuthProvider()).then((result) ->
                  route_url '/login'
                ).catch (error) ->
                  $el.find('> .error').append teacup.render ->
                    div -> "#{error.message} #{error.code}"


          $el.find('.socials [data-login]').off('click').on 'click', (e) ->
            auth = $(e.currentTarget).data 'login'
            switch auth

              when 'google'
                provider = new firebase.auth.GoogleAuthProvider();
                firebase.auth().signInWithPopup(provider).then((result) ->
                  route_url '/login'
                ).catch (error) ->
                  $el.find('> .error').append teacup.render ->
                    div -> "#{error.message} #{error.code}"

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
      firebase.database().ref("guesses").limitToLast(100).on 'child_added', (data) ->
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
            getProfileData (owner) ->
              firebase.database().ref("guesses").push {
                'answer': answer
                'correct': correct
                'owner': owner
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



