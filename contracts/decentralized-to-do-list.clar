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


(define-map task-vote-proposals
  { task-id: uint, proposal-id: uint }
  {
    proposer: principal,
    action: (string-utf8 20),
    votes-for: uint,
    votes-against: uint,
    status: (string-utf8 20),
    created-at: uint,
    expires-at: uint
  }
)

(define-map voter-records
  { task-id: uint, proposal-id: uint, voter: principal }
  { vote: bool }
)

(define-map proposal-counters
  { task-id: uint }
  { next-id: uint }
)

(define-public (create-vote-proposal (task-id uint) (action (string-utf8 20)) (duration uint))
  (let
    (
      (counter (default-to { next-id: u0 } (map-get? proposal-counters { task-id: task-id })))
      (next-id (+ (get next-id counter) u1))
      (expiry (+ block-height duration))
    )
    (begin
      (map-set task-vote-proposals
        { task-id: task-id, proposal-id: next-id }
        {
          proposer: tx-sender,
          action: action,
          votes-for: u0,
          votes-against: u0,
          status: u"active",
          created-at: block-height,
          expires-at: expiry
        }
      )
      (map-set proposal-counters { task-id: task-id } { next-id: next-id })
      (ok next-id)
    )
  )
)

(define-public (cast-vote (task-id uint) (proposal-id uint) (vote bool))
  (let
    (
      (proposal (map-get? task-vote-proposals { task-id: task-id, proposal-id: proposal-id }))
    )
    (match proposal
      proposal-data
        (begin
          (map-set voter-records
            { task-id: task-id, proposal-id: proposal-id, voter: tx-sender }
            { vote: vote }
          )
          (map-set task-vote-proposals
            { task-id: task-id, proposal-id: proposal-id }
            (merge proposal-data {
              votes-for: (if vote (+ (get votes-for proposal-data) u1) (get votes-for proposal-data)),
              votes-against: (if vote (get votes-against proposal-data) (+ (get votes-against proposal-data) u1))
            })
          )
          (ok true)
        )
      (err u200)
    )
  )
)



(define-read-only (get-vote-results (task-id uint) (proposal-id uint))
  (let
    (
      (proposal (map-get? task-vote-proposals { task-id: task-id, proposal-id: proposal-id }))
    )
    (match proposal
      proposal-data
        (ok {
          votes-for: (get votes-for proposal-data),
          votes-against: (get votes-against proposal-data),
          status: (get status proposal-data)
        })
      (err u201)
    )
  )
)

(define-map user-badges
  { owner: principal }
  { earned-badges: (list 20 (string-utf8 50)) }
)

(define-map badge-criteria
  { badge-id: (string-utf8 50) }
  {
    name: (string-utf8 50),
    description: (string-utf8 200),
    requirement: uint
  }
)

(define-public (initialize-badge-system)
  (begin
    (map-set badge-criteria
      { badge-id: u"task-master" }
      { name: u"Task Master", description: u"Complete 50 tasks", requirement: u50 }
    )
    (map-set badge-criteria
      { badge-id: u"speed-demon" }
      { name: u"Speed Demon", description: u"Complete 10 tasks before due date", requirement: u10 }
    )
    (map-set badge-criteria
      { badge-id: u"perfectionist" }
      { name: u"Perfectionist", description: u"Complete 25 high-priority tasks", requirement: u25 }
    )
    (ok true)
  )
)

(define-public (check-and-award-badges)
  (let
    (
      (stats (default-to { tasks-completed: u0 } (map-get? user-statistics { owner: tx-sender })))
      (current-badges (default-to { earned-badges: (list) } (map-get? user-badges { owner: tx-sender })))
    )
    (begin
      (if (>= (get tasks-completed stats) u50)
        (map-set user-badges
          { owner: tx-sender }
          { earned-badges: (unwrap-panic (as-max-len? (append (get earned-badges current-badges) u"task-master") u20)) }
        )
        true
      )
      (ok true)
    )
  )
)

(define-map workspaces
  { workspace-id: uint }
  {
    name: (string-utf8 100),
    description: (string-utf8 500),
    owner: principal,
    created-at: uint,
    is-public: bool
  }
)

(define-map workspace-members
  { workspace-id: uint, member: principal }
  {
    role: (string-utf8 20),
    joined-at: uint,
    permissions: uint
  }
)

(define-map workspace-tasks
  { workspace-id: uint, task-id: uint }
  {
    description: (string-utf8 500),
    assigned-to: principal,
    created-by: principal,
    status: (string-utf8 20),
    priority: uint,
    due-date: uint,
    created-at: uint
  }
)

(define-map workspace-counters
  { workspace-id: uint }
  { next-task-id: uint }
)

