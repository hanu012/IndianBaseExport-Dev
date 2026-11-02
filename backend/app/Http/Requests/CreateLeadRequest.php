<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

/**
 * POST /api/leads (SPEC section 4 item 7, task 5.4). Validates that the
 * referenced rows exist — the same floor every request applies — but
 * deliberately does NOT re-verify the vendor's active subscription
 * actually covers `subcategory_id` in `zone_id` at write time. See
 * Lead's own docblock and SPEC section 9 for why: a lead is an
 * append-only evidence-of-contact-intent record, not a capacity- or
 * money-bounded write like a subscription.
 *
 * `customer_id` is never accepted from the client — the controller
 * always derives it from the authenticated token.
 */
class CreateLeadRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'vendor_id' => ['required', 'integer', 'exists:vendors,id'],
            // Optional from the Feed, where a post is not tied to one service:
            // LeadController falls back to the vendor's own first service.
            'subcategory_id' => ['nullable', 'integer', 'exists:subcategories,id'],
            'zone_id' => ['nullable', 'integer', 'exists:zones,id'],
            'channel' => ['required', 'string', 'in:call,whatsapp'],
            // Set when the contact started from a paid promotion — the
            // vendor's "calls from this ad". Must be that vendor's own.
            'promotion_id' => [
                'nullable', 'integer',
                Rule::exists('promotions', 'id')->where('vendor_id', (int) $this->input('vendor_id')),
            ],
        ];
    }
}
