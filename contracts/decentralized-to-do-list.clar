(define-map tasks 
  {
    owner: principal,
    task-id: uint
  }
  {
    description: (string-utf8 500),
    is-completed: bool,
    created-at: uint
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
(define-public (add-task (description (string-utf8 500)))
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
          created-at: block-height
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