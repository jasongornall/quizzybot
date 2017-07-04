timeouts = []
intervals = []
MY_user_data = null
showError = (err = 'Error Occued') ->
  $('#popup').html teacup.render ->
    div '.modal', ->
      div '.modal-content', ->
        div '.header', -> 'Error Occured'
        div -> err


renderTimeouts = {}
setTimeoutStr = (str, length, func) ->
  clearTimeout renderTimeouts[str]
  renderTimeouts[str] = setTimeout func, length * 1000


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
  console.log route, 'sssssss'
  switch route

    when '/old'
      console.log 'a'
      firebase.database().ref("old_questions").on 'value', (data) ->
        $el.html teacup.render ->
          for key, {question} of data.val()
            console.log key, question, 'wakka'
            div '.question', 'data-key': key, ->
              h1 -> 'Question'
              div '.text', -> "#{question.public.question}"

              h3 -> 'Answer'
              div '.points', -> "#{question.public.user.answer}"

              h3 -> 'pointed gained'
              div '.points', -> "#{question.public.end_ts - question.public.ts}"



    when '/login'
      if user?.isAnonymous is false
        firebase.database().ref("users/#{user.uid}").once 'value', (profile_doc)->
          $el.html teacup.render ->
            div '.profile', ->
              div '.router-header', -> 'My Profile'
              div '.modify', ->
                img '.profile', src: profile_doc.child('photoURL').val()
                input '.profile', type: 'file', accept: "image/*"
              div '.modify', ->
                span -> 'Display Name '
                input '.name', value: profile_doc.child('displayName').val()
              div '.save', -> 'Save Changes'
              div '.status', ->
                div '.saved', -> 'Saved!'
                div '.saving', -> 'Saving...'
                div '.error', -> 'Error Occured.. photo too large?'
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

          $save = $el.find('.save')
          $save.off('click').on 'click', (e) ->
            $el.find('.status').attr 'data-state', 'saving'
            async.parallel [
              (next) =>
                profile_doc.child('displayName').ref.set $el.find('input.name').val(), next

              (next) =>
                file = $el.find('img.profile').data 'file'
                return next() unless file
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
              if err
                $el.find('.status').attr 'data-state', 'error'
              else
                $el.find('.status').attr 'data-state', 'saved'
                MY_user_data = null

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
            div '.store-item', 'data-type': 'riddle', ->
              div '.header', ->
                div '.name', -> 'Riddle'
                div '.description', -> 'Add your own question into the quizzy game!'
                div '.cost', -> "100 QuizzyPoints"
              div '.form', ->
                div -> 'Riddle Title'
                textarea '.riddle'

                div -> 'hint 1 (after 24 hours) (optional)'
                textarea '.hint.1'

                div -> 'hint 2 (after 48 hours) (optional)'
                textarea '.hint.2'

                div -> 'hint 3 (after 72 hours) (optional)'
                textarea '.hint.3'

                div -> 'answer'
                textarea '.answer'

                div '.submit', -> 'submit'

        $el.find('.store-item .header').on 'click', (e) ->
          $el =  $ e.currentTarget
          $el.siblings('.form').slideToggle()
        $el.find('.store-item[data-type=riddle] .submit').on 'click', (e) ->
          $form = $(e.currentTarget).closest('.form')


          key = firebase.database().ref().child('question_bucket').push().key;
          uid = firebase.auth().currentUser.uid
          firebase.database().ref("users/#{uid}").once 'value', (profile_doc) ->
            current_points = profile_doc.child('points').val() or 0
            updates = {}


            updates["users/#{uid}/points"] = current_points - 100
            updates["question_bucket/#{key}"] = {
              private:
                answer: $form.find('.answer').val()
                hint_1: $form.find('.hint.1').val()
                hint_2: $form.find('.hint.2').val()
                hint_3: $form.find('.hint.3').val()
              public:
                riddle: $form.find('.riddle').val()
                owner: firebase.auth().currentUser.uid
            }
            console.log updates, '213'
            firebase.database().ref().update(updates).then((result) ->
              console.log result, '123'
            ).catch (error) ->
              console.log error

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
        return if $el.find('.question .wrapper').data('ts') is data.child('ts').val()
        $el.find('.question').html teacup.render ->
          div '.wrapper', 'data-ts': data.child('ts').val(), ->
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
      force = true
      setTimeout (->
        force = false
      ), 3000

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
        if force or isScrolledToBottom
          console.log $guesses.prop('scrollHeight')
          $guesses.scrollTop($guesses.prop('scrollHeight'));

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
              'ts':  firebase.database.ServerValue.TIMESTAMP
            }, (err) ->
              next null, not err?

          (correct, next) ->
            getProfileData (owner) ->
              firebase.database().ref("guesses").push {
                'answer': answer
                'correct': correct
                'owner': owner
                'ts':  firebase.database.ServerValue.TIMESTAMP
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

  console.log 'aaa', path
  $el.fadeIn 200, ->
    console.log 'r'
    handleRoute new_path, $el

  $link = $("#navigation a[href='#{new_path}']")
  $link.addClass 'active'
  $link.siblings().removeClass 'active'

handleLink()
$(window).load ->
  handleAuth ->
    route_url()



