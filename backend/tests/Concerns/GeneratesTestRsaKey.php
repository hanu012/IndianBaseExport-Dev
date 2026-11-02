<?php

namespace Tests\Concerns;

use RuntimeException;

/**
 * A throwaway RSA private key (PEM) for the fake Firebase service account.
 *
 * openssl_pkey_new() needs an openssl.cnf. Some PHP installs — this
 * project's Windows dev PHP from winget among them — do not point
 * OPENSSL_CONF at one, so key generation fails with "Cannot get key"
 * (see also ServiceAccountJwtTest). PHP for Windows ships one at
 * extras/ssl/openssl.cnf beside php.exe; retry with that.
 */
trait GeneratesTestRsaKey
{
    protected static function testRsaPrivateKeyPem(): string
    {
        $options = ['private_key_bits' => 2048, 'private_key_type' => OPENSSL_KEYTYPE_RSA];
        $bundled = dirname(PHP_BINARY).DIRECTORY_SEPARATOR.'extras'.DIRECTORY_SEPARATOR.'ssl'.DIRECTORY_SEPARATOR.'openssl.cnf';

        foreach ([[], is_file($bundled) ? ['config' => $bundled] : null] as $extra) {
            if ($extra === null) {
                continue;
            }

            $key = @openssl_pkey_new($options + $extra);

            if ($key !== false && @openssl_pkey_export($key, $pem, null, $extra)) {
                return $pem;
            }
        }

        throw new RuntimeException('Could not generate a test RSA key: '.openssl_error_string());
    }
}
