<?php

namespace App\Http\Controllers;

use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Mail;

class AuthController extends Controller
{
    public function register(Request $request)
    {
        $roleInput = $request->input('role', 'patient');

        $rules = [
            'name'        => 'required|string|max:255',
            'email'       => 'required|string|email|unique:users,email',
            'password'    => 'required|string|min:6|confirmed',
            'role'        => 'sometimes|in:patient,companion',
            'hospital_id' => 'nullable|exists:hospitals,id',
        ];

        if (in_array($roleInput, ['patient', 'companion'])) {
            $rules['cnp_pacient'] = 'required|string|size:13';
        } else {
            $rules['cnp_pacient'] = 'nullable|string|size:13';
        }

        $fields = $request->validate($rules);

        $needsVerification = in_array($fields['role'] ?? 'patient', ['patient', 'companion']);

        // Generate a 6-digit numeric code
        $verificationCode = $needsVerification
            ? str_pad((string) random_int(0, 999999), 6, '0', STR_PAD_LEFT)
            : null;

        $user = User::create([
            'name'                                  => $fields['name'],
            'email'                                 => $fields['email'],
            'password'                              => bcrypt($fields['password']),
            'cnp_pacient'                           => $fields['cnp_pacient'] ?? null,
            'role'                                  => $fields['role'] ?? 'patient',
            'hospital_id'                           => $fields['hospital_id'] ?? null,
            'is_active'                             => true,
            'email_verification_token'              => $verificationCode,
            'email_verification_token_expires_at'   => $needsVerification ? now()->addMinutes(30) : null,
            'email_verified_at'                     => $needsVerification ? null : now(), // staff/admin skip verification
        ]);

        if ($needsVerification && $verificationCode) {
            $this->sendVerificationEmail($user, $verificationCode);
        }

        // Don't issue a login token yet — user must verify first
        return response([
            'message'           => 'register_verify_email', // i18n key
            'user_id'           => $user->id,
            'email'             => $user->email,
            'needs_verification' => $needsVerification,
        ], 201);
    }

    // ── NEW: Verify email with 6-digit code ───────────────────────────────────

    public function verifyEmail(Request $request)
    {
        $request->validate([
            'user_id' => 'required|integer|exists:users,id',
            'code'    => 'required|string|size:6',
        ]);

        $user = User::find($request->input('user_id'));

        if ($user->email_verified_at) {
            // Already verified — just log them in
            $token = $user->createToken('spitaltoken')->plainTextToken;
            return response([
                'message' => 'already_verified',
                'user'    => $this->formatUser($user->load('hospital')),
                'token'   => $token,
            ], 200);
        }

        if (
            $user->email_verification_token !== $request->input('code') ||
            now()->isAfter($user->email_verification_token_expires_at)
        ) {
            return response(['message' => 'error_invalid_or_expired_code'], 422);
        }

        $user->update([
            'email_verified_at'                   => now(),
            'email_verification_token'            => null,
            'email_verification_token_expires_at' => null,
        ]);

        $token = $user->createToken('spitaltoken')->plainTextToken;

        return response([
            'message' => 'email_verified_success',
            'user'    => $this->formatUser($user->load('hospital')),
            'token'   => $token,
        ], 200);
    }

    // ── NEW: Resend verification code ─────────────────────────────────────────

    public function resendVerification(Request $request)
    {
        $request->validate([
            'user_id' => 'required|integer|exists:users,id',
        ]);

        $user = User::find($request->input('user_id'));

        if ($user->email_verified_at) {
            return response(['message' => 'already_verified'], 200);
        }

        $newCode = str_pad((string) random_int(0, 999999), 6, '0', STR_PAD_LEFT);

        $user->update([
            'email_verification_token'            => $newCode,
            'email_verification_token_expires_at' => now()->addMinutes(30),
        ]);

        $this->sendVerificationEmail($user, $newCode);

        return response(['message' => 'verification_code_resent'], 200);
    }

    public function login(Request $request)
    {
        $fields = $request->validate([
            'email'    => 'required|string|email',
            'password' => 'required|string',
        ]);

        $user = User::where('email', $fields['email'])->first();

        if (! $user || ! Hash::check($fields['password'], $user->password)) {
            return response(['message' => 'error_invalid_credentials'], 401);
        }

        if (! $user->is_active) {
            return response(['message' => 'error_account_disabled'], 403);
        }

        // Block unverified patients and companions
        if (
            in_array($user->role, ['patient', 'companion']) &&
            ! $user->email_verified_at
        ) {
            return response([
                'message' => 'error_email_not_verified',
                'user_id' => $user->id,
                'email'   => $user->email,
            ], 403);
        }

        $token = $user->createToken('spitaltoken')->plainTextToken;

        return response([
            'user'  => $this->formatUser($user->load('hospital')),
            'token' => $token,
        ], 200);
    }

