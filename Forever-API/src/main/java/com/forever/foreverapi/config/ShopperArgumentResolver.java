package com.forever.foreverapi.config;

import com.forever.foreverapi.common.security.AuthUser;
import com.forever.foreverapi.common.security.GuestPrincipal;
import com.forever.foreverapi.common.security.ShopperRef;
import com.forever.foreverapi.exception.ApiException;
import org.springframework.core.MethodParameter;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.support.WebDataBinderFactory;
import org.springframework.web.context.request.NativeWebRequest;
import org.springframework.web.method.support.HandlerMethodArgumentResolver;
import org.springframework.web.method.support.ModelAndViewContainer;

import java.util.Set;

/** Injects the {@link ShopperRef} — a registered customer or a guest cart session — for cart/checkout endpoints. */
public class ShopperArgumentResolver implements HandlerMethodArgumentResolver {

    private static final Set<String> CUSTOMER_ROLES = Set.of("USER", "ADMIN");

    @Override
    public boolean supportsParameter(MethodParameter parameter) {
        return parameter.getParameterType() == ShopperRef.class;
    }

    @Override
    public Object resolveArgument(MethodParameter parameter, ModelAndViewContainer mav, NativeWebRequest request,
                                  WebDataBinderFactory binderFactory) {
        var auth = SecurityContextHolder.getContext().getAuthentication();
        Object principal = auth == null ? null : auth.getPrincipal();
        if (principal instanceof AuthUser u && CUSTOMER_ROLES.contains(u.role())) return ShopperRef.user(u.id());
        if (principal instanceof GuestPrincipal g) return ShopperRef.guest(g.sessionId());
        throw ApiException.unauthorized("UNAUTHORIZED", "Log in or start a guest session");
    }
}
