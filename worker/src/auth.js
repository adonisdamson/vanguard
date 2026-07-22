import { HTTPException } from 'hono/http-exception';
import { anonClient, serviceClient } from './supabase.js';

// Verify the caller's Supabase JWT (same anon-client getUser check as before).
async function verifyJwt(c) {
  const authHeader = c.req.header('authorization');
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return { user: null, error: 'Missing or malformed Authorization header' };
  }
  const token = authHeader.slice(7);
  const { data, error } = await anonClient(c.env).auth.getUser(token);
  if (error || !data.user) {
    return { user: null, error: 'Invalid or expired token' };
  }
  return { user: data.user, error: null };
}

export async function getOperatorRole(env, userId) {
  const { data, error } = await serviceClient(env)
    .from('app_users')
    .select('role, is_active')
    .eq('id', userId)
    .single();
  if (error || !data) return null;
  if (!data.is_active) return null;
  return data.role;
}

// Returns the authenticated user or throws a 401 (formatted by app.onError).
export async function requireAuth(c) {
  const { user, error } = await verifyJwt(c);
  if (!user) {
    throw new HTTPException(401, { message: error || 'Unauthorized' });
  }
  return user;
}

// Returns { user, role } or throws 401/403.
export async function requireRole(c, allowedRoles) {
  const user = await requireAuth(c);
  const role = await getOperatorRole(c.env, user.id);
  if (!role || !allowedRoles.includes(role)) {
    throw new HTTPException(403, { message: 'Insufficient permissions' });
  }
  return { user, role };
}
