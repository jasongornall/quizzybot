// Generated by CoffeeScript 1.8.0
var calculatePonts, cleanup, getProfileData, handleAuth, handleLink, handleRoute, intervals, route_url, timeouts;

timeouts = [];

intervals = [];

handleLink = function() {
  return $('a').off('click').on('click', function(e) {
    var $el, href, path;
    $el = $(e.currentTarget);
    href = $el.attr('href');
    if (href[0] !== '/') {
      return;
    }
    e.preventDefault();
    path = url('path', href);
    route_url(path || '/');
    return false;
  });
};

getProfileData = function() {
  var image, name, uid, user;
  user = firebase.auth().currentUser;
  image = user.photoURL || "/images/profile.jpg";
  name = user.displayName || ("Quizzer-" + (Math.floor(Math.random() * 1000)));
  uid = firebase.auth().currentUser.uid;
  return {
    name: name,
    image: image,
    uid: uid
  };
};

cleanup = function() {
  var _results;
  while (timeouts.length) {
    clearTimeout(timeouts.pop());
  }
  _results = [];
  while (intervals.length) {
    _results.push(clearInterval(intervals.pop()));
  }
  return _results;
};

calculatePonts = function(ts) {
  var base;
  base = 1;
  return base += Math.floor((Date.now() - ts) / 1000);
};

handleAuth = function(next) {
  var new_user;
  new_user = false;
  return firebase.auth().onAuthStateChanged(function(user) {
    if (user) {
      if (user.isAnonymous) {
        $('html').addClass('logged-out');
        if (new_user) {
          return user.updateProfile({
            displayName: "Quizzer-" + (Math.floor(Math.random() * 1000)),
            photoURL: "/images/profile.jpg"
          }).then(next);
        } else {
          return next();
        }
      } else {
        $('html').addClass('logged-in');
        return next();
      }
    } else {
      new_user = true;
      firebase.auth().signInAnonymously();
      return next();
    }
  });
};

