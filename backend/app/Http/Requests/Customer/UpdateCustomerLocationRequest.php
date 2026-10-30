<?php

namespace App\Http\Requests\Customer;

use App\Http\Requests\Concerns\HasCustomerLocation;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Validator;

/**
 * Reporting the customer's location (SPEC section 4.2, task 4.6) — a zone
 * picked from the list (the app's zone mode, when the admin has the map
 * off), a GPS point, or a pincode fallback when GPS is denied or
 * unavailable. At least one; several is fine (ZoneMatcher::resolve()
 * decides the order).
 */
class UpdateCustomerLocationRequest extends FormRequest
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
