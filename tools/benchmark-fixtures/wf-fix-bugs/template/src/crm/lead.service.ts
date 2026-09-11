// REQ-ID: REQ-CRM-003, REQ-CRM-004, REQ-CRM-005
// FEAT-ID: FEAT-CRM-LEAD-001
// Module: crm · Feature: Lead Tracking

import { Customer, CustomerService } from './customer.service';

export type LeadStatus = 'NEW' | 'QUALIFIED' | 'WON' | 'LOST';

export interface Lead {
  leadId: string;
  email: string;
  fullName: string;
  status: LeadStatus;
  score: number;
  activities: Activity[];
}

export interface Activity {
  type: string;
  timestamp: Date;
}

export class LeadService {
  private leads: Map<string, Lead> = new Map();

  constructor(private customerService: CustomerService) {}

  /**
   * REQ-CRM-003: Convert qualified lead to customer.
   * Healthy logic, but depends on customer.createCustomer() which has BUG-C01 (null return).
   * BUG-CR01 [HIGH][llm-scan][QD10]: Cross-module integration — không handle undefined return từ createCustomer.
   *   Khi BUG-C01 triggered → return statement gây runtime crash downstream.
   *   Expected detection: QD10 cross-module integration probe.
   */
  convertToCustomer(leadId: string): Customer {
    const lead = this.leads.get(leadId);
    if (!lead) throw new Error('Lead not found');
    if (lead.status !== 'QUALIFIED') throw new Error('Lead must be QUALIFIED');
    const customer = this.customerService.createCustomer(lead.email, lead.fullName);
    lead.status = 'WON';
    return customer;
  }

  /**
   * REQ-CRM-004: Track lead status transitions.
   * BUG-CR02 [MEDIUM][llm-scan][QD2,QD11]: Missing state machine validation.
   *   Should: prevent invalid transitions (e.g., WON → NEW).
   *   Currently: allows any status change.
   */
  setStatus(leadId: string, newStatus: LeadStatus): void {
    const lead = this.leads.get(leadId);
    if (lead) {
      lead.status = newStatus;
    }
  }

  /**
   * REQ-CRM-005: Calculate lead score from activities.
   * BUG-CR03 [MEDIUM][static-scan][QD4]: Performance — O(n²) nested loop.
   *   activities.forEach + indexOf inside → O(n²). Should use Set/Map.
   *   Expected fix: dedupe with Set.
   */
  calculateScore(leadId: string): number {
    const lead = this.leads.get(leadId);
    if (!lead) return 0;
    const uniqueTypes: string[] = [];
    lead.activities.forEach(a => {
      if (uniqueTypes.indexOf(a.type) === -1) {
        uniqueTypes.push(a.type);
      }
    });
    return uniqueTypes.length * 10;
  }
}
