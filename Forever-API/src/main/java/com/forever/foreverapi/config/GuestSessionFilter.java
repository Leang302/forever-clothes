package com.forever.foreverapi.config;

import com.forever.foreverapi.common.response.ErrorResponse;
import com.forever.foreverapi.common.security.GuestPrincipal;
import com.forever.foreverapi.service.GuestSessionService;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.filter.OncePerRequestFilter;
import tools.jackson.databind.json.JsonMapper;

import java.io.IOException;
import java.time.Instant;
import java.util.List;

/**
 * Turns a valid {@value #HEADER} into a cart-only guest principal (ROLE_GUEST_CART). A request may carry a login
 * OR a guest session, never both — mixing identities is refused outright. An unknown/expired guest token just
 * leaves the request anonymous (so public pages keep working); protected endpoints then answer 401
 * GUEST_SESSION_EXPIRED and the client starts a fresh session.
 */
public class GuestSessionFilter extends OncePerRequestFilter {

    public static final String HEADER = "X-Guest-Session";
    public static final String INVALID_ATTR = GuestSessionFilter.class.getName() + ".invalid";

    private final GuestSessionService sessions;
    private final JsonMapper json;

    public GuestSessionFilter(GuestSessionService sessions, JsonMapper json) {
        this.sessions = sessions;
        this.json = json;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {
        String token = request.getHeader(HEADER);
        if (token == null || token.isBlank()) {
            chain.doFilter(request, response);
            return;
        }
        if (request.getHeader(HttpHeaders.AUTHORIZATION) != null) {
            response.setStatus(HttpStatus.BAD_REQUEST.value());
            response.setContentType(MediaType.APPLICATION_JSON_VALUE);
            json.writeValue(response.getOutputStream(), new ErrorResponse(Instant.now(), 400, "AMBIGUOUS_IDENTITY",
                    "Send either a login token or a guest session, not both", null, request.getRequestURI()));
            return;
        }
        sessions.resolve(token).ifPresentOrElse(id -> SecurityContextHolder.getContext().setAuthentication(
                        new UsernamePasswordAuthenticationToken(new GuestPrincipal(id), null,
                                List.of(new SimpleGrantedAuthority("ROLE_GUEST_CART")))),
                () -> request.setAttribute(INVALID_ATTR, Boolean.TRUE));
        chain.doFilter(request, response);
    }
}
