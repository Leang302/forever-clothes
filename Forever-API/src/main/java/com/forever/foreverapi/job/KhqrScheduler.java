package com.forever.foreverapi.job;

import com.forever.foreverapi.model.entity.OrderStatus;
import com.forever.foreverapi.model.entity.PaymentMethod;
import com.forever.foreverapi.repository.OrderRepository;
import com.forever.foreverapi.service.KhqrService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/** Polls all PAYMENT_PENDING KHQR orders every 15 s and confirms them if Bakong shows the payment. */
@Component
public class KhqrScheduler {

    private static final Logger log = LoggerFactory.getLogger(KhqrScheduler.class);

    private final OrderRepository orderRepository;
    private final KhqrService khqrService;

    public KhqrScheduler(OrderRepository orderRepository, KhqrService khqrService) {
        this.orderRepository = orderRepository;
        this.khqrService = khqrService;
    }

    @Scheduled(fixedDelay = 15_000)
    public void pollPendingPayments() {
        var pending = orderRepository.findByPaymentMethodAndStatus(PaymentMethod.KHQR, OrderStatus.PAYMENT_PENDING);
        if (!pending.isEmpty()) {
            log.debug("Checking {} pending KHQR order(s)", pending.size());
        }
        for (var order : pending) {
            try {
                khqrService.checkAndConfirmIfPaid(order);
            } catch (Exception e) {
                log.warn("Error while checking KHQR order {}: {}", order.getId(), e.toString());
            }
        }
    }
}
