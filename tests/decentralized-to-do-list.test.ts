import { describe, it, beforeEach, expect } from 'vitest';

// Mocking the Task Contract for testing purposes
const mockTasks = {
  state: {
    tasks: {} as Record<string, any>, // Maps (owner, task-id) -> task data
    taskCounters: {} as Record<string, { nextId: number }>, // Maps owner -> next task id
  },
  addTask: (description: string, caller: string) => {
    // Get or initialize the task counter for the caller
    const taskCounter = mockTasks.state.taskCounters[caller] || { nextId: 0 };

    // Increment the task ID
    const nextTaskId = taskCounter.nextId + 1;

    // Store the new task
    mockTasks.state.tasks[`${caller}-${nextTaskId}`] = {
      description,
      isCompleted: false,
      createdAt: Date.now(),
    };

    // Update the task counter
    mockTasks.state.taskCounters[caller] = { nextId: nextTaskId };

    return { value: nextTaskId };
  },

  completeTask: (taskId: number, caller: string) => {
    const taskKey = `${caller}-${taskId}`;
    const task = mockTasks.state.tasks[taskKey];

    if (task) {
      // Mark task as completed
      task.isCompleted = true;
      return { value: true };
    }
    return { error: 101 }; // Task not found
  },

  deleteTask: (taskId: number, caller: string) => {
    const taskKey = `${caller}-${taskId}`;
    const task = mockTasks.state.tasks[taskKey];

    if (task) {
      // Delete the task
      delete mockTasks.state.tasks[taskKey];
      return { value: true };
    }
    return { error: 101 }; // Task not found
  },

  getTask: (owner: string, taskId: number) => {
    const taskKey = `${owner}-${taskId}`;
    return mockTasks.state.tasks[taskKey] || null;
  },

  getUserTasks: (owner: string) => {
    return Object.keys(mockTasks.state.tasks)
      .filter((key) => key.startsWith(owner))
      .map((key) => mockTasks.state.tasks[key]);
  },
};

describe('Task Management Contract', () => {
  let user1: string, user2;

  beforeEach(() => {
    // Initialize mock state and user principals
    user1 = 'ST1234...';
    user2 = 'ST5678...';

    mockTasks.state = {
      tasks: {},
      taskCounters: {},
    };
  });

  it('should allow a user to add a new task', () => {
    const result = mockTasks.addTask('Task 1 description', user1);
    expect(result).toEqual({ value: 1 });
    expect(mockTasks.state.tasks['ST1234...-1']).toEqual({
      description: 'Task 1 description',
      isCompleted: false,
      createdAt: expect.any(Number),
    });
  });

  it('should allow a user to mark a task as completed', () => {
    mockTasks.addTask('Task 1 description', user1);
    const result = mockTasks.completeTask(1, user1);
    expect(result).toEqual({ value: true });
    expect(mockTasks.state.tasks['ST1234...-1'].isCompleted).toBe(true);
  });

  it('should return error when trying to complete a non-existent task', () => {
    const result = mockTasks.completeTask(999, user1);
    expect(result).toEqual({ error: 101 });
  });

  it('should allow a user to delete a task', () => {
    mockTasks.addTask('Task 1 description', user1);
    const result = mockTasks.deleteTask(1, user1);
    expect(result).toEqual({ value: true });
    expect(mockTasks.state.tasks['ST1234...-1']).toBeUndefined();
  });

  it('should return error when trying to delete a non-existent task', () => {
    const result = mockTasks.deleteTask(999, user1);
    expect(result).toEqual({ error: 101 });
  });

  it('should retrieve a task by owner and task id', () => {
    mockTasks.addTask('Task 1 description', user1);
    const task = mockTasks.getTask(user1, 1);
    expect(task).toEqual({
      description: 'Task 1 description',
      isCompleted: false,
      createdAt: expect.any(Number),
    });
  });

  it('should return null for a non-existent task', () => {
    const task = mockTasks.getTask(user1, 999);
    expect(task).toBeNull();
  });

  it('should retrieve all tasks for a user', () => {
    mockTasks.addTask('Task 1 description', user1);
    mockTasks.addTask('Task 2 description', user1);
    const tasks = mockTasks.getUserTasks(user1);
    expect(tasks).toHaveLength(2);
    expect(tasks[0].description).toBe('Task 1 description');
    expect(tasks[1].description).toBe('Task 2 description');
  });
});
