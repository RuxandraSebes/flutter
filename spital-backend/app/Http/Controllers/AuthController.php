<?php

namespace App\Http\Controllers;

use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;

class AuthController extends Controller
{
    public function register(Request $request)
    {
        $fields = $request->validate([
            'name'         => 'required|string|max:255',
            'email'        => 'required|string|email|unique:users,email',
            'password'     => 'required|string|min:6|confirmed',
            'cnp_pacient'  => 'nullable|string|size:13',
            // Patients & companions self-register; other roles are created by admins
            'role'         => 'sometimes|in:patient,companion',
        ]);

        $user = User::create([
            'name'        => $fields['name'],
            'email'       => $fields['email'],
            'password'    => bcrypt($fields['password']),
            'cnp_pacient' => $fields['cnp_pacient'] ?? null,
            'role'        => $fields['role'] ?? 'patient',
        ]);

        $token = $user->createToken('spitaltoken')->plainTextToken;

        return response([
            'user'  => $this->formatUser($user),
            'token' => $token,
        ], 201);
    }

    public function login(Request $request)
    {
        $fields = $request->validate([
            'email'    => 'required|string|email',
            'password' => 'required|string',
        ]);

        $user = User::where('email', $fields['email'])->first();

        if (! $user || ! Hash::check($fields['password'], $user->password)) {
            return response(['message' => 'Date incorecte'], 401);
        }

        if (! $user->is_active) {
            return response(['message' => 'Contul este dezactivat. Contactați administratorul.'], 403);
        }

        $token = $user->createToken('spitaltoken')->plainTextToken;

        return response([
            'user'  => $this->formatUser($user),
            'token' => $token,
        ], 200);
    }

    public function logout(Request $request)
    {
        $request->user()->currentAccessToken()->delete();

        return response(['message' => 'Delogat cu succes'], 200);
    }

    public function me(Request $request)
    {
        return response($this->formatUser($request->user()->load('hospital')), 200);
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private function formatUser(User $user): array
    {
        return [
            'id'              => $user->id,
            'name'            => $user->name,
            'email'           => $user->email,
            'role'            => $user->role,
            'cnp_pacient'     => $user->cnp_pacient,
            'hospital_id'     => $user->hospital_id,
            'hospital'        => $user->hospital ? [
                'id'   => $user->hospital->id,
                'name' => $user->hospital->name,
                'city' => $user->hospital->city,
            ] : null,
            'specialization'  => $user->specialization,
            'license_number'  => $user->license_number,
            'is_active'       => $user->is_active,
        ];
    }
}