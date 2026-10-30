<?php

namespace App\Http\Requests\Customer;

use Illuminate\Foundation\Http\FormRequest;

/**
 * The search result the customer tapped, to be turned into a point.
 */
class PlaceDetailsRequest extends FormRequest
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
            'place_id' => ['required', 'string', 'max:255'],
            'session' => ['nullable', 'string', 'max:64'],
        ];
    }
}
