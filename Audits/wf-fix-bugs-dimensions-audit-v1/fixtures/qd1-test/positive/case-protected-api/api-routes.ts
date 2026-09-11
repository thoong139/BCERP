// REQ-ID: REQ-API-001
// FEAT-ID: FEAT-APP-AUTH-001
import { Router } from 'express';

const router = Router();

// Protected endpoints requiring authentication
router.get('/api/users', authMiddleware, (req, res) => {
  res.json({ users: [] });
});

router.post('/api/users', authMiddleware, (req, res) => {
  res.status(201).json({ id: 1 });
});

router.get('/api/profile', authMiddleware, (req, res) => {
  res.json({ profile: {} });
});

// Public endpoint
router.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

export default router;
