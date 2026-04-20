<?php

namespace App\Http\Controllers;

use App\Models\CompanionAccessCode;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Str;

class AccessCodeController extends Controller
{
    // ── Generate a numeric code (patient calls this) ──────────────────────────

    public function generate(Request $request)
    {
        $patient = $request->user();

        if (! $patient->isPatient()) {
            return response(['message' => 'Doar pacienții pot genera coduri de acces'], 403);
        }

        // Invalidate any previous unused numeric codes for this patient
        CompanionAccessCode::where('patient_id', $patient->id)
            ->whereNull('invite_token')
            ->where('used', false)
            ->update(['used' => true]);

        $code = str_pad((string) random_int(0, 999999), 6, '0', STR_PAD_LEFT);

        $accessCode = CompanionAccessCode::create([
            'patient_id' => $patient->id,
            'code'       => $code,
            'expires_at' => now()->addSeconds(300), // 5 minutes
            'used'       => false,
        ]);

        return response([
            'code'       => $accessCode->code,
            'expires_in' => 300,
            'expires_at' => $accessCode->expires_at->toIso8601String(),
        ], 201);
    }

    // ── Redeem a numeric code (companion calls this) ──────────────────────────

    public function redeem(Request $request)
    {
        $companion = $request->user();

        if (! $companion->isCompanion()) {
            return response(['message' => 'Doar însoțitorii pot folosi coduri de acces'], 403);
        }

        $request->validate([
            'code' => 'required|string|size:6',
        ]);

        $code = $request->input('code');

$accessCode = CompanionAccessCode::whereNull('invite_token')
    ->where('code', $code)
    ->where('used', false)
    ->where('expires_at', '>=', now()->subSeconds(10)) // Oferă o marjă de 10 secunde
    ->with('patient')
    ->first();

        if (! $accessCode) {
            return response([
                'message' => 'Cod invalid sau expirat. Cere pacientului un cod nou.',
            ], 422);
        }

        $patient = $accessCode->patient;

        if (! $patient) {
            return response(['message' => 'Pacientul asociat codului nu mai există'], 422);
        }

        // Link companion → patient (idempotent)
        $patient->companions()->syncWithoutDetaching([
            $companion->id => [
                'relationship'       => null,
                'can_view_documents' => true,
            ],
        ]);

        // Mark the code as used
        $accessCode->update(['used' => true]);

        return response([
            'message' => 'Asociere reușită! Poți acum vizualiza documentele pacientului.',
            'patient' => [
                'id'   => $patient->id,
                'name' => $patient->name,
            ],
        ], 200);
    }

    // ── Send email invitation (patient calls this) ────────────────────────────

    public function sendEmailInvite(Request $request)
    {
        $patient = $request->user();

        if (! $patient->isPatient()) {
            return response(['message' => 'Doar pacienții pot trimite invitații'], 403);
        }

        $request->validate([
            'email' => 'required|email|max:255',
        ]);

        $email = $request->input('email');

        // Invalidate previous unused email invites to this address
        CompanionAccessCode::where('patient_id', $patient->id)
            ->where('companion_email', $email)
            ->where('used', false)
            ->update(['used' => true]);

        $token = Str::random(48);

        CompanionAccessCode::create([
            'patient_id'      => $patient->id,
            'code'            => substr(md5($token), 0, 6), // placeholder for NOT NULL
            'invite_token'    => $token,
            'companion_email' => $email,
            'expires_at'      => now()->addHours(24),
            'used'            => false,
        ]);

        $patientName = $patient->name;
        $deepLink    = config('app.url') . '/invite/' . $token;

        $mailSent = false;
        try {
            Mail::send([], [], function ($message) use ($email, $patientName, $deepLink, $token) {
                $message->to($email)
                    ->subject("Invitație acces dosar medical – {$patientName}")
                    ->html($this->buildInviteEmailHtml($patientName, $deepLink, $token));
            });
            $mailSent = true;
        } catch (\Exception $e) {
            // Mail not configured — return token so patient can share it manually
        }

        return response([
            'message'      => $mailSent
                ? "Invitație trimisă la {$email}"
                : "Email-ul nu a putut fi trimis. Trimite manual tokenul aparținătorului.",
            'invite_token' => $token,
            'mail_sent'    => $mailSent,
        ], 200);
    }

    // ── Redeem an email invite token (companion calls this) ───────────────────