(define-map global-workspace-counter
  { counter: uint }
  { next-workspace-id: uint }
)

(define-constant ERR-WORKSPACE-NOT-FOUND (err u300))
(define-constant ERR-NOT-WORKSPACE-MEMBER (err u301))
(define-constant ERR-INSUFFICIENT-PERMISSIONS (err u302))

(define-public (create-workspace (name (string-utf8 100)) (description (string-utf8 500)) (is-public bool))
  (let
    (
      (counter (default-to { next-workspace-id: u0 } (map-get? global-workspace-counter { counter: u0 })))
      (next-id (+ (get next-workspace-id counter) u1))
    )
    (begin
      (map-set workspaces
        { workspace-id: next-id }
        {
          name: name,
          description: description,
          owner: tx-sender,
          created-at: block-height,
          is-public: is-public
        }
      )
      (map-set workspace-members
        { workspace-id: next-id, member: tx-sender }
        {
          role: u"owner",
          joined-at: block-height,
          permissions: u7
        }
      )
      (map-set global-workspace-counter
        { counter: u0 }
        { next-workspace-id: next-id }
      )
      (ok next-id)
    )
  )
)

(define-public (join-workspace (workspace-id uint))
  (let
    (
      (workspace (map-get? workspaces { workspace-id: workspace-id }))
    )
    (match workspace
      workspace-data
        (if (get is-public workspace-data)
          (begin
            (map-set workspace-members
              { workspace-id: workspace-id, member: tx-sender }
              {
                role: u"member",
                joined-at: block-height,
                permissions: u3
              }
            )
            (ok true)
          )
          ERR-INSUFFICIENT-PERMISSIONS
        )
      ERR-WORKSPACE-NOT-FOUND
    )
  )
)

(define-public (invite-to-workspace (workspace-id uint) (member principal) (role (string-utf8 20)))
  (let
    (
      (workspace (map-get? workspaces { workspace-id: workspace-id }))
      (inviter-membership (map-get? workspace-members { workspace-id: workspace-id, member: tx-sender }))
    )
    (match workspace
      workspace-data
        (match inviter-membership
          inviter-data
            (if (>= (get permissions inviter-data) u5)
              (begin
                (map-set workspace-members
                  { workspace-id: workspace-id, member: member }
                  {
                    role: role,
                    joined-at: block-height,
                    permissions: u3
                  }
                )
                (ok true)
              )
              ERR-INSUFFICIENT-PERMISSIONS
            )
          ERR-NOT-WORKSPACE-MEMBER
        )
      ERR-WORKSPACE-NOT-FOUND
    )
  )
)

(define-public (create-workspace-task 
    (workspace-id uint) 
    (description (string-utf8 500)) 
    (assigned-to principal) 
    (priority uint) 
    (due-date uint)
  )
  (let
    (
      (workspace (map-get? workspaces { workspace-id: workspace-id }))
      (membership (map-get? workspace-members { workspace-id: workspace-id, member: tx-sender }))
      (counter (default-to { next-task-id: u0 } (map-get? workspace-counters { workspace-id: workspace-id })))
      (next-id (+ (get next-task-id counter) u1))
    )
    (match workspace
      workspace-data
        (match membership
          member-data
            (if (>= (get permissions member-data) u3)
              (begin
                (map-set workspace-tasks
                  { workspace-id: workspace-id, task-id: next-id }
                  {
                    description: description,
                    assigned-to: assigned-to,
                    created-by: tx-sender,
                    status: u"pending",
                    priority: priority,
                    due-date: due-date,
                    created-at: block-height
                  }
                )
                (map-set workspace-counters
                  { workspace-id: workspace-id }
                  { next-task-id: next-id }
                )
                (ok next-id)
              )
              ERR-INSUFFICIENT-PERMISSIONS
            )
          ERR-NOT-WORKSPACE-MEMBER
        )
      ERR-WORKSPACE-NOT-FOUND
    )
  )
)

(define-public (update-workspace-task-status (workspace-id uint) (task-id uint) (status (string-utf8 20)))
  (let
    (
      (task (map-get? workspace-tasks { workspace-id: workspace-id, task-id: task-id }))
      (membership (map-get? workspace-members { workspace-id: workspace-id, member: tx-sender }))
    )
    (match task
      task-data
        (match membership
          member-data
            (if (or (is-eq tx-sender (get assigned-to task-data)) (>= (get permissions member-data) u5))
              (begin
                (map-set workspace-tasks
                  { workspace-id: workspace-id, task-id: task-id }
                  (merge task-data { status: status })
                )
                (ok true)
              )
              (err ERR-INSUFFICIENT-PERMISSIONS)
            )
          (err ERR-NOT-WORKSPACE-MEMBER)
        )
      (err ERR-TASK-NOT-FOUND)
    )
  )
)

