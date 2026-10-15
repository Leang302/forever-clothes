package com.forever.foreverapi.config;

import com.forever.foreverapi.common.response.ErrorResponse;
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
    SecurityFilterChain filterChain(HttpSecurity http, JwtService jwtService, JsonMapper json) throws Exception {
        http
                .csrf(csrf -> csrf.disable())
                .cors(Customizer.withDefaults())
                .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .authorizeHttpRequests(a -> a
                        .requestMatchers("/", "/swagger-ui.html", "/swagger-ui/**", "/v3/api-docs/**",
                                "/actuator/health/**").permitAll()
                        .requestMatchers(HttpMethod.OPTIONS, "/**").permitAll()
                        .requestMatchers("/api/auth/**").permitAll()
                        .requestMatchers(HttpMethod.POST, "/api/payway/callback").permitAll()
                        .requestMatchers(HttpMethod.GET, "/api/products/**", "/api/media/**").permitAll()
                        .requestMatchers("/api/admin/**").hasRole("ADMIN")
                        .anyRequest().authenticated())
                .exceptionHandling(e -> e
                        .authenticationEntryPoint((req, res, ex) -> write(res, json, HttpStatus.UNAUTHORIZED,
                                "UNAUTHORIZED", "Authentication required or token expired", req.getRequestURI()))
                        .accessDeniedHandler((req, res, ex) -> write(res, json, HttpStatus.FORBIDDEN,
                                "ACCESS_DENIED", "You do not have permission to do this", req.getRequestURI())))
                .addFilterBefore(new JwtAuthFilter(jwtService), UsernamePasswordAuthenticationFilter.class);
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
