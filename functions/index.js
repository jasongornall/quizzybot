/**
 * Copyright 2016 Google Inc. All Rights Reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
'use strict';

// [START all]
// [START import]
const functions = require('firebase-functions');

const admin = require('firebase-admin');
admin.initializeApp(functions.config().firebase);

const cors = require('cors')({origin: true});



exports.newQuestion = functions.database.ref('/active_question/public/user')
  .onWrite(event => {

    var user_data = event.data.val();
    if (!user_data || !user_data.owner) {
      return Promise.reject('already processing')
    }
    var my_active_question;

    // grab next question
    var snapshot;
    event.data.adminRef.root.child('question_bucket').once('child_added')
    .then(function(ss) {
      snapshot = ss
      return event.data.adminRef.database.ref('active_question').once('value')
    })

    // grab active question
    .then(function(active_question) {
      my_active_question = active_question.val()

      // update user points
      return event.data.adminRef.database.ref('/users/' + user_data.owner + '/points').transaction(function(points) {
        points = points || 0
        var ts = active_question.child('public/ts').val()
        return points += 1 + Math.floor (Date.now() - ts) / 60 / 60 / 1000
      })
    })

    // grab guesses
    .then(function(ss) {
      return event.data.adminRef.database.ref('guesses').once('value')
    })


    // set old Q and Guesses in old Q array
    .then(function(old_guesses_doc) {
      var active_q = my_active_question;
      active_q.public.end_ts = Date.now();

      // same key used in both places
      var key = event.data.adminRef.root.child('old_questions').push().key;

      // push to old places
      var setQ = event.data.adminRef.root.child('old_questions/' + key).set({
        question: active_q
      });
      var setG = event.data.adminRef.root.child('old_guesses/' + key).set({
        guesses: old_guesses_doc.val()
      });
      return Promise.all([setQ, setG]);
    })

    // empty guesses
    .then(function() {
      return event.data.adminRef.root.child('guesses').remove();
    })

    // set new q
    .then(function() {
      var new_data = snapshot.val()
      new_data.public.ts = Date.now()
      return event.data.adminRef.root.child('active_question').set(new_data)
    })

    // remove original Q
    .then(function() {
      return snapshot.ref.remove()
    })

    .then(function(){
      var headers = {
        "Content-Type": "application/json; charset=utf-8",
        "Authorization": `Basic ${functions.config().onesignal.secret}`
      };

      var options = {
        host: "onesignal.com",
        port: 443,
        path: "/api/v1/notifications",
        method: "POST",
        headers: headers
      };
      var message = {
        app_id: functions.config().onesignal.app_id,
        headings: {
          "en": "A QuizzyBot Question has changed!"
        },
        contents: {
          "en": "Check out the new riddle!"
        },
        included_segments: ["All"]
      }
      var https = require('https');
      var req = https.request(options, function(res) {
        res.on('data', function(data) {
          console.log('sent');
          Promise.resolve(JSON.parse(data));
        });
      });

      req.on('error', function(e) {
        console.log("ERROR:", e);
        Promise.reject(e);
      });

      req.write(JSON.stringify(message));
      req.end();
    })
  });
