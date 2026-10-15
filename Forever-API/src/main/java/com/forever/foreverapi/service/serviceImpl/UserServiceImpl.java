package com.forever.foreverapi.service.serviceImpl;

import com.forever.foreverapi.service.UserService;

import com.forever.foreverapi.exception.ApiException;
import com.forever.foreverapi.model.dto.UserDtos.UpdateProfileRequest;
import com.forever.foreverapi.model.dto.UserDtos.UserResponse;
import com.forever.foreverapi.model.entity.User;
import com.forever.foreverapi.repository.UserRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class UserServiceImpl implements UserService {

    private final UserRepository users;

    public UserServiceImpl(UserRepository users) {
        this.users = users;
    }

    @Transactional(readOnly = true)
    public UserResponse get(Long id) {
        return UserResponse.from(load(id));
    }

    @Transactional
    public UserResponse update(Long id, UpdateProfileRequest req) {
        User user = load(id);
        user.setName(req.name().trim());
        user.setPhone(req.phone() == null || req.phone().isBlank() ? null : req.phone().trim());
        return UserResponse.from(user);
    }

    private User load(Long id) {
        return users.findById(id)
                .filter(User::isEnabled)
                .orElseThrow(() -> ApiException.unauthorized("UNAUTHORIZED", "Account no longer exists"));
    }
}
