<?php

namespace App\Rules;

use Closure;
use Illuminate\Contracts\Validation\ValidationRule;
use Illuminate\Support\Facades\Cache;

/**
 * The part after "@" must be a domain that can receive mail (decided
 * 2026-11-01): it has mail servers (MX), or at least an address (A/AAAA).
 * Catches typos and made-up domains — "gmial.com", "gmail.con",
 * "abcxyz.in" — before an account is created or a link is sent.
 *
 * It cannot tell whether a mailbox exists at a real domain (meet@gmail.com):
 * mail providers do not answer that. Only the person using the emailed
 * link proves the address is theirs.
 *
 * Fails open: when DNS cannot be asked at all (offline, resolver down), the
 * address is allowed — an outage must not block every sign-up. Answers are
 * cached a day per domain. Switched off in tests (EMAIL_DOMAIN_CHECK=false,
 * phpunit.xml); `resolveUsing()` fakes the lookup for this rule's own tests.
 */
class EmailDomainExists implements ValidationRule
{
    /** @var (Closure(string): ?bool)|null true/false = can/cannot receive mail, null = could not ask */
    private static ?Closure $resolver = null;

    /** @param  (Closure(string): ?bool)|null  $resolver */
    public static function resolveUsing(?Closure $resolver): void
    {
        self::$resolver = $resolver;
    }

    public function validate(string $attribute, mixed $value, Closure $fail): void
    {
        if (! config('services.email_domain_check', true) || ! is_string($value) || ! str_contains($value, '@')) {
            return;
        }

        $domain = strtolower(trim(substr($value, strrpos($value, '@') + 1)));

        if ($domain === '') {
            return;
        }

        $canReceive = self::$resolver !== null ? (self::$resolver)($domain) : self::cachedLookup($domain);

        if ($canReceive === false) {
            $fail("The email domain \"{$domain}\" does not exist or cannot receive email. Check the address for typos.");
        }
    }

    /** A real answer is kept a day; "could not ask" is never cached. */
    private static function cachedLookup(string $domain): ?bool
    {
        $key = "email-domain:{$domain}";

        if (Cache::has($key)) {
            return (bool) Cache::get($key);
        }

        $answer = self::lookup($domain);

        if ($answer !== null) {
            Cache::put($key, $answer, now()->addDay());
        }

        return $answer;
    }

    /** true / false, or null when DNS could not be asked. */
    private static function lookup(string $domain): ?bool
    {
        $mx = @dns_get_record($domain, DNS_MX);

        if ($mx === false) {
            return null;
        }

        if ($mx !== []) {
            // A "null MX" (target ".") states the domain takes no email.
            return collect($mx)->contains(fn (array $record): bool => trim((string) ($record['target'] ?? ''), '.') !== '');
        }

        $address = @dns_get_record($domain, DNS_A | DNS_AAAA);

        return $address === false ? null : $address !== [];
    }
}
