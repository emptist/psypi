// FFI helper for creating test data
// This creates JavaScript objects that simulate PostgreSQL query results

export function makeTaskRow1() {
  return {
    id: "task-123",
    title: "Test Task",
    description: "A test task",
    status: "PENDING",
    priority: 100,
    result: null,
    error: null,
    retry_count: 0,
    created_at: "2026-05-04T00:00:00Z",
    updated_at: "2026-05-04T00:00:00Z",
    completed_at: null,
    created_by: "S-psypi-psypi",
  };
}

export function makeTaskRow2() {
  return {
    id: "task-456",
    title: "Completed Task",
    description: null,
    status: "COMPLETED",
    priority: 50,
    result: "Task completed successfully",
    error: null,
    retry_count: 1,
    created_at: "2026-05-04T00:00:00Z",
    updated_at: "2026-05-04T01:00:00Z",
    completed_at: "2026-05-04T01:00:00Z",
    created_by: "S-psypi-psypi",
  };
}

export function makeIdRow() {
  return { id: "task-789" };
}
