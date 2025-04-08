(define-map tasks 
  {
    owner: principal,
    task-id: uint
  }
  {
    description: (string-utf8 500),
    is-completed: bool,
    created-at: uint,
    priority: uint,  ;; 1=Low, 2=Medium, 3=High
    due-date: uint,  ;; Block height for due date
    category: (string-utf8 50)

  }
)

;; Store the next task ID for each user
(define-map task-counters
  { owner: principal }
  { next-id: uint }
)

;; Error constants
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-TASK-NOT-FOUND (err u101))

;; Add a new task
(define-public (add-task (description (string-utf8 500)) (category (string-utf8 50)) (priority uint) (due-date uint)) 
  (let 
    (
      ;; Get or initialize the task counter for the caller
      (task-counter 
        (default-to 
          { next-id: u0 } 
          (map-get? task-counters { owner: tx-sender })
        )
      )
      
      ;; Increment the task ID
      (next-task-id (+ (get next-id task-counter) u1))
    )
    (begin
      ;; Store the new task
      (map-set tasks 
        {
          owner: tx-sender,
          task-id: next-task-id
        }
        {
          description: description,
          is-completed: false,
          created-at: block-height,
          priority: priority,
          due-date: due-date,
          category: category
        }
      )
      
      ;; Update the task counter
      (map-set task-counters 
        { owner: tx-sender }
        { next-id: next-task-id }
      )
      
      ;; Return success with the new task ID
      (ok next-task-id)
    )
  )
)

;; Mark a task as completed
(define-public (complete-task (task-id uint))
  (let 
    (
      (task 
        (map-get? tasks 
          {
            owner: tx-sender,
            task-id: task-id
          }
        )
      )
    )
    (match task
      task-details
        (begin
          ;; Task already exists, so we know it belongs to the sender
          (map-set tasks 
            {
              owner: tx-sender,
              task-id: task-id
            }
            (merge task-details { is-completed: true })
          )
          
          (ok true)
        )
      (err ERR-TASK-NOT-FOUND)
    )
  )
)
;; Delete a task
(define-public (delete-task (task-id uint))
  (let 
    (
      (task 
        (map-get? tasks 
          {
            owner: tx-sender,
            task-id: task-id
          }
        )
      )
    )
    (match task
      task-details
        (begin
          ;; Remove the task
          (map-delete tasks 
            {
              owner: tx-sender,
              task-id: task-id
            }
          )
          
          (ok true)
        )
      (err ERR-TASK-NOT-FOUND)
    )
  )
)

;; Read-only function to get a task
(define-read-only (get-task (owner principal) (task-id uint))
  (map-get? tasks 
    {
      owner: owner,
      task-id: task-id
    }
  )
)


;; Add priority field to tasks map


(define-public (set-task-priority (task-id uint) (priority uint))
  (let ((task (map-get? tasks {owner: tx-sender, task-id: task-id})))
    (match task
      task-details
        (begin
          (map-set tasks 
            {owner: tx-sender, task-id: task-id}
            (merge task-details {priority: priority})
          )
          (ok true)
        )
      (err ERR-TASK-NOT-FOUND)
    )
  )
)


(define-public (set-due-date (task-id uint) (due-date uint))
  (let ((task (map-get? tasks {owner: tx-sender, task-id: task-id})))
    (match task
      task-details
        (begin
          (map-set tasks 
            {owner: tx-sender, task-id: task-id}
            (merge task-details {due-date: due-date})
          )
          (ok true)
        )
      (err ERR-TASK-NOT-FOUND)
    )
  )
)



(define-public (set-task-category (task-id uint) (category (string-utf8 50)))
  (let ((task (map-get? tasks {owner: tx-sender, task-id: task-id})))
    (match task
      task-details
        (begin
          (map-set tasks 
            {owner: tx-sender, task-id: task-id}
            (merge task-details {category: category})
          )
          (ok true)
        )
      (err ERR-TASK-NOT-FOUND)
    )
  )
)



(define-map task-notes
  { owner: principal, task-id: uint, note-id: uint }
  { 
    content: (string-utf8 500),
    created-at: uint
  }
)