    public function logout(Request $request)
    {
        $request->user()->currentAccessToken()->delete();
        return response(['message' => 'logout_success'], 200);
    }

    public function me(Request $request)
    {
        return response($this->formatUser($request->user()->load('hospital')), 200);
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    private function sendVerificationEmail(User $user, string $code): void
    {
        $hospitalName = $user->hospital?->name ?? 'Spital Vișeu de Sus';
        $subject = "{$hospitalName} – Cod de verificare cont";

        try {
            Mail::send([], [], function ($message) use ($user, $code, $subject, $hospitalName) {
                $message->to($user->email)
                    ->subject($subject)
                    ->html($this->buildVerificationEmailHtml($user->name, $code, $hospitalName));
            });
        } catch (\Exception $e) {
            // Mail not configured — code is still stored in DB
            // In dev you can log it: \Log::info("Verification code for {$user->email}: {$code}");
        }
    }

    private function buildVerificationEmailHtml(string $name, string $code, string $hospitalName): string
    {
        return <<<HTML
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="margin:0;padding:0;background:#f0f4f8;font-family:Arial,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#f0f4f8;padding:40px 0;">
    <tr>
      <td align="center">
        <table width="520" cellpadding="0" cellspacing="0"
               style="background:#ffffff;border-radius:16px;overflow:hidden;
                      box-shadow:0 4px 24px rgba(0,0,0,0.08);">
          <tr>
            <td style="background:#1A5276;padding:32px 40px;text-align:center;">
              <div style="font-size:36px;margin-bottom:8px;">🏥</div>
              <h1 style="color:#ffffff;margin:0;font-size:22px;font-weight:700;">
                {$hospitalName}
              </h1>
              <p style="color:rgba(255,255,255,0.75);margin:6px 0 0;font-size:14px;">Portal UPU</p>
            </td>
          </tr>
          <tr>
            <td style="padding:40px;">
              <h2 style="color:#1A5276;font-size:18px;margin:0 0 12px;">
                Bună, {$name}!
              </h2>
              <p style="color:#444;font-size:15px;line-height:1.6;margin:0 0 28px;">
                Contul tău a fost creat. Introdu codul de mai jos în aplicație pentru a confirma adresa de email.
              </p>
              <div style="background:#f0f4f8;border:2px dashed #1A5276;border-radius:12px;
                          padding:28px;text-align:center;margin-bottom:28px;">
                <p style="color:#888;font-size:11px;margin:0 0 10px;text-transform:uppercase;
                          letter-spacing:2px;">Cod de verificare</p>
                <span style="color:#1A5276;font-size:38px;font-weight:900;letter-spacing:10px;
                             font-family:monospace;">
                  {$code}
                </span>
              </div>
              <div style="background:#fff8e1;border-left:4px solid #f39c12;border-radius:0 8px 8px 0;
                          padding:12px 16px;margin-bottom:24px;">
                <p style="color:#856404;font-size:13px;margin:0;">
                  ⏱ Codul expiră în <strong>30 de minute</strong>.
                  Dacă nu ai creat acest cont, ignoră acest email.
                </p>
              </div>
            </td>
          </tr>
          <tr>
            <td style="background:#f8f9fa;padding:20px 40px;text-align:center;border-top:1px solid #e9ecef;">
              <p style="color:#aaa;font-size:12px;margin:0;">
                {$hospitalName} · Portal UPU
              </p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>
HTML;
    }

    private function formatUser(User $user): array
    {
        return [
            'id'             => $user->id,
            'name'           => $user->name,
            'email'          => $user->email,
            'role'           => $user->role,
            'cnp_pacient'    => $user->cnp_pacient,
            'hospital_id'    => $user->hospital_id,
            'hospital'       => $user->hospital ? [
                'id'   => $user->hospital->id,
                'name' => $user->hospital->name,
                'city' => $user->hospital->city,
            ] : null,
            'specialization' => $user->specialization,
            'license_number' => $user->license_number,
            'is_active'      => $user->is_active,
            'email_verified' => (bool) $user->email_verified_at,
        ];
    }
}