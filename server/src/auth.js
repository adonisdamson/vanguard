const { anonClient, serviceClient } = require('./supabase');

async function verifyJwt(req) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return { user: null, error: 'Missing or malformed Authorization header' };
  }
  const token = authHeader.slice(7);
  const { data, error } = await anonClient().auth.getUser(token);
  if (error || !data.user) {
    return { user: null, error: 'Invalid or expired token' };
  }
  return { user: data.user, error: null };
}

async function getOperatorRole(userId) {
  const { data, error } = await serviceClient()
    .from('app_users')
    .select('role, is_active')
    .eq('id', userId)
    .single();
  if (error || !data) return null;
  if (!data.is_active) return null;
  return data.role;
}

async function requireAuth(req, res) {
  const { user, error } = await verifyJwt(req);
  if (!user) {
    res.status(401).json({ error: error || 'Unauthorized' });
    return null;
  }
  return user;
}

async function requireRole(req, res, allowedRoles) {
  const user = await requireAuth(req, res);
  if (!user) return null;
  const role = await getOperatorRole(user.id);
  if (!role || !allowedRoles.includes(role)) {
    res.status(403).json({ error: 'Insufficient permissions' });
    return null;
  }
  return { user, role };
}

module.exports = { requireAuth, requireRole, getOperatorRole };
