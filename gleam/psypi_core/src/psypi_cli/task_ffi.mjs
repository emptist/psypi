import pg from 'pg';

const { Pool } = pg;

let pool = null;

function getPool() {
  if (!pool) {
    pool = new Pool({
      host: process.env.PSYPI_DB_HOST || 'localhost',
      port: parseInt(process.env.PSYPI_DB_PORT || '5432'),
      database: process.env.PSYPI_DB_NAME || 'psypi',
      user: process.env.PSYPI_DB_USER || 'postgres',
      password: process.env.PSYPI_DB_PASSWORD || '',
      max: 10,
    });
  }
  return pool;
}

export async function add_task(title, description, priority, created_by) {
  const client = getPool();
  try {
    const result = await client.query(
      `INSERT INTO tasks (id, title, description, status, priority, category, created_by)
       VALUES (gen_random_uuid(), $1, $2, 'PENDING', $3, 'general', $4)
       RETURNING id`,
      [title, description, priority, created_by]
    );
    return { Ok: result.rows[0].id };
  } catch (e) {
    return { Error: e.message };
  }
}

export async function list_tasks(status) {
  const client = getPool();
  try {
    let query = 'SELECT * FROM tasks';
    const params = [];
    if (status && status.Some) {
      query += ' WHERE status = $1';
      params.push(status.Some[0]);
    }
    query += ' ORDER BY created_at DESC LIMIT 50';
    const result = await client.query(query, params);
    const tasks = result.rows.map(row => ({
      id: row.id,
      title: row.title,
      description: row.description ? { Some: [row.description] } : { None: [] },
      status: stringToStatus(row.status),
      priority: row.priority || 0,
      result: row.result ? { Some: [JSON.stringify(row.result)] } : { None: [] },
      error: row.error ? { Some: [row.error] } : { None: [] },
      retry_count: row.retry_count || 0,
      created_at: row.created_at?.toISOString() || '',
      updated_at: row.updated_at?.toISOString() || '',
      completed_at: row.completed_at ? { Some: [row.completed_at.toISOString()] } : { None: [] },
      created_by: row.created_by || 'unknown',
    }));
    return { Ok: tasks };
  } catch (e) {
    return { Error: e.message };
  }
}

export async function complete_task(task_id) {
  const client = getPool();
  try {
    const result = await client.query(
      `UPDATE tasks SET status = 'COMPLETED', completed_at = NOW(), updated_at = NOW()
       WHERE id = $1 AND status != 'COMPLETED'
       RETURNING id`,
      [task_id]
    );
    if (result.rowCount === 0) {
      return { Error: 'Task not found or already completed' };
    }
    return { Ok: result.rows[0].id };
  } catch (e) {
    return { Error: e.message };
  }
}

export async function get_task(task_id) {
  const client = getPool();
  try {
    const result = await client.query('SELECT * FROM tasks WHERE id = $1', [task_id]);
    if (result.rows.length === 0) {
      return { Error: 'Task not found' };
    }
    const row = result.rows[0];
    return {
      Ok: {
        id: row.id,
        title: row.title,
        description: row.description ? { Some: [row.description] } : { None: [] },
        status: stringToStatus(row.status),
        priority: row.priority || 0,
        result: row.result ? { Some: [JSON.stringify(row.result)] } : { None: [] },
        error: row.error ? { Some: [row.error] } : { None: [] },
        retry_count: row.retry_count || 0,
        created_at: row.created_at?.toISOString() || '',
        updated_at: row.updated_at?.toISOString() || '',
        completed_at: row.completed_at ? { Some: [row.completed_at.toISOString()] } : { None: [] },
        created_by: row.created_by || 'unknown',
      }
    };
  } catch (e) {
    return { Error: e.message };
  }
}

function stringToStatus(s) {
  switch (s) {
    case 'RUNNING': return { Running: [] };
    case 'COMPLETED': return { Completed: [] };
    case 'FAILED': return { Failed: [] };
    default: return { Pending: [] };
  }
}
