# Decentralized Task Management Smart Contract

This project implements a decentralized task management system using a smart contract. The contract allows users to create, update, and manage their tasks in a secure and decentralized manner. Each user can add tasks, mark them as completed, delete them, and retrieve tasks by ID or list all their tasks.

## Features

### Public Functions
1. **Add Task (`add-task`)**
   - Allows a user to add a new task.
   - Tasks include a description, completion status (default: `false`), and creation timestamp.
   - Automatically assigns a unique task ID to each new task.

2. **Complete Task (`complete-task`)**
   - Enables users to mark a specific task as completed.
   - Ensures only the task owner can update the status.

3. **Delete Task (`delete-task`)**
   - Permits users to delete a task they own.
   - If the task does not exist, an error is returned.

### Read-Only Functions
1. **Get Task (`get-task`)**
   - Retrieves details of a specific task by owner and task ID.
   - Returns `null` if the task does not exist.

2. **Get User Tasks**
   - Lists all tasks belonging to a specific user.

### Error Handling
- `ERR-NOT-AUTHORIZED (u100)`: Returned if a user attempts to perform unauthorized actions.
- `ERR-TASK-NOT-FOUND (u101)`: Returned if the specified task does not exist.

## State Management
- **Tasks (`tasks` map)**: Maps a composite key of owner and task ID to task details, including:
  - `description` (string, up to 500 characters)
  - `is-completed` (boolean)
  - `created-at` (timestamp)
- **Task Counters (`task-counters` map)**: Tracks the next task ID for each user.

## Unit Testing

Comprehensive unit tests are provided to ensure the reliability of the contract:
- Verify task creation, completion, deletion, and retrieval functionality.
- Validate proper error handling for non-existent tasks or unauthorized actions.
- Confirm that task data remains isolated between users.

### Test Scenarios
1. Adding a new task with a valid description.
2. Completing an existing task and verifying its status.
3. Deleting an existing task and ensuring it's removed from storage.
4. Retrieving a task by owner and task ID.
5. Handling cases where tasks are missing or unauthorized actions are attempted.
6. Listing all tasks for a user.

## Deployment

This contract can be deployed to any blockchain supporting smart contracts. Each user has a private namespace for their tasks, ensuring secure and isolated task management.

## Future Enhancements
1. Add functionality to update task descriptions.
2. Implement pagination for large task lists.
3. Introduce task sharing or collaboration features between users.
4. Enhance query capabilities with filtering and sorting options.

---

## Getting Started

1. Clone the repository:
   ```bash
   git clone <repository-url>
