// REQ-ID: REQ-API-004
// FEAT-ID: FEAT-DEMO-ROUTE-004
// Fixture for IMP-001: Express/NestJS route detection
// Tests: app.get, router.post, NestJS @Get/@Post decorators

import express from 'express';
import { Get, Post, Put, Delete, Controller } from '@nestjs/common';

const router = express.Router();

// Express routes
router.get('/api/orders', (req, res) => res.json([]));
router.post('/api/orders', (req, res) => res.json({ id: 1 }));
router.put('/api/orders/:id', (req, res) => res.json({}));
router.delete('/api/orders/:id', (req, res) => res.status(204).send());
router.get('/api/orders/:id', (req, res) => res.json({}));

// NestJS controller style
@Controller('api/inventory')
export class InventoryController {
  @Get()
  findAll() { return []; }

  @Post()
  create() { return {}; }

  @Put(':id')
  update() { return {}; }

  @Delete(':id')
  remove() { return null; }
}
