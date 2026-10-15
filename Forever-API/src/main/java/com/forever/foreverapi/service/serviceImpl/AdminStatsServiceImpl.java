package com.forever.foreverapi.service.serviceImpl;

import com.forever.foreverapi.service.AdminStatsService;

import com.forever.foreverapi.model.dto.AdminDtos.StatsResponse;
import com.forever.foreverapi.model.entity.OrderStatus;
import com.forever.foreverapi.repository.OrderRepository;
import com.forever.foreverapi.repository.ProductRepository;
import com.forever.foreverapi.model.entity.Role;
import com.forever.foreverapi.repository.UserRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.LinkedHashMap;
import java.util.Map;

@Service
public class AdminStatsServiceImpl implements AdminStatsService {

    private final OrderRepository orders;
    private final ProductRepository products;
    private final UserRepository users;

    public AdminStatsServiceImpl(OrderRepository orders, ProductRepository products, UserRepository users) {
        this.orders = orders;
        this.products = products;
        this.users = users;
    }

    @Transactional(readOnly = true)
    public StatsResponse stats() {
        Map<String, Long> byStatus = new LinkedHashMap<>();
        for (OrderStatus s : OrderStatus.values()) {
            byStatus.put(s.name(), 0L); // every status is present, even with zero orders
        }
        long total = 0;
        for (Object[] row : orders.countGroupedByStatus()) {
            long count = (Long) row[1];
            byStatus.put(((OrderStatus) row[0]).name(), count);
            total += count;
        }
        return new StatsResponse(
                products.countByActive(true),
                products.countByActive(false),
                users.countByRole(Role.USER),
                total,
                byStatus,
                orders.sumTotalExcluding(OrderStatus.CANCELLED));
    }
}