(define-public (assign-workspace-task (workspace-id uint) (task-id uint) (new-assignee principal))
  (let
    (
      (task (map-get? workspace-tasks { workspace-id: workspace-id, task-id: task-id }))
      (membership (map-get? workspace-members { workspace-id: workspace-id, member: tx-sender }))
      (assignee-membership (map-get? workspace-members { workspace-id: workspace-id, member: new-assignee }))
    )
    (match task
      task-data
        (match membership
          member-data
            (match assignee-membership
              assignee-data
                (if (>= (get permissions member-data) u3)
                  (begin
                    (map-set workspace-tasks
                      { workspace-id: workspace-id, task-id: task-id }
                      (merge task-data { assigned-to: new-assignee })
                    )
                    (ok true)
                  )
                  (err ERR-INSUFFICIENT-PERMISSIONS)
                )
              (err ERR-NOT-WORKSPACE-MEMBER)
            )
          (err ERR-NOT-WORKSPACE-MEMBER)
        )
      (err ERR-TASK-NOT-FOUND)
    )
  )
)

(define-read-only (get-workspace (workspace-id uint))
  (map-get? workspaces { workspace-id: workspace-id })
)

(define-read-only (get-workspace-task (workspace-id uint) (task-id uint))
  (map-get? workspace-tasks { workspace-id: workspace-id, task-id: task-id })
)

(define-read-only (get-workspace-membership (workspace-id uint) (member principal))
  (map-get? workspace-members { workspace-id: workspace-id, member: member })
)

(define-read-only (is-workspace-member (workspace-id uint) (member principal))
  (is-some (map-get? workspace-members { workspace-id: workspace-id, member: member }))
)

(define-map task-bounties
  { task-owner: principal, task-id: uint }
  {
    bounty-amount: uint,
    bounty-placer: principal,
    is-active: bool,
    requirements: (string-utf8 200),
    expires-at: uint,
    created-at: uint
  }
)

(define-map bounty-claims
  { task-owner: principal, task-id: uint, claimer: principal }
  {
    claim-proof: (string-utf8 500),
    submitted-at: uint,
    status: (string-utf8 20)
  }
)

(define-map escrowed-stx
  { task-owner: principal, task-id: uint }
  { amount: uint }
)

(define-constant ERR-INSUFFICIENT-STX (err u400))
(define-constant ERR-BOUNTY-NOT-FOUND (err u401))
(define-constant ERR-BOUNTY-EXPIRED (err u402))
(define-constant ERR-ALREADY-CLAIMED (err u403))
(define-constant ERR-NOT-BOUNTY-PLACER (err u404))
(define-constant ERR-BOUNTY-NOT-ACTIVE (err u405))

(define-public (place-bounty 
    (task-owner principal) 
    (task-id uint) 
    (bounty-amount uint) 
    (requirements (string-utf8 200)) 
    (duration uint)
  )
  (let 
    (
      (task (map-get? tasks { owner: task-owner, task-id: task-id }))
      (expiry (+ block-height duration))
    )
    (match task
      task-details
        (begin
          (try! (stx-transfer? bounty-amount tx-sender (as-contract tx-sender)))
          (map-set task-bounties
            { task-owner: task-owner, task-id: task-id }
            {
              bounty-amount: bounty-amount,
              bounty-placer: tx-sender,
              is-active: true,
              requirements: requirements,
              expires-at: expiry,
              created-at: block-height
            }
          )
          (map-set escrowed-stx
            { task-owner: task-owner, task-id: task-id }
            { amount: bounty-amount }
          )
          (ok true)
        )
      ERR-TASK-NOT-FOUND
    )
  )
)

(define-public (submit-bounty-claim 
    (task-owner principal) 
    (task-id uint) 
    (claim-proof (string-utf8 500))
  )
  (let
    (
      (bounty (map-get? task-bounties { task-owner: task-owner, task-id: task-id }))
      (existing-claim (map-get? bounty-claims { task-owner: task-owner, task-id: task-id, claimer: tx-sender }))
    )
    (match bounty
      bounty-data
        (if (and (get is-active bounty-data) (< block-height (get expires-at bounty-data)))
          (if (is-none existing-claim)
            (begin
              (map-set bounty-claims
                { task-owner: task-owner, task-id: task-id, claimer: tx-sender }
                {
                  claim-proof: claim-proof,
                  submitted-at: block-height,
                  status: u"pending"
                }
              )
              (ok true)
            )
            ERR-ALREADY-CLAIMED
          )
          ERR-BOUNTY-EXPIRED
        )
      ERR-BOUNTY-NOT-FOUND
    )
  )
)

