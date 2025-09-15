;; Task Achievement System - Gamified task completion rewards
;; Provides achievements, badges, and progression metrics for task management

;; User achievement data storage
(define-map user-achievements
  { user: principal }
  {
    total-tasks-completed: uint,
    total-points: uint,
    current-streak: uint,
    longest-streak: uint,
    last-completion-date: uint,
    level: uint,
    badges-earned: uint
  }
)

;; Achievement definitions storage
(define-map achievement-types
  { achievement-id: uint }
  {
    name: (string-utf8 100),
    description: (string-utf8 300),
    category: (string-utf8 50),
    points-required: uint,
    tasks-required: uint,
    streak-required: uint,
    is-repeatable: bool,
    badge-icon: (string-utf8 50)
  }
)

;; User-specific achievement progress tracking
(define-map user-achievement-progress
  { user: principal, achievement-id: uint }
  {
    current-progress: uint,
    times-earned: uint,
    first-earned-at: uint,
    last-earned-at: uint,
    is-completed: bool
  }
)

;; Achievement unlock history
(define-map achievement-unlocks
  { user: principal, achievement-id: uint, unlock-id: uint }
  {
    unlocked-at: uint,
    trigger-task-id: uint,
    bonus-points: uint
  }
)

;; Daily challenge system
(define-map daily-challenges
  { date: uint }
  {
    challenge-type: (string-utf8 50),
    target-count: uint,
    bonus-points: uint,
    description: (string-utf8 200)
  }
)

;; User daily challenge progress
(define-map user-daily-progress
  { user: principal, date: uint }
  {
    tasks-completed: uint,
    challenge-completed: bool,
    points-earned: uint
  }
)

;; Leaderboard data
(define-map weekly-leaderboard
  { week: uint, rank: uint }
  {
    user: principal,
    points: uint,
    tasks-completed: uint
  }
)

;; Achievement counter for IDs
(define-map achievement-counter
  { counter: uint }
  { next-id: uint }
)

;; User unlock counters
(define-map user-unlock-counters
  { user: principal, achievement-id: uint }
  { next-unlock-id: uint }
)

;; Error constants
(define-constant ERR-ACHIEVEMENT-NOT-FOUND (err u500))
(define-constant ERR-ALREADY-COMPLETED (err u501))
(define-constant ERR-INSUFFICIENT-PROGRESS (err u502))
(define-constant ERR-INVALID-PARAMETERS (err u503))

;; Initialize user achievement data
(define-public (initialize-user-achievements)
  (let
    ((existing-data (map-get? user-achievements { user: tx-sender })))
    (if (is-none existing-data)
      (begin
        (map-set user-achievements
          { user: tx-sender }
          {
            total-tasks-completed: u0,
            total-points: u0,
            current-streak: u0,
            longest-streak: u0,
            last-completion-date: u0,
            level: u1,
            badges-earned: u0
          }
        )
        (ok true)
      )
      (ok false)
    )
  )
)

;; Record task completion for achievement tracking
(define-public (record-task-completion (task-id uint) (category (string-utf8 50)) (priority uint))
  (let
    (
      (user-data (default-to
        {
          total-tasks-completed: u0,
          total-points: u0,
          current-streak: u0,
          longest-streak: u0,
          last-completion-date: u0,
          level: u1,
          badges-earned: u0
        }
        (map-get? user-achievements { user: tx-sender })
      ))
      (current-date (/ block-height u144)) ;; Approximate daily blocks
      (points-earned (+ u10 (* priority u5))) ;; Base 10 + priority bonus
      (is-consecutive (is-eq (+ (get last-completion-date user-data) u1) current-date))
      (new-streak (if is-consecutive (+ (get current-streak user-data) u1) u1))
      (new-total-tasks (+ (get total-tasks-completed user-data) u1))
      (new-total-points (+ (get total-points user-data) points-earned))
      (new-level (+ u1 (/ new-total-points u100))) ;; Level up every 100 points
    )
    (begin
      ;; Update user achievement data
      (map-set user-achievements
        { user: tx-sender }
        {
          total-tasks-completed: new-total-tasks,
          total-points: new-total-points,
          current-streak: new-streak,
          longest-streak: (if (> new-streak (get longest-streak user-data)) 
                           new-streak 
                           (get longest-streak user-data)),
          last-completion-date: current-date,
          level: new-level,
          badges-earned: (get badges-earned user-data)
        }
      )
      
      ;; Check and process achievements
      (unwrap-panic (check-completion-achievements new-total-tasks new-streak new-level task-id))
      
      ;; Update daily challenge progress
      (unwrap-panic (update-daily-challenge-progress current-date))
      
      (ok points-earned)
    )
  )
)

