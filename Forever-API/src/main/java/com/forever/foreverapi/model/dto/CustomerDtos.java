package com.forever.foreverapi.model.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public final class CustomerDtos {
    private CustomerDtos() {}

    public record AddressRequest(
            @NotBlank @Size(max = 50) String label,
            @NotBlank @Size(max = 80) String firstName,
            @NotBlank @Size(max = 80) String lastName,
            @NotBlank @Email String email,
            @NotBlank @Size(max = 200) String street,
            @NotBlank @Size(max = 100) String city,
            @NotBlank @Size(max = 100) String state,
            @NotBlank @Size(max = 20) String zipcode,
            @NotBlank @Size(max = 100) String country,
            @NotBlank @Size(max = 40) String phone) {}

    public record AddressResponse(Long id, String label, String firstName, String lastName, String email,
                                  String street, String city, String state, String zipcode, String country,
                                  String phone) {}
}
