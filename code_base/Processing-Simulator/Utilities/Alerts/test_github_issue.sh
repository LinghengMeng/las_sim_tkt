curl -X "POST" "https://api.github.com/repos/pbarch/Processing-Simulator/issues?state=all" \
     -H "Cookie: logged_in=no" \
     -H "Authorization: token f045c673eee2bd1dfaf99b0af13dd86d5b3c8d87" \
     -H "Content-Type: text/plain; charset=utf-8" \
     -d $'{
  "title": "(TEST) Futurium lost PI#4",
  "body": "More testing --> SOMETHING HAPPENED (not really, this is a test)",
  "assignees": [
    "mgorbet"
  ],
  "labels": [
    "INCIDENT ALERT"
      ]
}'