(define-map note-counters
  { owner: principal, task-id: uint }
  { next-note-id: uint }
)

(define-public (add-task-note (task-id uint) (content (string-utf8 500)))
  (let 
    (
      (note-counter (default-to { next-note-id: u0 } 
        (map-get? note-counters { owner: tx-sender, task-id: task-id })))
      (next-note-id (+ (get next-note-id note-counter) u1))
    )
    (begin
      (map-set task-notes
        { owner: tx-sender, task-id: task-id, note-id: next-note-id }
        { content: content, created-at: block-height }
      )
      (map-set note-counters
        { owner: tx-sender, task-id: task-id }
        { next-note-id: next-note-id }
      )
      (ok next-note-id)
    )
  )
)


(define-map shared-tasks
  { owner: principal, shared-with: principal, task-id: uint }
  { can-edit: bool }
)

(define-public (share-task (task-id uint) (share-with principal) (can-edit bool))
  (let ((task (map-get? tasks {owner: tx-sender, task-id: task-id})))
    (match task
      task-details
        (begin
          (map-set shared-tasks
            { owner: tx-sender, shared-with: share-with, task-id: task-id }
            { can-edit: can-edit }
          )
          (ok true)
        )
      (err ERR-TASK-NOT-FOUND)
    )
  )
)



(define-map task-reminders
  { owner: principal, task-id: uint }
  { reminder-height: uint }
)

(define-public (set-reminder (task-id uint) (blocks-from-now uint))
  (let 
    ((reminder-height (+ block-height blocks-from-now)))
    (map-set task-reminders
      { owner: tx-sender, task-id: task-id }
      { reminder-height: reminder-height }
    )
    (ok true)
  )
)



;; Define map for task tags
(define-map task-tags
  { owner: principal, task-id: uint, tag: (string-utf8 20) }
  { created-at: uint }
)

(define-public (add-task-tag (task-id uint) (tag (string-utf8 20)))
  (let ((task (map-get? tasks {owner: tx-sender, task-id: task-id})))
    (match task
      task-details
        (begin
          (map-set task-tags
            { owner: tx-sender, task-id: task-id, tag: tag }
            { created-at: block-height }
          )
          (ok true)
        )
      (err ERR-TASK-NOT-FOUND)
    )
  )
)



(define-map task-comments
  { owner: principal, task-id: uint, comment-id: uint }
  { 
    content: (string-utf8 500),
    created-at: uint,
    author: principal
  }
)

(define-map comment-counters
  { task-id: uint }
  { next-comment-id: uint }
)

(define-public (add-comment (task-id uint) (content (string-utf8 500)))
  (let 
    ((counter (default-to { next-comment-id: u0 } 
      (map-get? comment-counters { task-id: task-id })))
     (next-id (+ (get next-comment-id counter) u1)))
    (begin
      (map-set task-comments
        { owner: tx-sender, task-id: task-id, comment-id: next-id }
        { content: content, created-at: block-height, author: tx-sender }
      )
      (map-set comment-counters
        { task-id: task-id }
        { next-comment-id: next-id }
      )
      (ok next-id)
    )
  )
)



(define-map recurring-tasks
  { owner: principal, task-id: uint }
  { 
    interval: uint,  ;; blocks between recurrence
    last-created: uint
  }
)

(define-public (set-recurring (task-id uint) (interval uint))
  (let ((task (map-get? tasks {owner: tx-sender, task-id: task-id})))
    (match task
      task-details
        (begin
          (map-set recurring-tasks
            { owner: tx-sender, task-id: task-id }
            { interval: interval, last-created: block-height }
          )
          (ok true)
        )
      (err ERR-TASK-NOT-FOUND)
    )
  )
)




(define-map task-dependencies
  { owner: principal, task-id: uint, depends-on: uint }
  { created-at: uint }
)

