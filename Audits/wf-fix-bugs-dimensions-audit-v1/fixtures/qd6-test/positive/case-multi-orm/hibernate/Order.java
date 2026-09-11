// Fixture: JPA entity with @ManyToOne but no index annotation
// IMP-010 test: missing performance index on FK relations
package com.demo.domain;

import javax.persistence.*;

@Entity
@Table(name = "orders")
public class Order {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String orderNumber;

    // FK relations without corresponding DB index
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "customer_id", nullable = false)
    private Customer customer;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "product_id", nullable = false)
    private Product product;

    @Column(nullable = false)
    private Integer quantity;

    public Long getId() { return id; }
    public String getOrderNumber() { return orderNumber; }
}
