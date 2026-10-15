package com.forever.foreverapi.model.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import java.time.Instant;

@Entity
@Table(name = "saved_addresses")
@Getter @Setter @NoArgsConstructor
public class SavedAddress {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @ManyToOne(fetch = FetchType.LAZY, optional = false) @JoinColumn(name = "user_id")
    private User user;
    private String label;
    @Column(name = "first_name") private String firstName;
    @Column(name = "last_name") private String lastName;
    private String email;
    private String street;
    private String city;
    private String state;
    private String zipcode;
    private String country;
    private String phone;
    @Column(name = "created_at", updatable = false) private Instant createdAt = Instant.now();
}