    public function redeemEmailInvite(Request $request)
    {
        $companion = $request->user();

        if (! $companion->isCompanion()) {
            return response(['message' => 'Doar însoțitorii pot accepta invitații'], 403);
        }

        $request->validate([
            'token' => 'required|string',
        ]);

        $token = $request->input('token');

        $accessCode = CompanionAccessCode::where('invite_token', $token)
            ->where('used', false)
            ->where('expires_at', '>', now())
            ->with('patient')
            ->first();

        if (! $accessCode) {
            return response([
                'message' => 'Link de invitație invalid sau expirat.',
            ], 422);
        }

        $patient = $accessCode->patient;

        if (! $patient) {
            return response(['message' => 'Pacientul asociat invitației nu mai există'], 422);
        }

        $patient->companions()->syncWithoutDetaching([
            $companion->id => [
                'relationship'       => null,
                'can_view_documents' => true,
            ],
        ]);

        $accessCode->update(['used' => true]);

        return response([
            'message' => 'Invitație acceptată! Poți acum vizualiza documentele pacientului.',
            'patient' => [
                'id'   => $patient->id,
                'name' => $patient->name,
            ],
        ], 200);
    }

    // ── List linked companions for current patient ────────────────────────────

    public function myCompanions(Request $request)
    {
        $patient = $request->user();

        if (! $patient->isPatient()) {
            return response(['message' => 'Acces interzis'], 403);
        }

        $companions = $patient->companions()
            ->get()
            ->map(fn($c) => [
                'id'           => $c->id,
                'name'         => $c->name,
                'email'        => $c->email,
                'relationship' => $c->pivot->relationship,
            ]);

        return response(['companions' => $companions], 200);
    }

    // ── Unlink a companion (patient calls this) ───────────────────────────────

    public function unlinkMyCompanion(Request $request, int $companionId)
    {
        $patient = $request->user();

        if (! $patient->isPatient()) {
            return response(['message' => 'Acces interzis'], 403);
        }

        $patient->companions()->detach($companionId);

        return response(['message' => 'Însoțitor deconectat'], 200);
    }

    // ── Private: build invite email HTML ─────────────────────────────────────

    private function buildInviteEmailHtml(string $patientName, string $deepLink, string $token): string
    {
        return <<<HTML
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Invitație acces dosar medical</title>
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
                Spital Vișeu de Sus
              </h1>
              <p style="color:rgba(255,255,255,0.75);margin:6px 0 0;font-size:14px;">
                Portal UPU
              </p>
            </td>
          </tr>

          <tr>
            <td style="padding:40px;">
              <h2 style="color:#1A5276;font-size:18px;margin:0 0 16px;">
                Ai primit o invitație de acces
              </h2>
              <p style="color:#444;font-size:15px;line-height:1.6;margin:0 0 24px;">
                Pacientul <strong>{$patientName}</strong> ți-a trimis o invitație
                pentru a accesa dosarul său medical din aplicația
                <strong>Spital Vișeu UPU</strong>.
              </p>

              <table width="100%" cellpadding="0" cellspacing="0">
                <tr>
                  <td align="center" style="padding:8px 0 24px;">
                    <a href="{$deepLink}"
                       style="background:#1A5276;color:#ffffff;text-decoration:none;
                              padding:16px 40px;border-radius:12px;font-size:16px;
                              font-weight:700;display:inline-block;">
                      ✓ &nbsp;Acceptă invitația
                    </a>
                  </td>
                </tr>
              </table>

              <p style="color:#888;font-size:13px;text-align:center;margin:0 0 12px;">
                Sau introdu manual tokenul în aplicație:
              </p>

              <div style="background:#f0f4f8;border:2px dashed #1A5276;border-radius:12px;
                          padding:20px;text-align:center;margin-bottom:24px;">
                <p style="color:#888;font-size:11px;margin:0 0 8px;text-transform:uppercase;
                          letter-spacing:1px;">Token de invitație</p>
                <code style="color:#1A5276;font-size:13px;word-break:break-all;font-weight:700;
                             letter-spacing:1px;">
                  {$token}
                </code>
              </div>

              <div style="background:#fff8e1;border-left:4px solid #f39c12;border-radius:0 8px 8px 0;
                          padding:12px 16px;margin-bottom:24px;">
                <p style="color:#856404;font-size:13px;margin:0;">
                  ⏱ Această invitație expiră în <strong>24 de ore</strong>.
                  Dacă nu ai aplicația instalată, descarcă-o din
                  <strong>App Store</strong> sau <strong>Google Play</strong>.
                </p>
              </div>

              <p style="color:#bbb;font-size:12px;text-align:center;margin:0;">
                Dacă nu cunoști pe <strong>{$patientName}</strong>,
                poți ignora acest email.
              </p>
            </td>
          </tr>

          <tr>
            <td style="background:#f8f9fa;padding:20px 40px;text-align:center;
                       border-top:1px solid #e9ecef;">
              <p style="color:#aaa;font-size:12px;margin:0;">
                Spitalul Municipal Vișeu de Sus · Portal UPU
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
}