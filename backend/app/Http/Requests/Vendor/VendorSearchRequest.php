<?php

namespace App\Http\Requests\Vendor;

use App\Http\Requests\Concerns\HasCustomerLocation;
use App\Services\VendorSearchService;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Validator;

/**
 * The customer vendor-search query (SPEC section 4 item 4, task 5.3).
 * Location is always explicit — a picked zone, a GPS point or a pincode,
 * same shape as UpdateCustomerLocationRequest — never resolved from the
 * caller's stored profile, since this endpoint is public and returns
 * other people's data, not the caller's own record.
 */
class VendorSearchRequest extends FormRequest
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
        return [
            // Optional: left out, the search covers every service (the home
            // screen's "Vendors near you").
            'subcategory_id' => ['nullable', 'integer', 'exists:subcategories,id'],
            ...$this->locationRules(),
            'per_page' => ['sometimes', 'integer', 'min:1', 'max:50'],
            // The three list-screen sort chips (task 5.3's redesign).
            // Defaults to "nearest" in the service itself, not here, so
            // every other caller of VendorSearchService::search() keeps
            // its own default rather than silently depending on this
            // request class's.
            'sort' => ['sometimes', Rule::in([
                VendorSearchService::SORT_NEAREST,
                VendorSearchService::SORT_RATING,
                VendorSearchService::SORT_NEW,
            ])],
        ];
    }

    public function withValidator(Validator $validator): void
    {
        $validator->after(function (Validator $validator) {
            if (! $this->hasLocation()) {
                $validator->errors()->add(
                    'pincode',
                    'Provide a zone, a latitude/longitude pair or a pincode.'
                );
            }
        });
    }
}
