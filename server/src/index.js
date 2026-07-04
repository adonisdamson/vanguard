require('dotenv').config();
const express = require('express');

const membersRouter = require('./routes/members');
const adminRouter = require('./routes/admin');
const exportsRouter = require('./routes/exports');
const bootstrapRouter = require('./routes/bootstrap');
const migrationsRouter = require('./routes/migrations');

const app = express();
app.use(express.json());

app.use('/api/members', membersRouter);
app.use('/api/admin/operators', adminRouter);
app.use('/api/exports', exportsRouter);
app.use('/api/admin/bootstrap-superadmin', bootstrapRouter);
app.use('/api/internal/run-migrations', migrationsRouter);

app.get('/health', (_, res) => res.json({ ok: true }));

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Vanguard API listening on :${PORT}`));
