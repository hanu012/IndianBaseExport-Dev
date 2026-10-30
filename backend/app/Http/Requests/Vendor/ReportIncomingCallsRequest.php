<?php

namespace App\Http\Requests\Vendor;

use Illuminate\Foundation\Http\FormRequest;

/**
 * Incoming calls the vendor app saw ring (CallOutcomeMatcher): when each
 * rang, whether it was answered, and the talk time. Times only — never a
 * phone number.
 *
 * device_time is the phone's clock at sending: the server corrects every
 * rang_at by the difference to its own clock, so a phone set a few minutes
 * wrong still pairs its calls with the right leads.
 */
class ReportIncomingCallsRequest extends FormRequest
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
            'device_time' => ['required', 'date'],
            'calls' => ['required', 'array', 'max:50'],
            'calls.*.rang_at' => ['required', 'date'],
            'calls.*.answered' => ['required', 'boolean'],
            'calls.*.talk_seconds' => ['nullable', 'integer', 'min:0', 'max:36000'],
        ];
    }
}
