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