;; Check if user qualifies for new achievements
(define-private (check-completion-achievements (total-tasks uint) (current-streak uint) (level uint) (task-id uint))
  (begin
    ;; Check task milestone achievements (10, 25, 50, 100, 250, 500 tasks)
    (if (and (>= total-tasks u10) (not (is-achievement-completed u1)))
      (unwrap-panic (unlock-achievement u1 task-id u20))
      true
    )
    (if (and (>= total-tasks u25) (not (is-achievement-completed u2)))
      (unwrap-panic (unlock-achievement u2 task-id u50))
      true
    )
    (if (and (>= total-tasks u50) (not (is-achievement-completed u3)))
      (unwrap-panic (unlock-achievement u3 task-id u100))
      true
    )
    (if (and (>= total-tasks u100) (not (is-achievement-completed u4)))
      (unwrap-panic (unlock-achievement u4 task-id u200))
      true
    )
    
    ;; Check streak achievements (3, 7, 14, 30 day streaks)
    (if (and (>= current-streak u3) (not (is-achievement-completed u5)))
      (unwrap-panic (unlock-achievement u5 task-id u30))
      true
    )
    (if (and (>= current-streak u7) (not (is-achievement-completed u6)))
      (unwrap-panic (unlock-achievement u6 task-id u70))
      true
    )
    (if (and (>= current-streak u14) (not (is-achievement-completed u7)))
      (unwrap-panic (unlock-achievement u7 task-id u140))
      true
    )
    (if (and (>= current-streak u30) (not (is-achievement-completed u8)))
      (unwrap-panic (unlock-achievement u8 task-id u300))
      true
    )
    
    ;; Check level achievements (5, 10, 20, 50 levels)
    (if (and (>= level u5) (not (is-achievement-completed u9)))
      (unwrap-panic (unlock-achievement u9 task-id u50))
      true
    )
    (if (and (>= level u10) (not (is-achievement-completed u10)))
      (unwrap-panic (unlock-achievement u10 task-id u100))
      true
    )
    
    (ok true)
  )
)

;; Helper function to check if achievement is completed
(define-private (is-achievement-completed (achievement-id uint))
  (match (map-get? user-achievement-progress { user: tx-sender, achievement-id: achievement-id })
    progress (get is-completed progress)
    false
  )
)

;; Unlock a specific achievement for user
(define-private (unlock-achievement (achievement-id uint) (trigger-task-id uint) (bonus-points uint))
  (let
    (
      (counter (default-to { next-unlock-id: u0 } 
        (map-get? user-unlock-counters { user: tx-sender, achievement-id: achievement-id })))
      (next-unlock-id (+ (get next-unlock-id counter) u1))
      (user-data (unwrap-panic (map-get? user-achievements { user: tx-sender })))
    )
    (begin
      ;; Record achievement unlock
      (map-set achievement-unlocks
        { user: tx-sender, achievement-id: achievement-id, unlock-id: next-unlock-id }
        {
          unlocked-at: block-height,
          trigger-task-id: trigger-task-id,
          bonus-points: bonus-points
        }
      )
      
      ;; Update progress tracking
      (map-set user-achievement-progress
        { user: tx-sender, achievement-id: achievement-id }
        {
          current-progress: u100,
          times-earned: next-unlock-id,
          first-earned-at: (match (map-get? user-achievement-progress { user: tx-sender, achievement-id: achievement-id })
                             existing (get first-earned-at existing)
                             block-height),
          last-earned-at: block-height,
          is-completed: true
        }
      )
      
      ;; Update unlock counter
      (map-set user-unlock-counters
        { user: tx-sender, achievement-id: achievement-id }
        { next-unlock-id: next-unlock-id }
      )
      
      ;; Add bonus points and badge count
      (map-set user-achievements
        { user: tx-sender }
        (merge user-data {
          total-points: (+ (get total-points user-data) bonus-points),
          badges-earned: (+ (get badges-earned user-data) u1)
        })
      )
      
      (ok true)
    )
  )
)

