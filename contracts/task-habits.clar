;; Task Habit Tracking System
;; Links tasks to habits for consistency building and automatic habit reinforcement

;; Error constants
(define-constant ERR-HABIT-NOT-FOUND (err u600))
(define-constant ERR-INVALID-FREQUENCY (err u601))
(define-constant ERR-HABIT-ALREADY-TRACKED (err u602))
(define-constant ERR-NO-HABIT-TODAY (err u603))
(define-constant ERR-ALREADY-COMPLETED-TODAY (err u604))

;; Data variables
(define-data-var habit-counter uint u0)
(define-data-var habit-completion-counter uint u0)

;; Habit definitions
(define-map user-habits
  { user: principal, habit-id: uint }
  {
    name: (string-utf8 100),
    description: (string-utf8 300),
    frequency: (string-utf8 20), ;; "daily", "weekly", "monthly"
    target-count: uint, ;; completions per frequency period
    difficulty-level: uint, ;; 1=easy, 2=medium, 3=hard
    category: (string-utf8 50),
    created-at: uint,
    is-active: bool,
    auto-generate-tasks: bool
  }
)

;; Daily habit tracking
(define-map daily-habit-tracking
  { user: principal, habit-id: uint, date: uint }
  {
    completions-today: uint,
    target-met: bool,
    completion-times: (list 10 uint),
    quality-rating: uint, ;; 1-5 self-rating
    notes: (string-utf8 200)
  }
)

;; Habit streak tracking
(define-map habit-streaks
  { user: principal, habit-id: uint }
  {
    current-streak: uint,
    longest-streak: uint,
    last-completion-date: uint,
    total-completions: uint,
    streak-level: uint, ;; 1=beginner, 2=developing, 3=strong, 4=master
    consistency-score: uint ;; percentage of target days met
  }
)

;; Generated habit tasks
(define-map habit-generated-tasks
  { user: principal, habit-id: uint, task-date: uint }
  {
    task-description: (string-utf8 300),
    is-completed: bool,
    completion-time: uint,
    linked-main-task-id: (optional uint)
  }
)

;; Habit analytics
(define-map habit-analytics
  { user: principal, habit-id: uint, week: uint }
  {
    completion-rate: uint, ;; percentage
    average-quality: uint,
    best-day: (string-utf8 10),
    improvement-trend: (string-utf8 10), ;; "up", "down", "stable"
    total-sessions: uint
  }
)

;; Habit milestone rewards
(define-map habit-milestones
  { user: principal, habit-id: uint, milestone-type: (string-utf8 20) }
  {
    threshold: uint,
    reward-points: uint,
    achieved: bool,
    achieved-at: uint
  }
)

;; Create a new habit
(define-public (create-habit 
  (name (string-utf8 100))
  (description (string-utf8 300))
  (frequency (string-utf8 20))
  (target-count uint)
  (difficulty-level uint)
  (category (string-utf8 50))
  (auto-generate-tasks bool))
  (let
    (
      (habit-id (var-get habit-counter))
    )
    
    ;; Validate inputs
    (asserts! (or (is-eq frequency u"daily") 
                  (or (is-eq frequency u"weekly") (is-eq frequency u"monthly"))) ERR-INVALID-FREQUENCY)
    (asserts! (and (>= difficulty-level u1) (<= difficulty-level u3)) ERR-INVALID-FREQUENCY)
    (asserts! (> target-count u0) ERR-INVALID-FREQUENCY)
    
    ;; Create habit
    (map-set user-habits
      { user: tx-sender, habit-id: habit-id }
      {
        name: name,
        description: description,
        frequency: frequency,
        target-count: target-count,
        difficulty-level: difficulty-level,
        category: category,
        created-at: block-height,
        is-active: true,
        auto-generate-tasks: auto-generate-tasks
      })
    
    ;; Initialize streak tracking
    (map-set habit-streaks
      { user: tx-sender, habit-id: habit-id }
      {
        current-streak: u0,
        longest-streak: u0,
        last-completion-date: u0,
        total-completions: u0,
        streak-level: u1,
        consistency-score: u0
      })
    
    ;; Setup milestones
    (unwrap-panic (setup-habit-milestones habit-id))
    
    (var-set habit-counter (+ habit-id u1))
    (ok habit-id)
  )
)