(define-public (approve-bounty-claim 
    (task-owner principal) 
    (task-id uint) 
    (claimer principal)
  )
  (let
    (
      (bounty (map-get? task-bounties { task-owner: task-owner, task-id: task-id }))
      (claim (map-get? bounty-claims { task-owner: task-owner, task-id: task-id, claimer: claimer }))
      (escrow (map-get? escrowed-stx { task-owner: task-owner, task-id: task-id }))
    )
    (match bounty
      bounty-data
        (match claim
          claim-data
            (match escrow
              escrow-data
                (if (is-eq tx-sender (get bounty-placer bounty-data))
                  (begin
                    (try! (as-contract (stx-transfer? (get amount escrow-data) tx-sender claimer)))
                    (map-set bounty-claims
                      { task-owner: task-owner, task-id: task-id, claimer: claimer }
                      (merge claim-data { status: u"approved" })
                    )
                    (map-set task-bounties
                      { task-owner: task-owner, task-id: task-id }
                      (merge bounty-data { is-active: false })
                    )
                    (map-delete escrowed-stx { task-owner: task-owner, task-id: task-id })
                    (ok true)
                  )
                  ERR-NOT-BOUNTY-PLACER
                )
              ERR-BOUNTY-NOT-FOUND
            )
          ERR-BOUNTY-NOT-FOUND
        )
      ERR-BOUNTY-NOT-FOUND
    )
  )
)

(define-public (reject-bounty-claim 
    (task-owner principal) 
    (task-id uint) 
    (claimer principal)
  )
  (let
    (
      (bounty (map-get? task-bounties { task-owner: task-owner, task-id: task-id }))
      (claim (map-get? bounty-claims { task-owner: task-owner, task-id: task-id, claimer: claimer }))
    )
    (match bounty
      bounty-data
        (match claim
          claim-data
            (if (is-eq tx-sender (get bounty-placer bounty-data))
              (begin
                (map-set bounty-claims
                  { task-owner: task-owner, task-id: task-id, claimer: claimer }
                  (merge claim-data { status: u"rejected" })
                )
                (ok true)
              )
              ERR-NOT-BOUNTY-PLACER
            )
          ERR-BOUNTY-NOT-FOUND
        )
      ERR-BOUNTY-NOT-FOUND
    )
  )
)

(define-public (cancel-bounty (task-owner principal) (task-id uint))
  (let
    (
      (bounty (map-get? task-bounties { task-owner: task-owner, task-id: task-id }))
      (escrow (map-get? escrowed-stx { task-owner: task-owner, task-id: task-id }))
    )
    (match bounty
      bounty-data
        (match escrow
          escrow-data
            (if (is-eq tx-sender (get bounty-placer bounty-data))
              (begin
                (try! (as-contract (stx-transfer? (get amount escrow-data) tx-sender (get bounty-placer bounty-data))))
                (map-set task-bounties
                  { task-owner: task-owner, task-id: task-id }
                  (merge bounty-data { is-active: false })
                )
                (map-delete escrowed-stx { task-owner: task-owner, task-id: task-id })
                (ok true)
              )
              ERR-NOT-BOUNTY-PLACER
            )
          ERR-BOUNTY-NOT-FOUND
        )
      ERR-BOUNTY-NOT-FOUND
    )
  )
)

(define-public (claim-expired-bounty (task-owner principal) (task-id uint))
  (let
    (
      (bounty (map-get? task-bounties { task-owner: task-owner, task-id: task-id }))
      (escrow (map-get? escrowed-stx { task-owner: task-owner, task-id: task-id }))
    )
    (match bounty
      bounty-data
        (match escrow
          escrow-data
            (if (and (get is-active bounty-data) (>= block-height (get expires-at bounty-data)))
              (begin
                (try! (as-contract (stx-transfer? (get amount escrow-data) tx-sender (get bounty-placer bounty-data))))
                (map-set task-bounties
                  { task-owner: task-owner, task-id: task-id }
                  (merge bounty-data { is-active: false })
                )
                (map-delete escrowed-stx { task-owner: task-owner, task-id: task-id })
                (ok true)
              )
              ERR-BOUNTY-NOT-ACTIVE
            )
          ERR-BOUNTY-NOT-FOUND
        )
      ERR-BOUNTY-NOT-FOUND
    )
  )
)

(define-read-only (get-bounty (task-owner principal) (task-id uint))
  (map-get? task-bounties { task-owner: task-owner, task-id: task-id })
)

(define-read-only (get-bounty-claim (task-owner principal) (task-id uint) (claimer principal))
  (map-get? bounty-claims { task-owner: task-owner, task-id: task-id, claimer: claimer })
)

(define-read-only (get-escrow-amount (task-owner principal) (task-id uint))
  (default-to u0 (get amount (map-get? escrowed-stx { task-owner: task-owner, task-id: task-id })))
)