(define-public (add-dependency (task-id uint) (depends-on uint))
  (let ((task (map-get? tasks {owner: tx-sender, task-id: task-id})))
    (match task
      task-details
        (begin
          (map-set task-dependencies
            { owner: tx-sender, task-id: task-id, depends-on: depends-on }
            { created-at: block-height }
          )
          (ok true)
        )
      (err ERR-TASK-NOT-FOUND)
    )
  )
)



(define-map task-progress
  { owner: principal, task-id: uint }
  { 
    percentage: uint,  ;; 0-100
    last-updated: uint
  }
)

(define-public (update-progress (task-id uint) (percentage uint))
  (let ((task (map-get? tasks {owner: tx-sender, task-id: task-id})))
    (match task
      task-details
        (begin
          (map-set task-progress
            { owner: tx-sender, task-id: task-id }
            { percentage: percentage, last-updated: block-height }
          )
          (ok true)
        )
      (err ERR-TASK-NOT-FOUND)
    )
  )
)


(define-map task-time-tracking
  { owner: principal, task-id: uint }
  { 
    start-time: uint,
    total-time: uint,
    is-running: bool
  }
)

(define-public (start-time-tracking (task-id uint))
  (let ((task (map-get? tasks {owner: tx-sender, task-id: task-id})))
    (match task
      task-details
        (begin
          (map-set task-time-tracking
            { owner: tx-sender, task-id: task-id }
            { start-time: block-height, total-time: u0, is-running: true }
          )
          (ok true)
        )
      (err ERR-TASK-NOT-FOUND)
    )
  )
)



(define-map task-attachments
  { owner: principal, task-id: uint, attachment-id: uint }
  { 
    url: (string-utf8 500),
    description: (string-utf8 100),
    added-at: uint
  }
)

(define-map attachment-counters
  { task-id: uint }
  { next-attachment-id: uint }
)

(define-public (add-attachment (task-id uint) (url (string-utf8 500)) (description (string-utf8 100)))
  (let 
    ((counter (default-to { next-attachment-id: u0 } 
      (map-get? attachment-counters { task-id: task-id })))
     (next-id (+ (get next-attachment-id counter) u1)))
    (begin
      (map-set task-attachments
        { owner: tx-sender, task-id: task-id, attachment-id: next-id }
        { url: url, description: description, added-at: block-height }
      )
      (map-set attachment-counters
        { task-id: task-id }
        { next-attachment-id: next-id }
      )
      (ok next-id)
    )
  )
)



;; Template storage
(define-map task-templates
  { owner: principal, template-id: uint }
  {
    name: (string-utf8 100),
    description: (string-utf8 500),
    category: (string-utf8 50),
    priority: uint
  }
)

(define-map template-counters
  { owner: principal }
  { next-template-id: uint }
)

(define-public (create-template 
    (name (string-utf8 100))
    (description (string-utf8 500))
    (category (string-utf8 50))
    (priority uint)
  )
  (let
    (
      (counter (default-to { next-template-id: u0 } 
        (map-get? template-counters { owner: tx-sender })))
      (next-id (+ (get next-template-id counter) u1))
    )
    (begin
      (map-set task-templates
        { owner: tx-sender, template-id: next-id }
        { name: name, description: description, category: category, priority: priority }
      )
      (map-set template-counters
        { owner: tx-sender }
        { next-template-id: next-id }
      )
      (ok next-id)
    )
  )
)



(define-map task-labels
  { owner: principal, task-id: uint }
  {
    color: (string-utf8 7), ;; Hex color code
    label-text: (string-utf8 20)
  }
)

(define-public (add-label (task-id uint) (color (string-utf8 7)) (label-text (string-utf8 20)))
  (let ((task (map-get? tasks {owner: tx-sender, task-id: task-id})))
    (match task
      task-details
        (begin
          (map-set task-labels
            { owner: tx-sender, task-id: task-id }
            { color: color, label-text: label-text }
          )
          (ok true)
        )
      (err ERR-TASK-NOT-FOUND)
    )
  )
)


(define-map task-checklist
  { owner: principal, task-id: uint, item-id: uint }
  {
    description: (string-utf8 200),
    is-completed: bool
  }
)

(define-map checklist-counters
  { task-id: uint }
  { next-item-id: uint }
)

