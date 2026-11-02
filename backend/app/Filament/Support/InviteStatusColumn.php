<?php

namespace App\Filament\Support;

use App\Models\User;
use Filament\Tables\Columns\TextColumn;

/**
 * "Password" on the Users and Admins lists (decided 2026-11-01): for an
 * account that has not set its own password yet, whether its "set your
 * password" link is out (Invite sent), ran out unused (Invite expired —
 * likely a wrong address) or never went (Not sent). Blank once the person
 * has set one. "Send password link" on the account sends a fresh link.
 */
class InviteStatusColumn
{
    public static function make(): TextColumn
    {
        return TextColumn::make('invite_status')
            ->label('Password')
            ->badge()
            ->state(fn (User $record): ?string => match ($record->inviteStatus()) {
                User::INVITE_SENT => 'Invite sent',
                User::INVITE_EXPIRED => 'Invite expired',
                User::INVITE_NOT_SENT => 'Not set',
                default => null,
            })
            ->color(fn (?string $state): string => match ($state) {
                'Invite sent' => 'warning',
                'Invite expired' => 'danger',
                default => 'gray',
            })
            ->tooltip(fn (User $record): ?string => $record->inviteStatus() === User::INVITE_EXPIRED
                ? 'The link was never used. Check the email address, then send a new password link.'
                : null)
            ->placeholder('Set');
    }
}
