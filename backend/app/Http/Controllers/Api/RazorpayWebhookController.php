<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Responses\ApiResponse;
use App\Models\Payment;
use App\Services\Payments\RazorpayClient;
use App\Services\PromotionService;
use App\Services\SubscriptionService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;

/**
 * Razorpay → us. The source of truth for an online payment: the vendor pays
 * in their own browser, so nothing in our apps sees the payment happen.
 *
 * Events (set on the webhook in the Razorpay dashboard):
 *  - payment_link.paid      → activate what the payment was for
 *  - payment_link.expired   → cancel it
 *  - payment_link.cancelled → cancel it
 *
 * Rules:
 *  - The signature is checked against the RAW body before anything else; an
 *    unsigned or wrongly signed call is rejected with 400 and changes nothing.
 *  - Unknown events and unknown links answer 200 so Razorpay stops retrying —
 *    there is nothing to do, and a 4xx would only queue more deliveries.
 *  - Handling is idempotent (SubscriptionService locks and checks status);
 *    Razorpay retries, and the same event arriving twice is normal.
 */
class RazorpayWebhookController extends Controller
{
    public function __construct(
        private readonly RazorpayClient $razorpay,
        private readonly SubscriptionService $subscriptions,
        private readonly PromotionService $promotions,
    ) {}

    public function __invoke(Request $request): JsonResponse
    {
        $rawBody = $request->getContent();

        if (! $this->razorpay->verifyWebhookSignature($rawBody, $request->header('X-Razorpay-Signature'))) {
            Log::warning('Razorpay webhook rejected: bad signature', ['ip' => $request->ip()]);

            return ApiResponse::error('INVALID_SIGNATURE', 'Signature verification failed.', 400);
        }

        $event = (string) $request->input('event');
        $linkId = $request->input('payload.payment_link.entity.id');

        if (! is_string($linkId) || ! in_array($event, ['payment_link.paid', 'payment_link.expired', 'payment_link.cancelled'], true)) {
            return ApiResponse::success(['handled' => false]);
        }

        $payment = Payment::query()
            ->where('gateway', 'razorpay')
            ->where('gateway_order_id', $linkId)
            ->first();

        if ($payment === null) {
            Log::warning('Razorpay webhook for an unknown payment link', ['link' => $linkId, 'event' => $event]);

            return ApiResponse::success(['handled' => false]);
        }

        // A payment belongs to a subscription or a paid promotion; each has
        // its own activation rules.
        $handler = $payment->promotion_id !== null ? $this->promotions : $this->subscriptions;

        if ($event === 'payment_link.paid') {
            $gatewayPaymentId = $request->input('payload.payment.entity.id');

            $handler->completeOnlinePayment(
                $payment,
                is_string($gatewayPaymentId) ? $gatewayPaymentId : null,
            );
        } else {
            $handler->failOnlinePayment($payment);
        }

        return ApiResponse::success(['handled' => true]);
    }
}