(define-public (add-checklist-item (task-id uint) (description (string-utf8 200)))
  (let
    (
      (counter (default-to { next-item-id: u0 }
        (map-get? checklist-counters { task-id: task-id })))
      (next-id (+ (get next-item-id counter) u1))
    )
    (begin
      (map-set task-checklist
        { owner: tx-sender, task-id: task-id, item-id: next-id }
        { description: description, is-completed: false }
      )
      (map-set checklist-counters
        { task-id: task-id }
        { next-item-id: next-id }
      )
      (ok next-id)
    )
  )
)


(define-map archived-tasks
  { owner: principal, task-id: uint }
  {
    task-data: (optional {
      description: (string-utf8 500),
      category: (string-utf8 50),
      completed-at: uint
    })
  }
)

(define-public (archive-task (task-id uint))
  (let ((task (map-get? tasks {owner: tx-sender, task-id: task-id})))
    (match task
      task-details
        (begin
          (map-set archived-tasks
            { owner: tx-sender, task-id: task-id }
            {
              task-data: (some {
                description: (get description task-details),
                category: (get category task-details),
                completed-at: block-height
              })
            }
          )
          (map-delete tasks {owner: tx-sender, task-id: task-id})
          (ok true)
        )
      (err ERR-TASK-NOT-FOUND)
    )
  )
)



(define-map important-tasks
  { owner: principal, task-id: uint }
  { is-important: bool }
)

(define-public (toggle-importance (task-id uint))
  (let 
    (
      (current-status (default-to { is-important: false }
        (map-get? important-tasks { owner: tx-sender, task-id: task-id })))
    )
    (begin
      (map-set important-tasks
        { owner: tx-sender, task-id: task-id }
        { is-important: (not (get is-important current-status)) }
      )
      (ok true)
    )
  )
)



(define-map task-groups
  { owner: principal, group-id: uint }
  {
    name: (string-utf8 100),
    description: (string-utf8 500)
  }
)

(define-map group-tasks
  { owner: principal, group-id: uint, task-id: uint }
  { added-at: uint }
)

(define-map group-counters
  { owner: principal }
  { next-group-id: uint }
)

(define-public (create-group (name (string-utf8 100)) (description (string-utf8 500)))
  (let
    (
      (counter (default-to { next-group-id: u0 }
        (map-get? group-counters { owner: tx-sender })))
      (next-id (+ (get next-group-id counter) u1))
    )
    (begin
      (map-set task-groups
        { owner: tx-sender, group-id: next-id }
        { name: name, description: description }
      )
      (map-set group-counters
        { owner: tx-sender }
        { next-group-id: next-id }
      )
      (ok next-id)
    )
  )
)


(define-map task-estimates
  { owner: principal, task-id: uint }
  {
    estimated-minutes: uint,
    actual-minutes: uint
  }
)

(define-public (set-estimate (task-id uint) (minutes uint))
  (let ((task (map-get? tasks {owner: tx-sender, task-id: task-id})))
    (match task
      task-details
        (begin
          (map-set task-estimates
            { owner: tx-sender, task-id: task-id }
            { estimated-minutes: minutes, actual-minutes: u0 }
          )
          (ok true)
        )
      (err ERR-TASK-NOT-FOUND)
    )
  )
)



(define-map task-energy
  { owner: principal, task-id: uint }
  {
    energy-level: uint,  ;; 1=Low, 2=Medium, 3=High
    best-time: (string-utf8 20)  ;; e.g. "morning", "afternoon", "evening"
  }
)

(define-public (set-energy-level 
    (task-id uint) 
    (energy-level uint)
    (best-time (string-utf8 20))
  )
  (let ((task (map-get? tasks {owner: tx-sender, task-id: task-id})))
    (match task
      task-details
        (begin
          (map-set task-energy
            { owner: tx-sender, task-id: task-id }
            { energy-level: energy-level, best-time: best-time }
          )
          (ok true)
        )
      (err ERR-TASK-NOT-FOUND)
    )
  )
)


