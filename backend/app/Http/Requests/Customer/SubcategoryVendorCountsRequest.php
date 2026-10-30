<?php

namespace App\Http\Requests\Customer;

use App\Http\Requests\Concerns\HasCustomerLocation;
use Illuminate\Foundation\Http\FormRequest;

/**
 * Location for the subcategories screen's "X vendors" counts.
 *
 * Unlike VendorSearchRequest, a location is NOT required here: this
 * endpoint is called the moment the subcategories screen opens, and the
 * customer's location may not have resolved yet (SPEC section 4.2's own
 * fallback states). Missing location just means every count comes back
 * zero rather than the request being rejected — the grid still renders,
 * it simply has nothing to count against.
 */
class SubcategoryVendorCountsRequest extends FormRequest
{
    use HasCustomerLocation;

    public function authorize(): bool
    {
        return true;
    }

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return $this->locationRules();
    }
}
