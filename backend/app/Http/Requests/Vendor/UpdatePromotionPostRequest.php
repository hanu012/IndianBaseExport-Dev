<?php

namespace App\Http\Requests\Vendor;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Validator;

/**
 * POST /api/vendors/me/promotions/{promotion}/post — "Edit post": a new
 * caption, and optionally a new photo/video (`file`) or `remove_media`.
 * Package, areas and dates are what was paid for and stay as they are.
 */
class UpdatePromotionPostRequest extends FormRequest
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
        return StorePromotionRequest::mediaRules($this->input('media_type')) + [
            'remove_media' => ['sometimes', 'boolean'],
        ];
    }

    public function withValidator(Validator $validator): void
    {
        $validator->after(function (Validator $validator) {
            $promotion = $this->route('promotion');

            if ($validator->errors()->isEmpty()
                && $this->hasFile('file')
                && $this->input('media_type') === 'video'
                && ! $promotion?->package?->allows_video) {
                $validator->errors()->add('file', 'This package allows a photo only.');
            }
        });
    }
}
