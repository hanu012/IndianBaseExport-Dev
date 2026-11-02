{{--
    Browser-tab and home-screen icons for both panels (/admin and
    /super-admin).

    Super Admin → System settings → Branding can upload one (setting
    `admin_favicon`, a path on the public disk); it then serves every size.
    Otherwise the Indian Base Experts favicon pack in public/favicons, with
    public/favicon.ico for browsers that ask for it directly.
--}}
@php
    $custom = rescue(fn () => \App\Models\Setting::get('admin_favicon'), null, report: false);
    $customUrl = filled($custom) ? \Illuminate\Support\Facades\Storage::disk('public')->url($custom) : null;
@endphp

@if ($customUrl)
    <link rel="icon" href="{{ $customUrl }}">
    <link rel="apple-touch-icon" href="{{ $customUrl }}">
@else
    <link rel="icon" type="image/x-icon" href="{{ asset('favicon.ico') }}">
    <link rel="icon" type="image/png" sizes="16x16" href="{{ asset('favicons/favicon-16x16.png') }}">
    <link rel="icon" type="image/png" sizes="32x32" href="{{ asset('favicons/favicon-32x32.png') }}">
    <link rel="icon" type="image/png" sizes="48x48" href="{{ asset('favicons/favicon-48x48.png') }}">
    <link rel="icon" type="image/png" sizes="96x96" href="{{ asset('favicons/favicon-96x96.png') }}">
    <link rel="icon" type="image/png" sizes="192x192" href="{{ asset('favicons/android-chrome-192x192.png') }}">
    <link rel="apple-touch-icon" sizes="180x180" href="{{ asset('favicons/apple-touch-icon.png') }}">
@endif
