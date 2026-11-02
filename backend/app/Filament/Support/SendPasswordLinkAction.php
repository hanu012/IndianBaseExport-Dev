<?php

namespace App\Filament\Support;

use App\Models\User;
use App\Services\AccountInviteService;
use App\Services\PasswordResetService;
use Filament\Actions\Action;
use Filament\Notifications\Notification;
use Illuminate\Support\Facades\Auth;

/**
 * "Send password link" on an account page (Users and Admins): emails a fresh
 * "set your password" link to an account that has not set its own password
 * yet — the way to re-send an expired invite (InviteStatusColumn). Never for
 * an account whose owner chose a password (CLAUDE.md: passwords are reset
 * only by the user).
 */
class SendPasswordLinkAction
{
    public static function make(): Action
    {
        return Action::make('sendPasswordLink')
            ->label('Send password link')
            ->icon('heroicon-o-envelope')
            ->color('gray')
            ->requiresConfirmation()
            ->modalHeading('Email a password link?')
            ->modalDescription(fn (User $record): string => "{$record->email} gets a link to set their own password. It works for "
                .(app(PasswordResetService::class)->inviteSender() === PasswordResetService::INVITE_BY_FIREBASE ? '1 hour' : '7 days')
                .'. If they did not get the last one, check the address first.')
            ->visible(fn (User $record): bool => app(AccountInviteService::class)->canInvite($record))
            ->authorize(fn (User $record): bool => Auth::user()?->can('update', $record) ?? false)
            ->action(function (User $record): void {
                $sentTo = app(AccountInviteService::class)->send($record);

                $sentTo !== null
                    ? Notification::make()
                        ->title("Password link sent to {$sentTo}")
                        ->body('If it does not arrive, check the address — the account stays "Invite sent" until they set a password.')
                        ->success()
                        ->send()
                    : Notification::make()
                        ->title('The email could not be sent')
                        ->body('Check the server\'s email (MAIL_*) settings, then try again.')
                        ->danger()
                        ->send();
            });
    }
}