;; Update daily challenge progress
(define-private (update-daily-challenge-progress (current-date uint))
  (let
    (
      (daily-progress (default-to
        { tasks-completed: u0, challenge-completed: false, points-earned: u0 }
        (map-get? user-daily-progress { user: tx-sender, date: current-date })
      ))
      (challenge (map-get? daily-challenges { date: current-date }))
      (new-task-count (+ (get tasks-completed daily-progress) u1))
    )
    (match challenge
      challenge-data
        (let ((target-reached (>= new-task-count (get target-count challenge-data))))
          (map-set user-daily-progress
            { user: tx-sender, date: current-date }
            {
              tasks-completed: new-task-count,
              challenge-completed: target-reached,
              points-earned: (if target-reached (get bonus-points challenge-data) u0)
            }
          )
          (ok target-reached)
        )
      (ok false)
    )
  )
)

;; Create predefined achievements
(define-public (setup-default-achievements)
  (begin
    ;; Task completion milestones
    (unwrap-panic (create-achievement u"First Steps" u"Complete your first 10 tasks" u"milestone" u10 u0 u"trophy"))
    (unwrap-panic (create-achievement u"Getting Productive" u"Complete 25 tasks" u"milestone" u25 u0 u"star"))
    (unwrap-panic (create-achievement u"Task Master" u"Complete 50 tasks" u"milestone" u50 u0 u"crown"))
    (unwrap-panic (create-achievement u"Productivity Legend" u"Complete 100 tasks" u"milestone" u100 u0 u"diamond"))
    
    ;; Streak achievements
    (unwrap-panic (create-achievement u"Consistent" u"Maintain a 3-day completion streak" u"streak" u0 u3 u"fire"))
    (unwrap-panic (create-achievement u"Weekly Warrior" u"Maintain a 7-day completion streak" u"streak" u0 u7 u"lightning"))
    (unwrap-panic (create-achievement u"Fortnight Focus" u"Maintain a 14-day completion streak" u"streak" u0 u14 u"target"))
    (unwrap-panic (create-achievement u"Monthly Master" u"Maintain a 30-day completion streak" u"streak" u0 u30 u"medal"))
    
    ;; Level achievements
    (unwrap-panic (create-achievement u"Rising Star" u"Reach level 5" u"level" u0 u0 u"arrow-up"))
    (unwrap-panic (create-achievement u"Expert Level" u"Reach level 10" u"level" u0 u0 u"graduation"))
    
    (ok true)
  )
)

;; Helper function to create achievements
(define-private (create-achievement 
    (name (string-utf8 100)) 
    (description (string-utf8 300)) 
    (category (string-utf8 50)) 
    (tasks-required uint) 
    (streak-required uint) 
    (badge-icon (string-utf8 50))
  )
  (let
    (
      (counter (default-to { next-id: u0 } (map-get? achievement-counter { counter: u0 })))
      (next-id (+ (get next-id counter) u1))
    )
    (begin
      (map-set achievement-types
        { achievement-id: next-id }
        {
          name: name,
          description: description,
          category: category,
          points-required: u0,
          tasks-required: tasks-required,
          streak-required: streak-required,
          is-repeatable: false,
          badge-icon: badge-icon
        }
      )
      (map-set achievement-counter
        { counter: u0 }
        { next-id: next-id }
      )
      (ok next-id)
    )
  )
)

;; Set daily challenge
(define-public (set-daily-challenge 
    (date uint) 
    (challenge-type (string-utf8 50)) 
    (target-count uint) 
    (bonus-points uint) 
    (description (string-utf8 200))
  )
  (begin
    (map-set daily-challenges
      { date: date }
      {
        challenge-type: challenge-type,
        target-count: target-count,
        bonus-points: bonus-points,
        description: description
      }
    )
    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-user-achievements (user principal))
  (map-get? user-achievements { user: user })
)

(define-read-only (get-achievement-progress (user principal) (achievement-id uint))
  (map-get? user-achievement-progress { user: user, achievement-id: achievement-id })
)

(define-read-only (get-achievement-details (achievement-id uint))
  (map-get? achievement-types { achievement-id: achievement-id })
)

(define-read-only (get-daily-challenge (date uint))
  (map-get? daily-challenges { date: date })
)

(define-read-only (get-user-daily-progress (user principal) (date uint))
  (map-get? user-daily-progress { user: user, date: date })
)

(define-read-only (get-user-level (user principal))
  (match (map-get? user-achievements { user: user })
    user-data (get level user-data)
    u1
  )
)

(define-read-only (get-user-total-points (user principal))
  (match (map-get? user-achievements { user: user })
    user-data (get total-points user-data)
    u0
  )
)

(define-read-only (get-user-current-streak (user principal))
  (match (map-get? user-achievements { user: user })
    user-data (get current-streak user-data)
    u0
  )
)


