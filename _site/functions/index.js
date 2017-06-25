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

exports.helloWorld = functions.https.onRequest((req, res) => {
  cors(req, res, () => {
    res.status(200).send('hello world');
  });
});

exports.helloWorld_2 = functions.https.onRequest((req, res) => {
  cors(req, res, () => {
    res.status(200).send('hello world');
  });
});

exports.newQuestion = functions.database.ref('/active_question/public/user')
  .onWrite(event => {

    var user_data = event.data.val();
    if (!user_data || !user_data.owner) {
      return Promise.reject('already processing')
    }

    // grab next question
    var snapshot;
    event.data.adminRef.root.child('question_bucket').once('child_added')
    .then(function(ss) {
      snapshot = ss
      return event.data.adminRef.database.ref('active_question').once('value')
    })

    // grab active question
    .then(function(active_question) {

      // update user points
      return event.data.adminRef.database.ref('/users/' + user_data.owner + '/points').transaction(function(points) {
        points = points || 0
        console.log(active_question.val())

        var ts = active_question.child('public/ts').val()
        return points += 1 + Math.floor (Date.now() - ts) / 60 / 60 / 1000
      })
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
  });
