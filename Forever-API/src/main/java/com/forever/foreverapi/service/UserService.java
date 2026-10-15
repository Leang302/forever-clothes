package com.forever.foreverapi.service;

import com.forever.foreverapi.model.dto.UserDtos.UpdateProfileRequest;
import com.forever.foreverapi.model.dto.UserDtos.UserResponse;

public interface UserService {
    UserResponse get(Long id);
    UserResponse update(Long id, UpdateProfileRequest req);
}
