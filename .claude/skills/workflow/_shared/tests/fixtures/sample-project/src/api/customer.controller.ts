// API Controller: Customer
// QD7 issues: Missing version header, deprecated endpoint

import { CustomerService } from '../features/customer/service';

export class CustomerController {

  // QD7 issue: Deprecated API — should use /api/v2/customer/:id
  async getCustomer(req: any, res: any) {
    const service = new CustomerService();
    const customer = service.getCustomer(req.params.id);
    res.json(customer);
  }

  // QD7 issue: Unversioned endpoint — should be /api/v2/customer/:id
  async deleteCustomer(req: any, res: any) {
    const service = new CustomerService();
    service.deleteCustomer(req.params.id);
    res.status(204).send();
  }

  // No version header in responses
  private setHeaders(res: any) {
    // Missing: res.setHeader('X-API-Version', '2.0');
  }
}
