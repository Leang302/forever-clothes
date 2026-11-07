package com.forever.foreverapi.config;

import com.forever.foreverapi.common.response.ErrorResponse;
import com.forever.foreverapi.service.GuestSessionService;
import com.forever.foreverapi.service.JwtService;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.security.config.Customizer;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import tools.jackson.databind.json.JsonMapper;

import jakarta.servlet.http.HttpServletResponse;
import java.time.Instant;

@Configuration
@EnableMethodSecurity
public class SecurityConfig {

    @Bean
    PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }

    @Bean
    SecurityFilterChain filterChain(HttpSecurity http, JwtService jwtService, JsonMapper json,
                                    GuestSessionService guestSessions) throws Exception {
        http
                .csrf(csrf -> csrf.disable())
                .cors(Customizer.withDefaults())
                .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .authorizeHttpRequests(a -> a
                        .requestMatchers("/", "/swagger-ui.html", "/swagger-ui/**", "/v3/api-docs/**",
                                "/actuator/health/**").permitAll()
                        .requestMatchers(HttpMethod.OPTIONS, "/**").permitAll()
                        .requestMatchers("/api/auth/**").permitAll()
                        .requestMatchers(HttpMethod.GET, "/api/products/**", "/api/media/**").permitAll()
                        // Guest shopping: start a cart session; open your own order with its order-access token
                        // (checked in the service, not here).
                        .requestMatchers(HttpMethod.POST, "/api/guest-sessions").permitAll()
                        .requestMatchers("/api/guest-orders/**").permitAll()
                        .requestMatchers(HttpMethod.DELETE, "/api/guest-sessions/current").hasRole("GUEST_CART")
                        .requestMatchers("/api/admin/**").hasRole("ADMIN")
                        // Cart + checkout: a registered customer or a guest cart session.
                        .requestMatchers("/api/cart/**", "/api/checkout/**").hasAnyRole("USER", "ADMIN", "GUEST_CART")
                        .requestMatchers(HttpMethod.POST, "/api/orders", "/api/khqr/checkout")
                        .hasAnyRole("USER", "ADMIN", "GUEST_CART")
                        // Everything else (account, order history, wishlist, ...) is for registered accounts only.
                        // Also shuts out JWTs of the retired throwaway GUEST accounts.
                        .anyRequest().hasAnyRole("USER", "ADMIN"))
                .exceptionHandling(e -> e
                        .authenticationEntryPoint((req, res, ex) -> {
                            if (req.getAttribute(GuestSessionFilter.INVALID_ATTR) != null) {
                                write(res, json, HttpStatus.UNAUTHORIZED, "GUEST_SESSION_EXPIRED",
                                        "Your guest session has expired. Start a new one", req.getRequestURI());
                            } else {
                                write(res, json, HttpStatus.UNAUTHORIZED, "UNAUTHORIZED",
                                        "Authentication required or token expired", req.getRequestURI());
                            }
                        })
                        .accessDeniedHandler((req, res, ex) -> write(res, json, HttpStatus.FORBIDDEN,
                                "ACCESS_DENIED", "You do not have permission to do this", req.getRequestURI())))
                .addFilterBefore(new JwtAuthFilter(jwtService), UsernamePasswordAuthenticationFilter.class)
                .addFilterAfter(new GuestSessionFilter(guestSessions, json), JwtAuthFilter.class);
        return http.build();
    }

    private static void write(HttpServletResponse res, JsonMapper json, HttpStatus status, String code,
                              String message, String path) throws java.io.IOException {
        res.setStatus(status.value());
        res.setContentType(MediaType.APPLICATION_JSON_VALUE);
        json.writeValue(res.getOutputStream(),
                new ErrorResponse(Instant.now(), status.value(), code, message, null, path));
    }
}
