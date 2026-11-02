<?php

namespace App\Http\Requests\Vendor;

use App\Models\PromotionPackage;
use App\Services\PromotionService;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Validator;

/**
 * POST /api/vendors/me/promotions — buy a paid promotion: the package, an
 * optional photo or video (multipart `file`), a caption and the zones to
 * show in. Same file limits as portfolio uploads.
 */
class StorePromotionRequest extends FormRequest
{
    public ?PromotionPackage $package = null;

    public function authorize(): bool
    {
        return true;
    }

    /** Shared with UpdatePromotionPostRequest: the media is optional (decided 2026-10-31). */
    public static function mediaRules(?string $mediaType): array
    {
        return [
            'media_type' => ['nullable', 'required_with:file', 'in:image,video'],
            'file' => $mediaType === 'video'
                ? ['nullable', 'file', 'mimetypes:video/mp4,video/quicktime,video/webm', 'max:51200']
                : ['nullable', 'file', 'image', 'mimes:jpg,jpeg,png,webp', 'max:8192'],
            'caption' => ['required', 'string', 'max:300'],
        ];
    }

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return self::mediaRules($this->input('media_type')) + [
            'promotion_package_id' => ['required', 'integer'],
            'zone_ids' => ['required', 'array', 'min:1'],
            'zone_ids.*' => ['integer', 'distinct'],
        ];
    }

    public function withValidator(Validator $validator): void
    {
        $validator->after(function (Validator $validator) {
            if ($validator->errors()->isNotEmpty()) {
                return;
            }

            $vendor = $this->user()->vendor;
            $this->package = PromotionPackage::active()->find($this->integer('promotion_package_id'));

            if ($this->package === null) {
                $validator->errors()->add('promotion_package_id', 'This package is no longer available.');

                return;
            }

            if ($this->hasFile('file') && $this->input('media_type') === 'video' && ! $this->package->allows_video) {
                $validator->errors()->add('file', 'This package allows a photo only.');
            }

            // No per-package area limit (removed 2026-10-31): any of the
            // vendor's own subscription areas.
            $zoneIds = array_map('intval', $this->input('zone_ids', []));

            $allowed = app(PromotionService::class)->zonesFor($vendor)->pluck('id')->all();

            if ($allowed === []) {
                $validator->errors()->add('zone_ids', 'You need an active subscription to promote your business.');
            } elseif (array_diff($zoneIds, $allowed) !== []) {
                $validator->errors()->add('zone_ids', 'You can only promote in the areas you serve.');
            }
        });
    }
}
