## Tech Specification

---

Used Technology: Backend (Java Spring Boot), Mobile (Flutter for Android and IOS)

---

#### STEPS

- Tracks user steps from mobile and sends it to backend to store it and returns these data using GET endpoints
  """
  {
  "time_interval": {
  "start": "start timestamp",
  "end": "end timestamp"
  },
  "steps_value": "count of steps done in this period"
  }
  """ -> json that mobile sends to backend

Backend returns:
GET stepsForToday(Date date) -> Amount of steps for given day
GET stepsByIntervals(Date date) -> Amount of steps by intervals in given day

#### Activity (Run, Biking, Walking etc)

- Tracks distance, records by interval, pace, time and path of activity on the map

- Ability to run together with friends.
  - Permission (User gives permission to allow his friends to see his activities)
  - If permission is given friends can join activity and in map they can see each other with their path.
  - In settings we have to have toggle button that specifies should user accept friends join manually or automatically. If its manual then user receives dialog window with accept or deny button.

- Paints activity path using animation(? at least it should be smooth) in flutter app.

- Sends location of User periodically to backend server. If User runs/walks with friends sends location with interval 1-2seconds using REST or WebSocket and if user runs alone, then sends location using batches within interval 30-60 seconds.

- Use MapBox for map in flutter app and mapbox apis in backend for creation route and more.

- User can create route, and when its clicked backend creates route using mapbox APIs

- Backend saves run/walk history in database with locations, so user can see path history later in analytics.

#### Fitness

- In backend we have library of workouts with these data:
  {
  "name": "Ягодичный мост со штангой",
  "name_en": "barbell glute bridge",
  "category": "Силовые",
  "muscles": [
  { "name": "Ягодичные", "percentage": 60 },
  { "name": "Бицепс бедра", "percentage": 25 },
  { "name": "Разгибатели спины", "percentage": 15 }
  ],
  "approx_duration": 15,
  "rec_reps": "10-15",
  "rec_sets": 3,
  "tutorial_link": "https://youtu.be/EvoVfOCDzgU?si=SfaFgJsavXbuGXwH",
  "thumbnail_link": "some_link",
  "rest_time": 60
  }
  - and it can be updated manually (its updated rarely so its good to be cached in mobile)

- In mobile (flutter app) User can access to these library and add them into their Programms.

- There is also Programs - list of workouts created by User as routine.
  - There is also premade programs so user can add them into their routine.
  - Routine is programms or workouts that can be repeated periodically.

- mobile ui:
  - User can see each workout card to see information about it: like recommended sets/reps, youtube player for tutorial and more.

  - In flutter app user can choose calendar day to see programs and workouts assigned to that day

  - We have create routine button

#### Groups

We have features like: clubs, friends and posts

- Friends
  - Search for friends and request for friendships
  - User can see friends activity analysis if permission is given
  - User can see friends posts if its public

- Clubs
  - Channels with posts for organizations
  - Users can join them and see its members
  - clubs can have challenges to their members
    - challenges have patterns to check them automatically like:
      - do n amount of steps or mileage in given period and more
    - users can subscribe for challenges, so app could check progress automaitcally. And Club members can see subscribers of club challenges.
  - Clubs can anons its events as posts and more

- Posts
  - Users and Clubs can create posts for everything
  - Posts have Comments and likes/dislikes.
  - Posts includes images and discriptions.

## General Tips

- Google Oauth flow starts in mobile app and authorization code sends to backend, so backend can exchange it to token and Backend creates internal token (JWT) for mobile app that linked to google token in database. For internal token User id is used as sub.

## Backend Tips

- Images and files should be saved in S3 storage

- Save users permanent settings (like localizations, app theme, and more) in google drive for apps

- Backend verifies user from internal token came in authroization header.

- In backend we have notification service that stores user notifications in database: (title, description, markedAsRead, timestamp and more)

## Mobile Tips

- Mobile sends internal token in authorization header for authorized endpoints
- checks for available notifications periodically

- UI
  - homepage
    - shows minimal user activity analytics (steps, mileage, activity time)
    - plan for today: Programms or list of workouts for today
  - run page
    - mapbox sdk map, start run button (floating button), history button, find current location button
    - before start in bar we have create route and after start there should be shown run info (record, time, distance and more)
    - after start in map should be painted users path
  - Fitness page
    - We have three tabs:
      - My day
        - Expandable calendar (by default 1 week and chosen today) where user can choose day and see programs and nested workouts assigned to that day
        - If chosen today there is start training button (starts program not workout) that opens new navigation page
          - User sees list of workouts have to be done and can change order of workouts by dragging them
          - User can delete/skip workouts for today if wants
          - in bottom have start workouts button
            - when started shows up first workout in order with additional info (reps, sets and more)
            - in bottom bar we have start button, next/previous workout button and skip for today button
              - when started it shows video of the workout in repeat as background
              - shows info about current set (number of set)
              - two floating buttons if its not last set(finish set, finish workout), if its last set (finish workout, extra set)
                - when finish set button clicked shows timer for rest if its not the last set and when timer ended alerts user to continue workout
                - when finish workout clicked opens up next workout in order with same logic as previous
      - My Programms
        - List of Programms, when clicked opens up new navigation page with programm info (list of workouts and more)
      - Library
        - List of Predefined workouts that can be added to user programms
        - Each workout is clickable, and when clicked opens up new navigation page with workout info
        - This tab has filters and search for workouts
  - groups page
    - We have three tabs (by defaulst opens feed tab)
      - Feed
        - Shows posts of clubs that user follows and posts of friends ordered by latest
      - Clubs
        - In above we have search bar that allows user to search for clubs and follow them
        - when club clicked opens up profile page for club and shows posts and active challenges if user followed already
      - Friends
        - same as clubs
        - User can see friends analytics (if friend gave visibility permission)
