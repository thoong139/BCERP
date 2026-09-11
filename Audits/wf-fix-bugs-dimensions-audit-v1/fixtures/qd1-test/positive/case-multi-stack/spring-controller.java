// REQ-ID: REQ-API-002
// FEAT-ID: FEAT-DEMO-ROUTE-002
// Fixture for IMP-001: Spring Boot route detection
// Tests: @GetMapping, @PostMapping, @RequestMapping

package com.demo.controller;

import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/users")
public class UserController {

    @GetMapping
    public List<User> getAll() { return List.of(); }

    @GetMapping("/{id}")
    public User getById(@PathVariable Long id) { return null; }

    @PostMapping
    public User create(@RequestBody User user) { return user; }

    @PutMapping("/{id}")
    public User update(@PathVariable Long id, @RequestBody User user) { return user; }

    @DeleteMapping("/{id}")
    public void delete(@PathVariable Long id) {}

    @GetMapping("/search")
    public List<User> search(@RequestParam String query) { return List.of(); }
}