;; Log habit completion for today
(define-public (complete-habit-today 
  (habit-id uint)
  (quality-rating uint)
  (notes (string-utf8 200)))
  (let
    (
      (today (/ block-height u144)) ;; Approximate daily blocks
      (habit-data (unwrap! (map-get? user-habits { user: tx-sender, habit-id: habit-id }) ERR-HABIT-NOT-FOUND))
      (today-tracking (default-to
        { completions-today: u0, target-met: false, completion-times: (list), 
          quality-rating: u0, notes: u"" }
        (map-get? daily-habit-tracking { user: tx-sender, habit-id: habit-id, date: today })))
      (new-completions (+ (get completions-today today-tracking) u1))
      (target-achieved (>= new-completions (get target-count habit-data)))
    )
    
    ;; Validate habit is active
    (asserts! (get is-active habit-data) ERR-HABIT-NOT-FOUND)
    (asserts! (and (>= quality-rating u1) (<= quality-rating u5)) ERR-INVALID-FREQUENCY)
    
    ;; Update daily tracking
    (map-set daily-habit-tracking
      { user: tx-sender, habit-id: habit-id, date: today }
      {
        completions-today: new-completions,
        target-met: target-achieved,
        completion-times: (unwrap-panic (as-max-len? 
          (append (get completion-times today-tracking) block-height) u10)),
        quality-rating: quality-rating,
        notes: notes
      })
    
    ;; Update streak if target achieved
    (if target-achieved
        (unwrap-panic (update-habit-streak habit-id today))
        true)
    
    ;; Generate next habit task if auto-generation enabled
    (if (get auto-generate-tasks habit-data)
        (unwrap-panic (generate-next-habit-task habit-id))
        true)
    
    (ok target-achieved)
  )
)

;; Update habit streak tracking
(define-private (update-habit-streak (habit-id uint) (completion-date uint))
  (let
    (
      (streak-data (unwrap-panic (map-get? habit-streaks { user: tx-sender, habit-id: habit-id })))
      (is-consecutive (is-eq (+ (get last-completion-date streak-data) u1) completion-date))
      (new-streak (if is-consecutive 
                      (+ (get current-streak streak-data) u1)
                      u1))
      (new-longest (if (> new-streak (get longest-streak streak-data))
                       new-streak
                       (get longest-streak streak-data)))
      (new-total (+ (get total-completions streak-data) u1))
      (new-level (calculate-streak-level new-streak))
      (consistency (calculate-consistency-score habit-id new-total))
    )
    
    ;; Update streak data
    (map-set habit-streaks
      { user: tx-sender, habit-id: habit-id }
      {
        current-streak: new-streak,
        longest-streak: new-longest,
        last-completion-date: completion-date,
        total-completions: new-total,
        streak-level: new-level,
        consistency-score: consistency
      })
    
    ;; Check milestone achievements
    (unwrap-panic (check-habit-milestones habit-id new-streak new-total))
    
    (ok true)
  )
)

;; Generate automatic habit task for tomorrow
(define-private (generate-next-habit-task (habit-id uint))
  (let
    (
      (habit-data (unwrap-panic (map-get? user-habits { user: tx-sender, habit-id: habit-id })))
      (tomorrow (+ (/ block-height u144) u1))
      (task-description (get description habit-data))
    )
    
    ;; Create habit task for tomorrow
    (map-set habit-generated-tasks
      { user: tx-sender, habit-id: habit-id, task-date: tomorrow }
      {
        task-description: task-description,
        is-completed: false,
        completion-time: u0,
        linked-main-task-id: none
      })
    
    (ok true)
  )
)

;; Calculate habit analytics for a week
(define-public (calculate-weekly-analytics (habit-id uint) (week uint))
  (let
    (
      (habit-data (unwrap! (map-get? user-habits { user: tx-sender, habit-id: habit-id }) ERR-HABIT-NOT-FOUND))
      ;; Mock analytics calculation for simplicity
      (completion-rate u75)
      (average-quality u4)
      (best-day u"monday")
      (trend u"up")
      (sessions u5)
    )
    
    ;; Store analytics
    (map-set habit-analytics
      { user: tx-sender, habit-id: habit-id, week: week }
      {
        completion-rate: completion-rate,
        average-quality: average-quality,
        best-day: best-day,
        improvement-trend: trend,
        total-sessions: sessions
      })
    
    (ok true)
  )
)

