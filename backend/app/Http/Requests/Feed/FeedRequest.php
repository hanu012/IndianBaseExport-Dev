<?php

namespace App\Http\Requests\Feed;

use App\Http\Requests\Concerns\HasCustomerLocation;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Validator;

/**
 * GET /api/feed — where the customer is (zone, point or pincode, as for
 * vendor search) and which page.
 */
class FeedRequest extends FormRequest
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
            ...$this->locationRules(),
            'page' => ['sometimes', 'integer', 'min:1'],
            // The chips: for_you (default) | offers | nearby | following.
            'filter' => ['sometimes', 'in:'.implode(',', \App\Services\FeedService::FILTERS)],
            'per_page' => ['sometimes', 'integer', 'min:1', 'max:30'],
        ];
    }

    public function withValidator(Validator $validator): void
    {
        $validator->after(function (Validator $validator) {
            if (! $this->hasLocation()) {
                $validator->errors()->add('pincode', 'Provide a zone, a latitude/longitude pair or a pincode.');
            }
        });
    }
}