(define-map search-index
  { owner: principal, keyword: (string-utf8 50) }
  { task-ids: (list 100 uint) }
)



(define-read-only (search-tasks (keyword (string-utf8 50)))
  (default-to (list) (get task-ids (map-get? search-index { owner: tx-sender, keyword: keyword })))
)


(define-map task-votes
  { task-id: uint, voter: principal }
  { vote-type: (string-utf8 20), timestamp: uint }
)

(define-map task-vote-counts
  { task-id: uint, vote-type: (string-utf8 20) }
  { count: uint }
)

(define-public (vote-on-task (task-id uint) (owner principal) (vote-type (string-utf8 20)))
  (let
    (
      (task (map-get? tasks {owner: owner, task-id: task-id}))
      (current-count (default-to { count: u0 } (map-get? task-vote-counts { task-id: task-id, vote-type: vote-type })))
    )
    (match task
      task-details
        (begin
          (map-set task-votes
            { task-id: task-id, voter: tx-sender }
            { vote-type: vote-type, timestamp: block-height }
          )
          (map-set task-vote-counts
            { task-id: task-id, vote-type: vote-type }
            { count: (+ (get count current-count) u1) }
          )
          (ok true)
        )
      (err ERR-TASK-NOT-FOUND)
    )
  )
)

(define-read-only (get-vote-count (task-id uint) (vote-type (string-utf8 20)))
  (default-to u0 (get count (map-get? task-vote-counts { task-id: task-id, vote-type: vote-type })))
)




(define-map task-streaks
  { owner: principal, task-id: uint }
  { 
    current-streak: uint,
    longest-streak: uint,
    last-completed: uint
  }
)

(define-public (update-streak (task-id uint))
  (let
    (
      (task (map-get? tasks {owner: tx-sender, task-id: task-id}))
      (current-streak-data (default-to 
        { current-streak: u0, longest-streak: u0, last-completed: u0 } 
        (map-get? task-streaks { owner: tx-sender, task-id: task-id })))
      (new-streak (+ (get current-streak current-streak-data) u1))
      (new-longest (if (> new-streak (get longest-streak current-streak-data))
                      new-streak
                      (get longest-streak current-streak-data)))
    )
    (match task
      task-details
        (begin
          (map-set task-streaks
            { owner: tx-sender, task-id: task-id }
            { 
              current-streak: new-streak,
              longest-streak: new-longest,
              last-completed: block-height
            }
          )
          (ok true)
        )
      (err ERR-TASK-NOT-FOUND)
    )
  )
)

(define-read-only (get-streak-info (task-id uint))
  (map-get? task-streaks { owner: tx-sender, task-id: task-id })
)


(define-map user-points
  { owner: principal }
  { points: uint }
)

(define-map task-rewards
  { owner: principal, task-id: uint }
  { points-value: uint }
)

(define-public (set-task-reward (task-id uint) (points uint))
  (let ((task (map-get? tasks {owner: tx-sender, task-id: task-id})))
    (match task
      task-details
        (begin
          (map-set task-rewards
            { owner: tx-sender, task-id: task-id }
            { points-value: points }
          )
          (ok true)
        )
      (err ERR-TASK-NOT-FOUND)
    )
  )
)

(define-public (claim-task-reward (task-id uint))
  (let
    (
      (task (map-get? tasks {owner: tx-sender, task-id: task-id}))
      (reward (default-to { points-value: u0 } (map-get? task-rewards { owner: tx-sender, task-id: task-id })))
      (current-points (default-to { points: u0 } (map-get? user-points { owner: tx-sender })))
    )
    (match task
      task-details
        (if (get is-completed task-details)
          (begin
            (map-set user-points
              { owner: tx-sender }
              { points: (+ (get points current-points) (get points-value reward)) }
            )
            (ok true)
          )
          (err u102) ;; Task not completed
        )
      ERR-TASK-NOT-FOUND
    )
  )
)

(define-read-only (get-user-points)
  (default-to u0 (get points (map-get? user-points { owner: tx-sender })))
)