;; Helper functions
(define-private (calculate-streak-level (streak uint))
  (if (>= streak u30) u4      ;; Master (30+ days)
    (if (>= streak u14) u3    ;; Strong (14-29 days)  
      (if (>= streak u7) u2   ;; Developing (7-13 days)
        u1)))               ;; Beginner (1-6 days)
)

(define-private (calculate-consistency-score (habit-id uint) (total-completions uint))
  ;; Simplified calculation - in reality would analyze completion patterns
  (let ((days-since-creation (- (/ block-height u144) 
                                (/ (get created-at (unwrap-panic 
                                  (map-get? user-habits { user: tx-sender, habit-id: habit-id }))) u144))))
    (if (> days-since-creation u0)
        (/ (* total-completions u100) days-since-creation)
        u0))
)

(define-private (setup-habit-milestones (habit-id uint))
  (begin
    ;; Setup streak milestones
    (map-set habit-milestones
      { user: tx-sender, habit-id: habit-id, milestone-type: u"streak-7" }
      { threshold: u7, reward-points: u50, achieved: false, achieved-at: u0 })
    
    (map-set habit-milestones
      { user: tx-sender, habit-id: habit-id, milestone-type: u"streak-30" }
      { threshold: u30, reward-points: u200, achieved: false, achieved-at: u0 })
    
    (map-set habit-milestones
      { user: tx-sender, habit-id: habit-id, milestone-type: u"total-100" }
      { threshold: u100, reward-points: u300, achieved: false, achieved-at: u0 })
    
    (ok true)
  )
)

(define-private (check-habit-milestones (habit-id uint) (current-streak uint) (total-completions uint))
  (begin
    ;; Check 7-day streak milestone
    (if (and (>= current-streak u7) 
             (not (get achieved (unwrap-panic (map-get? habit-milestones 
               { user: tx-sender, habit-id: habit-id, milestone-type: u"streak-7" })))))
        (map-set habit-milestones
          { user: tx-sender, habit-id: habit-id, milestone-type: u"streak-7" }
          { threshold: u7, reward-points: u50, achieved: true, achieved-at: block-height })
        true)
    
    ;; Check 30-day streak milestone  
    (if (and (>= current-streak u30)
             (not (get achieved (unwrap-panic (map-get? habit-milestones 
               { user: tx-sender, habit-id: habit-id, milestone-type: u"streak-30" })))))
        (map-set habit-milestones
          { user: tx-sender, habit-id: habit-id, milestone-type: u"streak-30" }
          { threshold: u30, reward-points: u200, achieved: true, achieved-at: block-height })
        true)
    
    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-user-habit (habit-id uint))
  (map-get? user-habits { user: tx-sender, habit-id: habit-id })
)

(define-read-only (get-habit-streak (habit-id uint))
  (map-get? habit-streaks { user: tx-sender, habit-id: habit-id })
)

(define-read-only (get-daily-tracking (habit-id uint) (date uint))
  (map-get? daily-habit-tracking { user: tx-sender, habit-id: habit-id, date: date })
)

(define-read-only (get-habit-analytics (habit-id uint) (week uint))
  (map-get? habit-analytics { user: tx-sender, habit-id: habit-id, week: week })
)

(define-read-only (get-habit-milestones (habit-id uint) (milestone-type (string-utf8 20)))
  (map-get? habit-milestones { user: tx-sender, habit-id: habit-id, milestone-type: milestone-type })
)

(define-read-only (get-generated-task (habit-id uint) (task-date uint))
  (map-get? habit-generated-tasks { user: tx-sender, habit-id: habit-id, task-date: task-date })
)

;; Get user habit summary
(define-read-only (get-user-habit-summary)
  (ok {
    total-habits: (var-get habit-counter),
    total-completions: (var-get habit-completion-counter)
  })
)