handleRoute = function(route, $el) {
  var $form, $guesses, user;
  firebase.database().ref().off();
  switch (route) {
    case '/login':
      user = firebase.auth().currentUser;
      if ((user != null ? user.isAnonymous : void 0) === false) {
        return firebase.database().ref("users/" + user.uid).on('value', function(data) {
          return $el.html(teacup.render(function() {
            div('.profile', function() {
              div('.router-header', function() {
                return 'My Profile';
              });
              img({
                src: user.photoURL
              });
              span(function() {
                return 'Display Name ';
              });
              return input('.name', {
                value: user.displayName
              });
            });
            div('.quizzypoints', function() {
              return "" + (data.child('points').val() || 0);
            });
            return div('.purchased-items', function() {
              return 'TBD';
            });
          }));
        });
      } else {
        $el.html(teacup.render(function() {
          div('.router-header', function() {
            return 'Login to save your points!';
          });
          return div('.logged-out', function() {
            div('.description', function() {
              return 'This is just to connect the account I won\'t take any of your creds\nI didn\'t want to bother with forgot password flow etc.. so just\nriding the back of one of the many social networks that are\nalready out there';
            });
            div('.socials', function() {
              div('.facebook', {
                'data-login': 'facebook'
              }, function() {
                return 'Login with Facebook';
              });
              div('.google', {
                'data-login': 'google'
              }, function() {
                return 'Login with Google';
              });
              return div('.twitter', {
                'data-login': 'twitter'
              }, function() {
                return 'Login with Twitter';
              });
            });
            return div('.logins', function() {
              div('.basic', function() {
                div('.router-header', function() {
                  return 'Login';
                });
                div(function() {
                  return 'email';
                });
                input('.email', {
                  type: 'text',
                  placeholder: 'email'
                });
                div(function() {
                  return 'password';
                });
                input('.password', {
                  type: 'password',
                  placeholder: 'password'
                });
                return div('.login', {
                  'data-login': 'login'
                }, function() {
                  return "Login with your account";
                });
              });
              return div('.basic', function() {
                div('.router-header', function() {
                  return 'Signup';
                });
                div(function() {
                  return 'email';
                });
                input('.email', {
                  type: 'text',
                  placeholder: 'email'
                });
                div(function() {
                  return 'password';
                });
                input('.password', {
                  type: 'password',
                  placeholder: 'password'
                });
                div(function() {
                  return 'password (again)';
                });
                input('.password-again', {
                  type: 'password',
                  placeholder: 'password (again):'
                });
                return div('.login', {
                  'data-login': 'signup'
                }, function() {
                  return "Signup with your email";
                });
              });
            });
          });
        }));
        return $el.find('[data-login]').off('click').on('click', function(e) {
          var auth, email, password, provider;
          auth = $(e.currentTarget).data('login');
          switch (auth) {
            case 'google':
              provider = new firebase.auth.GoogleAuthProvider();
              return firebase.auth().signInWithRedirect(provider);
            case 'signup':
              $el = $(e.currentTarget);
              password = $el.siblings('.password').val();
              email = $el.siblings('.email').val();
              return firebase.auth().createUserWithEmailAndPassword(email, password)["catch"](function(error) {
                return console.log(error, '123');
              });
            case 'login':
              $el = $(e.currentTarget);
              password = $el.siblings('.password').val();
              email = $el.siblings('.email').val();
              return firebase.auth().signInWithEmailAndPassword(email, password)["catch"](function(error) {
                return console.log(error, '333');
              });
          }
        });
      }
      break;
    case '/store':
      return firebase.database().ref("store").on('value', function(data) {
        return $el.html(teacup.render(function() {
          div('.router-header', function() {
            return 'Quizzybot store!';
          });
          div('.description', function() {
            return 'Spend your knowledge to try to stump the net!';
          });
          return div('.store-front', function() {
            var item, _i, _len, _ref, _results;
            _ref = data.val();
            _results = [];
            for (_i = 0, _len = _ref.length; _i < _len; _i++) {
              item = _ref[_i];
              _results.push(div('.store-item', {
                'data-type': item.type
              }, function() {
                div('.name', function() {
                  return item.type;
                });
                div('.description', function() {
                  return item.description;
                });
                return div('.cost', function() {
                  return "" + item.cost + " QuizzyPoints";
                });
              }));
            }
            return _results;
          });
        }));
      });
    case '/':
      $el.html(teacup.render(function() {
        div('.router-header', function() {
          return 'Quizzybot game!';
        });
        div('.question');
        div('.guesses');
        return form('.answer-form', function() {
          input('.guess-field');
          return input({
            type: 'submit',
            value: 'submit'
          });
        });
      }));
      firebase.database().ref("active_question/public").on('value', function(data) {
        return $el.find('.question').html(teacup.render(function() {
          div(function() {
            return 'Welcome to the Quiz Game!\nJust answer the Current Riddle in a comment on this post and win...\nquizbot points!\nYeah! You can spend them over in the shop section';
          });
          h1(function() {
            return 'Question';
          });
          div('.text', function() {
            return "" + (data.child('question').val());
          });
          h3(function() {
            return 'Points';
          });
          return div('.points', function() {
            return "" + (calculatePonts(data.child('ts').val()));
          });
        }));
      });
      $guesses = $el.find('> .guesses');
      firebase.database().ref("guesses").limitToFirst(100).on('child_added', function(data) {
        var correct, isScrolledToBottom, out;
        correct = "" + (data.child('correct').val());
        $guesses.append(teacup.render(function() {
          return div('.guess', function() {
            div('.profile', function() {
              return img({
                src: data.child('owner/image').val()
              });
            });
            div('.attempt', {
              'data-correct': correct
            }, function() {
              span('.username', function() {
                return data.child('owner/name').val();
              });
              return span('.name', function() {
                return data.child('answer').val();
              });
            });
            return hr();
          });
        }));
        out = $guesses[0];
        isScrolledToBottom = out.scrollHeight - out.clientHeight <= out.scrollTop + 70;
        if (isScrolledToBottom) {
          out.scrollTop = out.scrollHeight - out.clientHeight;
        }
        return $guesses.find('.guess').slice(0, 0 - 100).remove();
      });
      $form = $('.answer-form');
      return $form.submit(function() {
        var $guest, answer;
        $guest = $el.find('form .guess-field');
        answer = $guest.val();
        $guest.val('');
        async.waterfall([
          function(next) {
            return firebase.database().ref("active_question/public/user").set({
              'answer': answer,
              'owner': firebase.auth().currentUser.uid
            }, function(err) {
              return next(null, err == null);
            });
          }, function(correct, next) {
            return firebase.database().ref("guesses").push({
              'answer': answer,
              'correct': correct,
              'owner': getProfileData()
            }, function(err) {
              return next(err);
            });
          }
        ], function(err) {
          if (err) {
            return console.log(err);
          }
        });
        return false;
      });
  }
};

route_url = function(path) {
  var $el, $link, data, new_path;
  $('#body').attr('class', '');
  path = path || url('path');
  data = path.split('/');
  history.replaceState(null, null, path);
  new_path = "/" + (data[1] || '');
  $("[data-route]").hide();
  $el = $("[data-route='" + new_path + "']");
  handleRoute(new_path, $el);
  $el.fadeIn();
  $link = $("#navigation a[href='" + new_path + "']");
  $link.addClass('active');
  return $link.siblings().removeClass('active');
};

handleLink();

$(window).load(function() {
  return handleAuth(function() {
    return route_url();
  });
});
