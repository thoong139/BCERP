// Fixture: TypeORM entity with @ManyToOne but no @Index decorator
// Expected signal: "TypeORM: @ManyToOne/@OneToOne thiếu @Index"
import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  ManyToOne,
  JoinColumn,
} from 'typeorm';

// IMP-010 fixture: Entity with @ManyToOne but no Index decorator
@Entity('orders')
export class Order {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  totalAmount: number;

  @Column()
  status: string;

  // Relation without index — should trigger signal
  @ManyToOne(() => Customer)
  @JoinColumn({ name: 'customerId' })
  customer: Customer;

  @Column()
  customerId: string;
}

@Entity('customers')
export class Customer {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  name: string;

  @Column({ unique: true })
  email: string;
}