(define-map user-statistics
  { owner: principal }
  { 
    tasks-created: uint,
    tasks-completed: uint,
    total-time-spent: uint,
    last-updated: uint
  }
)

(define-public (update-statistics (time-spent uint) (is-completion bool))
  (let
    (
      (current-stats (default-to 
        { tasks-created: u0, tasks-completed: u0, total-time-spent: u0, last-updated: u0 } 
        (map-get? user-statistics { owner: tx-sender })))
      (new-completed (if is-completion
                        (+ (get tasks-completed current-stats) u1)
                        (get tasks-completed current-stats)))
    )
    (begin
      (map-set user-statistics
        { owner: tx-sender }
        { 
          tasks-created: (+ (get tasks-created current-stats) u1),
          tasks-completed: new-completed,
          total-time-spent: (+ (get total-time-spent current-stats) time-spent),
          last-updated: block-height
        }
      )
      (ok true)
    )
  )
)

(define-read-only (get-user-statistics)
  (map-get? user-statistics { owner: tx-sender })
)



(define-map subtasks
  { owner: principal, parent-task-id: uint, subtask-id: uint }
  {
    description: (string-utf8 500),
    is-completed: bool,
    created-at: uint
  }
)

(define-map subtask-counters
  { owner: principal, parent-task-id: uint }
  { next-id: uint }
)

(define-public (add-subtask (parent-task-id uint) (description (string-utf8 500)))
  (let
    (
      (parent-task (map-get? tasks {owner: tx-sender, task-id: parent-task-id}))
      (counter (default-to { next-id: u0 } (map-get? subtask-counters { owner: tx-sender, parent-task-id: parent-task-id })))
      (next-id (+ (get next-id counter) u1))
    )
    (match parent-task
      parent-task-details
        (begin
          (map-set subtasks
            { owner: tx-sender, parent-task-id: parent-task-id, subtask-id: next-id }
            { 
              description: description,
              is-completed: false,
              created-at: block-height
            }
          )
          (map-set subtask-counters
            { owner: tx-sender, parent-task-id: parent-task-id }
            { next-id: next-id }
          )
          (ok next-id)
        )
      (err ERR-TASK-NOT-FOUND)
    )
  )
)

(define-public (complete-subtask (parent-task-id uint) (subtask-id uint))
  (let ((subtask (map-get? subtasks {owner: tx-sender, parent-task-id: parent-task-id, subtask-id: subtask-id})))
    (match subtask
      subtask-details
        (begin
          (map-set subtasks
            { owner: tx-sender, parent-task-id: parent-task-id, subtask-id: subtask-id }
            (merge subtask-details { is-completed: true })
          )
          (ok true)
        )
      (err u103) ;; Subtask not found
    )
  )
)

(define-read-only (get-subtasks (parent-task-id uint))
  (map-get? subtask-counters { owner: tx-sender, parent-task-id: parent-task-id })
)




(define-map task-exports
  { owner: principal, export-id: uint }
  { 
    task-ids: (list 100 uint),
    created-at: uint,
    name: (string-utf8 100)
  }
)

(define-map export-counters
  { owner: principal }
  { next-id: uint }
)

(define-public (export-tasks (task-ids (list 100 uint)) (name (string-utf8 100)))
  (let
    (
      (counter (default-to { next-id: u0 } (map-get? export-counters { owner: tx-sender })))
      (next-id (+ (get next-id counter) u1))
    )
    (begin
      (map-set task-exports
        { owner: tx-sender, export-id: next-id }
        { 
          task-ids: task-ids,
          created-at: block-height,
          name: name
        }
      )
      (map-set export-counters
        { owner: tx-sender }
        { next-id: next-id }
      )
      (ok next-id)
    )
  )
)

(define-public (import-tasks (from-principal principal) (export-id uint))
  (let
    (
      (export-data (map-get? task-exports { owner: from-principal, export-id: export-id }))
    )
    (match export-data
      data
        (begin
          (ok (get task-ids data))
        )
      (err u104) ;; Export not found
    )
  )
)

(define-read-only (get-exports)
  (map-get? export-counters { owner: tx-sender })
)