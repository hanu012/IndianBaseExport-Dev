<?php

namespace App\Http\Requests\Customer;

use Illuminate\Foundation\Http\FormRequest;

/**
 * The customer app's location search box — what has been typed so far.
 */
class PlaceAutocompleteRequest extends FormRequest
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
            'q' => ['required', 'string', 'min:2', 'max:200'],
            // Groups a typing session into one billable autocomplete.
            'session' => ['nullable', 'string', 'max:64'],
        ];
    }
}
