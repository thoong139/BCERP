// ORM Model: Customer
// QD6 issue: Schema drift — extra column 'nickname' not in migration

export interface Customer {
  id: number;
  name: string;
  email: string;
  nickname: string;  // Not in migration — schema drift
  created_at: Date;
}
